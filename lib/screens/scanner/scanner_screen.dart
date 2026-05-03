import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/circle_button.dart';
import '../../widgets/rounded_card.dart';
import '../../widgets/scan_feedback_overlay.dart';
import 'package:intl/intl.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final ProductService _productService = ProductService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  bool _isProcessingScan = false;
  bool _showScanner = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessingScan = true);

    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) {
      setState(() => _isProcessingScan = false);
      return;
    }

    final product = await _productService.getProductByBarcode(storeId, barcode);

    if (!mounted) return;

    if (product != null) {
      context.read<CartProvider>().addItem(product);
      ScanFeedbackOverlay.show(context, productName: product.name);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product not in inventory: $barcode'),
          backgroundColor: AppTheme.black,
        ),
      );
    }

    // Delay to prevent rapid re-scanning of the same code
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isProcessingScan = false);
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
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text('Scanner', style: AppTheme.headlineLg),
                  const Spacer(),
                  // Toggle scanner
                  CircleButton.icon(
                    icon: _showScanner
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    onPressed: () {
                      setState(() => _showScanner = !_showScanner);
                      if (_showScanner) {
                        _scannerController.start();
                      } else {
                        _scannerController.stop();
                      }
                    },
                    size: 48,
                    filled: _showScanner,
                  ),
                ],
              ),
            ),

            AppStyles.gap16,

            // ─── Scanner View ────────────────────────────────────
            if (_showScanner)
              Padding(
                padding: AppStyles.paddingHorizontal,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.black,
                        width: 2,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd - 2),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onBarcodeDetected,
                          ),
                          // Scan line indicator
                          if (_isProcessingScan)
                            Container(
                              color: AppTheme.black.withValues(alpha: 0.3),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          // Corner guides
                          ..._buildCornerGuides(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            AppStyles.gap16,

            // ─── Cart Section ────────────────────────────────────
            Expanded(
              child: cartProvider.isEmpty
                  ? _buildEmptyCart()
                  : _buildCartList(cartProvider),
            ),

            // ─── Bottom Total & Pay ──────────────────────────────
            if (!cartProvider.isEmpty)
              Container(
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
                                'TOTAL',
                                style: AppTheme.labelBold.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              AppStyles.gap4,
                              Text(
                                _currencyFormat.format(cartProvider.totalAmount),
                                style: AppTheme.priceDisplay,
                              ),
                            ],
                          ),
                          Text(
                            '${cartProvider.itemCount} items',
                            style: AppTheme.bodySm.copyWith(
                              color: AppTheme.onSurfaceVariant,
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
                          onPressed: cartProvider.isProcessing
                              ? null
                              : _handleCheckout,
                          isLoading: cartProvider.isProcessing,
                          height: 64,
                        ),
                      ),
                    ],
                  ),
                ),
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
            'Scan a product to get started',
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
          onDismissed: (_) => cartProvider.removeItem(item.product.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: AppTheme.white,
              size: 28,
            ),
          ),
          child: RoundedCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Product info
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
                      AppStyles.gap4,
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

  List<Widget> _buildCornerGuides() {
    const guideSize = 32.0;
    const guideThickness = 4.0;
    const guideColor = AppTheme.white;
    const guideInset = 16.0;

    Widget corner({
      required Alignment alignment,
      required BorderRadius radius,
    }) {
      return Positioned(
        left: alignment == Alignment.topLeft ||
                alignment == Alignment.bottomLeft
            ? guideInset
            : null,
        right: alignment == Alignment.topRight ||
                alignment == Alignment.bottomRight
            ? guideInset
            : null,
        top: alignment == Alignment.topLeft ||
                alignment == Alignment.topRight
            ? guideInset
            : null,
        bottom: alignment == Alignment.bottomLeft ||
                alignment == Alignment.bottomRight
            ? guideInset
            : null,
        child: Container(
          width: guideSize,
          height: guideSize,
          decoration: BoxDecoration(
            border: Border(
              top: alignment == Alignment.topLeft ||
                      alignment == Alignment.topRight
                  ? const BorderSide(
                      color: guideColor, width: guideThickness)
                  : BorderSide.none,
              bottom: alignment == Alignment.bottomLeft ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(
                      color: guideColor, width: guideThickness)
                  : BorderSide.none,
              left: alignment == Alignment.topLeft ||
                      alignment == Alignment.bottomLeft
                  ? const BorderSide(
                      color: guideColor, width: guideThickness)
                  : BorderSide.none,
              right: alignment == Alignment.topRight ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(
                      color: guideColor, width: guideThickness)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      corner(
        alignment: Alignment.topLeft,
        radius: const BorderRadius.only(topLeft: Radius.circular(4)),
      ),
      corner(
        alignment: Alignment.topRight,
        radius: const BorderRadius.only(topRight: Radius.circular(4)),
      ),
      corner(
        alignment: Alignment.bottomLeft,
        radius: const BorderRadius.only(bottomLeft: Radius.circular(4)),
      ),
      corner(
        alignment: Alignment.bottomRight,
        radius: const BorderRadius.only(bottomRight: Radius.circular(4)),
      ),
    ];
  }
}
