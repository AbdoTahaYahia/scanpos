import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/barcode_lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_input.dart';
import '../../widgets/rounded_card.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AddEditProductScreen({super.key, this.product});
  bool get isEditing => product != null;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();
  final _lookupService = BarcodeLookupService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _categoryCtrl;

  bool _isSaving = false;
  bool _isLookingUp = false;
  String? _lookupStatus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name);
    _priceCtrl = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '',
    );
    _qtyCtrl = TextEditingController(
      text: widget.product != null ? widget.product!.quantityInStock.toString() : '',
    );
    _barcodeCtrl = TextEditingController(text: widget.product?.barcode);
    _categoryCtrl = TextEditingController(text: widget.product?.category);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BarcodeScanDialog(),
    );
    if (result != null && result.isNotEmpty) {
      if (result.startsWith('TEXT:')) {
        // Text was detected instead of barcode — use as product name
        final text = result.substring(5).trim();
        _nameCtrl.text = text;
        setState(() {});
      } else {
        // Barcode scanned
        _barcodeCtrl.text = result;
        // Auto-lookup product info from the internet
        await _lookupProductInfo(result);
      }
    }
  }

  Future<void> _lookupProductInfo(String barcode) async {
    setState(() {
      _isLookingUp = true;
      _lookupStatus = null;
    });

    final result = await _lookupService.lookupBarcode(barcode);

    if (!mounted) return;

    if (result != null) {
      // Auto-fill the form fields
      if (_nameCtrl.text.isEmpty) {
        _nameCtrl.text = result.name;
      }
      if (_categoryCtrl.text.isEmpty && result.category != null) {
        _categoryCtrl.text = result.category!;
      }

      setState(() {
        _isLookingUp = false;
        _lookupStatus = '✅ Found: ${result.name}';
      });

      // Show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product found! Review and edit the details.'),
            backgroundColor: AppTheme.black,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isLookingUp = false;
        _lookupStatus = '⚠️ Not found online — fill manually';
      });
    }

    // Clear status after a few seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _lookupStatus = null);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final storeId = context.read<AuthProvider>().appUser!.storeId!;
      if (widget.isEditing) {
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          price: double.parse(_priceCtrl.text.trim()),
          quantityInStock: int.parse(_qtyCtrl.text.trim()),
          barcode: _barcodeCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
        );
        await _productService.updateProduct(updated);
      } else {
        await _productService.addProduct(
          storeId: storeId,
          name: _nameCtrl.text.trim(),
          price: double.parse(_priceCtrl.text.trim()),
          quantity: int.parse(_qtyCtrl.text.trim()),
          barcode: _barcodeCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_rounded, size: 48, color: AppTheme.black),
            AppStyles.gap16,
            Text('Delete Product?', style: AppTheme.headlineMd),
            AppStyles.gap8,
            Text(
              '"${widget.product!.name}" will be permanently removed.',
              style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            AppStyles.gap24,
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: 'Delete',
                onPressed: () => Navigator.of(ctx).pop(true),
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
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await _productService.deleteProduct(
          widget.product!.storeId,
          widget.product!.id,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ─── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppStyles.gapW8,
              Text(
                widget.isEditing ? 'Edit Product' : 'Add Product',
                style: AppTheme.headlineLg,
              ),
              const Spacer(),
              if (widget.isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  color: AppTheme.error,
                  onPressed: _delete,
                ),
            ]),
          ),
          AppStyles.gap16,

          // ─── Form ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: AppStyles.paddingHorizontal,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Scan to Auto-Fill (new products only) ──────
                    if (!widget.isEditing) ...[
                      RoundedCard(
                        padding: const EdgeInsets.all(20),
                        onTap: _isLookingUp ? null : _scanBarcode,
                        child: Row(children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _isLookingUp
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: AppTheme.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: AppTheme.white,
                                    size: 28,
                                  ),
                          ),
                          AppStyles.gapW16,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan Barcode to Auto-Fill',
                                  style: AppTheme.bodyLg.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                AppStyles.gap4,
                                Text(
                                  _isLookingUp
                                      ? 'Looking up product info...'
                                      : 'Scan a barcode and we\'ll find the product details',
                                  style: AppTheme.bodySm.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isLookingUp)
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: AppTheme.outline,
                            ),
                        ]),
                      ),

                      // Lookup status message
                      if (_lookupStatus != null) ...[
                        AppStyles.gap8,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _lookupStatus!,
                            style: AppTheme.bodySm.copyWith(
                              color: _lookupStatus!.startsWith('✅')
                                  ? AppTheme.black
                                  : AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      AppStyles.gap24,
                    ],

                    // ─── Product Icon ──────────────────────────────
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.outlineVariant, width: 2),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          size: 36,
                          color: AppTheme.outline,
                        ),
                      ),
                    ),
                    AppStyles.gap24,

                    // ─── Barcode ────────────────────────────────────
                    PillInput(
                      label: 'Barcode Number (Optional)',
                      hint: 'Scan or type barcode (optional)',
                      controller: _barcodeCtrl,
                      textInputAction: TextInputAction.next,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_barcodeCtrl.text.isNotEmpty && !widget.isEditing)
                            IconButton(
                              icon: const Icon(Icons.search_rounded, color: AppTheme.outline),
                              onPressed: () => _lookupProductInfo(_barcodeCtrl.text.trim()),
                              tooltip: 'Lookup info online',
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.black),
                            onPressed: _scanBarcode,
                          ),
                        ],
                      ),
                    ),
                    AppStyles.gap16,

                    // ─── Product Name ──────────────────────────────
                    PillInput(
                      label: 'Product Name',
                      hint: 'e.g. Organic Milk 1L',
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    AppStyles.gap16,

                    // ─── Price ──────────────────────────────────────
                    PillInput(
                      label: 'Price (EGP)',
                      hint: '0.00',
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Enter valid price';
                        return null;
                      },
                    ),
                    AppStyles.gap16,

                    // ─── Quantity ───────────────────────────────────
                    PillInput(
                      label: 'Quantity in Stock',
                      hint: '0',
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v.trim()) == null) return 'Enter valid number';
                        return null;
                      },
                    ),
                    AppStyles.gap16,

                    // ─── Category ──────────────────────────────────
                    PillInput(
                      label: 'Category',
                      hint: 'e.g. Dairy, Beverages',
                      controller: _categoryCtrl,
                      textInputAction: TextInputAction.done,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    AppStyles.gap32,

                    // ─── Save Button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: PillButton(
                        label: widget.isEditing ? 'Update Product' : 'Add Product',
                        onPressed: _isSaving ? null : _save,
                        isLoading: _isSaving,
                        height: 64,
                      ),
                    ),
                    AppStyles.gap48,
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Smart scan dialog — scans for barcode AND reads text
class _BarcodeScanDialog extends StatefulWidget {
  @override
  State<_BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<_BarcodeScanDialog> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Scan Product', style: AppTheme.headlineMd),
          AppStyles.gap4,
          Text(
            'Scan barcode or use "Read Text" if none',
            style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          AppStyles.gap16,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: MobileScanner(
                controller: _ctrl,
                onDetect: (capture) {
                  if (_scanned) return;
                  final barcode = capture.barcodes.firstOrNull?.rawValue;
                  if (barcode != null) {
                    _scanned = true;
                    Navigator.of(context).pop(barcode);
                  }
                },
              ),
            ),
          ),
          AppStyles.gap16,
          // Read Text button — opens LiveTextScanner
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: 'Read Text Instead',
              icon: Icons.text_fields_rounded,
              onPressed: () async {
                _ctrl.stop();
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => _TextReadScreen(),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.of(context).pop('TEXT:$result');
                } else {
                  _ctrl.start();
                }
              },
            ),
          ),
          AppStyles.gap8,
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: 'Cancel',
              variant: PillButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Simple text reading screen using camera + ML Kit
