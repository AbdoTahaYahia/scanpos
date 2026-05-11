import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/product_service.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_input.dart';
import '../../widgets/circle_button.dart';
import '../../widgets/rounded_card.dart';
import '../../widgets/scan_feedback_overlay.dart';
import '../../utils/string_extensions.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ScannerScreen extends StatefulWidget {
  final bool isActive;
  const ScannerScreen({super.key, this.isActive = true});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ProductService _productService = ProductService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isProcessingBarcode = false;
  bool _isProcessingText = false;
  bool _isCameraReady = false;
  bool _isFlashOn = false;
  int _frameCount = 0;
  List<Product> _textMatchedProducts = [];
  DateTime _lastTextMatchUpdate = DateTime.now();
  // Cache for normalized product names to avoid recomputing per frame
  Map<String, String> _normalizedProductNameCache = {};
  String _lastCachedStoreId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      WakelockPlus.enable();
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraReady = true);
      if (widget.isActive) {
        _cameraController!.startImageStream(_processFrame);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Tab became active — fully reinitialize camera for fresh preview
      WakelockPlus.enable();
      _reinitCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      WakelockPlus.disable();
      _disposeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
      _reinitCamera();
    } else if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
      _disposeCamera();
    }
  }

  Future<void> _reinitCamera() async {
    await _disposeCamera();
    await _initCamera();
  }

  Future<void> _disposeCamera() async {
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        await _cameraController?.stopImageStream();
      }
      if (_isFlashOn) {
        await _cameraController?.setFlashMode(FlashMode.off);
      }
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraReady = false;
        _isFlashOn = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  void _processFrame(CameraImage image) async {
    _frameCount++;

    // ── Global frame gate ──────────────────────────────────────────
    // Drop frames aggressively when both processors are busy.
    // This prevents native BLASTBufferQueue overflow (max frames error).
    if (_isProcessingBarcode && _isProcessingText) return;

    // Skip every other frame unconditionally to reduce buffer pressure
    if (_frameCount % 2 != 0) return;

    // Every 30th frame (~once a second at 30fps), try text scanning
    if (_frameCount % 30 == 0 && !_isProcessingText) {
      _isProcessingText = true;
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        _isProcessingText = false;
        return;
      }
      try {
        final textResult = await _textRecognizer.processImage(inputImage);
        if (textResult.text.isNotEmpty && mounted) {
          _handleDetectedText(textResult.text);
        }
      } catch (_) {}
      _isProcessingText = false;
    } else if (!_isProcessingBarcode) {
      // For remaining frames, run fast barcode scanning
      _isProcessingBarcode = true;
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        _isProcessingBarcode = false;
        return;
      }
      try {
        final barcodes = await _barcodeScanner.processImage(inputImage);
        if (barcodes.isNotEmpty && mounted) {
          final rawValue = barcodes.first.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            await _handleBarcode(rawValue);
            // Throttle barcode after a successful scan
            await Future.delayed(const Duration(milliseconds: 800));
          }
        }
      } catch (_) {}
      _isProcessingBarcode = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final rotation = _cameraController?.description.sensorOrientation ?? 0;
      final inputRotation = InputImageRotationValue.fromRawValue(rotation);
      if (inputRotation == null) return null;

      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: inputRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleBarcode(String barcode) async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    final product = await _productService.getProductByBarcode(storeId, barcode);

    if (!mounted) return;

    if (product != null) {
      final added = context.read<CartProvider>().addItem(product);
      if (added) {
        ScanFeedbackOverlay.show(context, productName: product.name);
        // Clear text match since barcode found
        setState(() {
          _textMatchedProducts.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product out of stock: ${product.name}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product not in inventory: $barcode'),
          backgroundColor: AppTheme.black,
        ),
      );
    }
  }

  /// Refreshes the cached normalized names when inventory changes
  void _refreshNormalizedCache() {
    final storeId = context.read<AuthProvider>().appUser?.storeId ?? '';
    if (storeId == _lastCachedStoreId && _normalizedProductNameCache.isNotEmpty) return;
    _lastCachedStoreId = storeId;
    final products = context.read<InventoryProvider>().allProductsForSearch;
    _normalizedProductNameCache = {
      for (final p in products) p.id: p.name.normalizedForSearch,
    };
  }

  // Pre-compiled regex for word splitting
  static final _wordSplitRegex = RegExp(r'[\s\-,]+');

  void _handleDetectedText(String fullText) {
    final products = context.read<InventoryProvider>().allProductsForSearch;
    if (products.isEmpty) return;

    // Refresh normalized name cache if needed
    _refreshNormalizedCache();

    final textLower = fullText.normalizedForSearch;
    final scoredProducts = <Product, int>{};

    for (final product in products) {
      // Use cached normalized name instead of recomputing
      final nameLower = _normalizedProductNameCache[product.id] ?? product.name.normalizedForSearch;

      int score = 0;

      if (textLower.contains(nameLower)) {
        score += 10;
      } else {
        final words = nameLower.split(_wordSplitRegex);
        for (final word in words) {
          if (word.length > 2 && textLower.contains(word)) score++;
        }
      }

      if (score >= 2) {
        scoredProducts[product] = score;
      }
    }

    if (scoredProducts.isNotEmpty && mounted) {
      final sortedEntries = scoredProducts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topMatches = sortedEntries.take(3).map((e) => e.key).toList();

      bool isIdentical = false;
      if (_textMatchedProducts.length == topMatches.length) {
        isIdentical = true;
        for (int i = 0; i < topMatches.length; i++) {
          if (_textMatchedProducts[i].id != topMatches[i].id) {
            isIdentical = false;
            break;
          }
        }
      }

      if (isIdentical) return;

      final now = DateTime.now();
      if (now.difference(_lastTextMatchUpdate).inMilliseconds < 800) {
        return;
      }

      _lastTextMatchUpdate = now;
      setState(() {
        _textMatchedProducts = topMatches;
      });
    }
  }

  void _addTextMatchedProduct(Product product) {
    final added = context.read<CartProvider>().addItem(product);
    if (added) {
      ScanFeedbackOverlay.show(context, productName: product.name);
      setState(() {
        _textMatchedProducts.remove(product);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product out of stock: ${product.name}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _handleCheckout() async {
    final cartProvider = context.read<CartProvider>();
    final user = context.read<AuthProvider>().appUser;
    if (user == null || cartProvider.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Confirm Payment', style: AppTheme.headlineMd),
              AppStyles.gap16,
              Text(
                'Total: ${_currencyFormat.format(cartProvider.totalAmount)}',
                style: AppTheme.priceDisplay,
                textAlign: TextAlign.center,
              ),
              AppStyles.gap8,
              Text(
                '${cartProvider.itemCount} items',
                style: AppTheme.bodySm.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              AppStyles.gap32,
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Confirm & Pay',
                  onPressed: () => Navigator.of(ctx).pop(true),
                  height: 56,
                ),
              ),
              AppStyles.gap12,
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Cancel',
                  variant: PillButtonVariant.secondary,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await cartProvider.checkout(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Sale completed successfully!'
                  : 'Failed to process sale. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    // Stop the image stream BEFORE disposing to prevent memory leak
    // from frames arriving after controller is disposed
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        _cameraController?.stopImageStream();
      }
    } catch (_) {}
    _cameraController?.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scanner', style: AppTheme.headlineLg),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppTheme.black),
                      onPressed: () => context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer(),
                    ),
                  ),
                ],
              ),
            ),

            AppStyles.gap16,

            // ─── Camera View ─────────────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.black, width: 2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd - 2),
                        child: _isCameraReady && _cameraController != null
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _cameraController!.value.previewSize?.height ?? 640,
                                  height: _cameraController!.value.previewSize?.width ?? 480,
                                  child: CameraPreview(_cameraController!),
                                ),
                              )
                            : Container(
                                color: AppTheme.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                      ),
                      if (_isCameraReady && _cameraController != null)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: CircleAvatar(
                            backgroundColor: AppTheme.black.withValues(alpha: 0.5),
                            radius: 20,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: AppTheme.white,
                                size: 20,
                              ),
                              onPressed: _toggleFlash,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Manual Search Bar ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: RawAutocomplete<Product>(
                textEditingController: _searchCtrl,
                focusNode: _searchFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Product>.empty();
                  }
                  final query = textEditingValue.text.normalizedForSearch;
                  // Access all products loaded for search purposes, not just the paginated list
                  final products = context.read<InventoryProvider>().allProductsForSearch;
                  
                  // Return up to 3 matches
                  return products
                      .where((p) => p.name.normalizedForSearch.contains(query) || p.barcode.normalizedForSearch.contains(query))
                      .take(3);
                },
                displayStringForOption: (Product option) => option.name,
                onSelected: (Product selection) {
                  final added = context.read<CartProvider>().addItem(selection);
                  if (added) {
                    ScanFeedbackOverlay.show(context, productName: selection.name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product out of stock: ${selection.name}'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                  // Clear the search bar after selection
                  Future.delayed(Duration.zero, () {
                    _searchCtrl.clear();
                    _searchFocusNode.unfocus();
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  return PillInput(
                    controller: controller,
                    focusNode: focusNode,
                    hint: 'Search by name or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.outline, size: 22),
                    onSubmitted: (_) => onEditingComplete(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, right: 48),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.black, width: 2),
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option.name,
                                        style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _currencyFormat.format(option.price),
                                      style: AppTheme.labelBold,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ─── Text Match Banner ───────────────────────────────
            if (_textMatchedProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  children: _textMatchedProducts.map((matchedProduct) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () => _addTextMatchedProduct(matchedProduct),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppTheme.white, size: 20),
                              AppStyles.gapW8,
                              Expanded(
                                child: Text(
                                  matchedProduct.name.replaceAll('\n', ' ').trim(),
                                  style: AppTheme.bodyLg.copyWith(
                                    color: AppTheme.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppStyles.gapW8,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                child: Text(
                                  '+ Add',
                                  style: AppTheme.labelBold.copyWith(color: AppTheme.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            AppStyles.gap12,

            // ─── Cart Section ────────────────────────────────────
            Expanded(
              child: Selector<CartProvider, bool>(
                selector: (_, cart) => cart.isEmpty,
                builder: (context, isEmpty, _) => isEmpty
                    ? _buildEmptyCart()
                    : _buildCartList(context.read<CartProvider>()),
              ),
            ),

            // ─── Bottom Total & Pay ──────────────────────────────
            // ─── Bottom Total & Pay (rebuilds only when total/count/processing change) ──
            Selector<CartProvider, ({double total, int count, bool processing, bool empty})>(
              selector: (_, cart) => (
                total: cart.totalAmount,
                count: cart.itemCount,
                processing: cart.isProcessing,
                empty: cart.isEmpty,
              ),
              builder: (context, data, _) {
                if (data.empty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.white,
                    border: Border(
                      top: BorderSide(color: AppTheme.black, width: 2),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: AppTheme.bodySm.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(data.total),
                                  style: AppTheme.priceDisplay,
                                ),
                              ],
                            ),
                            Text(
                              '${data.count} items',
                              style: AppTheme.bodyLg.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        AppStyles.gap16,
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: PillButton(
                            label: 'Pay',
                            icon: Icons.payment_rounded,
                            onPressed: data.processing
                                ? null
                                : _handleCheckout,
                            isLoading: data.processing,
                            height: 64,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 36,
              color: AppTheme.outline,
            ),
          ),
          AppStyles.gap16,
          Text(
            'Cart is empty',
            style: AppTheme.headlineMd.copyWith(
              color: AppTheme.outline,
            ),
          ),
          AppStyles.gap8,
          Text(
            'Scan a barcode or point at product text',
            style: AppTheme.bodySm.copyWith(
              color: AppTheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(CartProvider cartProvider) {
    return ListView.separated(
      padding: AppStyles.paddingHorizontal,
      itemCount: cartProvider.items.length,
      separatorBuilder: (_, _a) => AppStyles.gap12,
      itemBuilder: (context, index) {
        final item = cartProvider.items[index];
        return Dismissible(
          key: ValueKey(item.product.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) =>
              cartProvider.removeItem(item.product.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.delete_rounded, color: AppTheme.white),
          ),
          child: RoundedCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.outline,
                    size: 22,
                  ),
                ),

                AppStyles.gapW16,

                // Name + price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: AppTheme.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currencyFormat.format(item.product.price),
                        style: AppTheme.bodySm.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity controls
                Row(
                  children: [
                    CircleButton.icon(
                      icon: Icons.remove,
                      size: 36,
                      iconSize: 18,
                      onPressed: () =>
                          cartProvider.decrementQuantity(item.product.id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: AppTheme.headlineMd,
                      ),
                    ),
                    CircleButton.icon(
                      icon: Icons.add,
                      size: 36,
                      iconSize: 18,
                      filled: true,
                      onPressed: () =>
                          cartProvider.incrementQuantity(item.product.id),
                    ),
                  ],
                ),

                AppStyles.gapW16,

                // Subtotal
                SizedBox(
                  width: 80,
                  child: Text(
                    _currencyFormat.format(item.subtotal),
                    style: AppTheme.bodyLg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