class _TextReadScreen extends StatefulWidget {
  @override
  State<_TextReadScreen> createState() => _TextReadScreenState();
}

class _TextReadScreenState extends State<_TextReadScreen> {
  CameraController? _cam;
  final _textRecognizer = TextRecognizer();
  bool _ready = false;
  bool _processing = false;
  String _detected = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _cam = CameraController(back, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    await _cam!.initialize();
    if (!mounted) return;
    setState(() => _ready = true);
    _cam!.startImageStream(_process);
  }

  void _process(CameraImage image) async {
    if (_processing) return;
    _processing = true;
    try {
      final rot = _cam?.description.sensorOrientation ?? 0;
      final inputRot = InputImageRotationValue.fromRawValue(rot);
      if (inputRot == null) { _processing = false; return; }
      final plane = image.planes.first;
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: inputRot,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final result = await _textRecognizer.processImage(input);
      if (result.text.isNotEmpty && mounted) {
        setState(() => _detected = result.text.length > 100
            ? result.text.substring(0, 100)
            : result.text);
      }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    _processing = false;
  }

  @override
  void dispose() {
    _cam?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.white,
        title: Text('Read Product Text', style: AppTheme.headlineMd.copyWith(color: AppTheme.white)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: _ready && _cam != null
                    ? CameraPreview(_cam!)
                    : const Center(child: CircularProgressIndicator(color: AppTheme.white)),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detected Text:', style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                AppStyles.gap8,
                Text(
                  _detected.isEmpty ? 'Point camera at product text...' : _detected,
                  style: AppTheme.bodySm.copyWith(
                    color: _detected.isEmpty ? AppTheme.outline : AppTheme.black,
                  ),
                  maxLines: 3,
                ),
                AppStyles.gap16,
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Use This Text',
                    onPressed: _detected.isEmpty ? null : () => Navigator.of(context).pop(_detected),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

