import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/rounded_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ProductService _productService = ProductService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);

  List<Product> _lowStockProducts = [];
  bool _isLoading = true;
  int _threshold = 5;

  @override
  void initState() {
    super.initState();
    _loadLowStock();
  }

  Future<void> _loadLowStock() async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final products = await _productService.getLowStockProducts(
        storeId: storeId,
        threshold: _threshold,
      );
      if (mounted) {
        setState(() {
          _lowStockProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading low stock: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = _lowStockProducts.where((p) => p.quantityInStock <= 0).length;
    final lowStock = _lowStockProducts.where((p) => p.quantityInStock > 0).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reports', style: AppTheme.headlineLg),
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

            // ─── Summary Cards ───────────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.error_outline_rounded,
                      label: 'Out of Stock',
                      value: '$outOfStock',
                      isAlert: outOfStock > 0,
                    ),
                  ),
                  AppStyles.gapW12,
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value: '$lowStock',
                      isAlert: false,
                    ),
                  ),
                ],
              ),
            ),

            AppStyles.gap16,

            // ─── Threshold Selector ──────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: RoundedCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppTheme.black, size: 20),
                    AppStyles.gapW12,
                    Expanded(
                      child: Text(
                        'Low stock threshold',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Decrease
                    GestureDetector(
                      onTap: _threshold > 1
                          ? () {
                              setState(() => _threshold--);
                              _loadLowStock();
                            }
                          : null,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _threshold > 1 ? AppTheme.black : AppTheme.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 16,
                          color: _threshold > 1 ? AppTheme.white : AppTheme.outline,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '≤ $_threshold',
                        style: AppTheme.headlineMd,
                      ),
                    ),
                    // Increase
                    GestureDetector(
                      onTap: _threshold < 100
                          ? () {
                              setState(() => _threshold++);
                              _loadLowStock();
                            }
                          : null,
                      child: Container(
                        width: 32, height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 16, color: AppTheme.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppStyles.gap16,

            // ─── Section Title ───────────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: Text(
                'LOW STOCK PRODUCTS',
                style: AppTheme.labelBold.copyWith(color: AppTheme.onSurfaceVariant),
              ),
            ),

            AppStyles.gap12,

            // ─── Product List ────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.black),
                    )
                  : _lowStockProducts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppTheme.black,
                          onRefresh: _loadLowStock,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: _lowStockProducts.length,
                            separatorBuilder: (_, __) => AppStyles.gap12,
                            itemBuilder: (context, index) {
                              final product = _lowStockProducts[index];
                              return _LowStockProductCard(
                                product: product,
                                currencyFormat: _currencyFormat,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: AppTheme.outline),
          ),
          AppStyles.gap16,
          Text('All stocked up!', style: AppTheme.headlineMd.copyWith(color: AppTheme.outline)),
          AppStyles.gap8,
          Text(
            'No products below $_threshold units',
            style: AppTheme.bodySm.copyWith(color: AppTheme.outline),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ──────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isAlert;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAlert ? AppTheme.black : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.black,
          width: AppTheme.borderLevel1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isAlert ? AppTheme.white : AppTheme.black, size: 24),
          AppStyles.gap12,
          Text(
            value,
            style: AppTheme.headlineLg.copyWith(
              color: isAlert ? AppTheme.white : AppTheme.black,
            ),
          ),
          AppStyles.gap4,
          Text(
            label,
            style: AppTheme.bodySm.copyWith(
              color: isAlert ? AppTheme.white.withValues(alpha: 0.7) : AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Low Stock Product Card ────────────────────────────────────────────
class _LowStockProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat currencyFormat;

  const _LowStockProductCard({
    required this.product,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.quantityInStock <= 0;

    return RoundedCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isOutOfStock ? AppTheme.errorContainer : AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${product.quantityInStock}',
                style: AppTheme.headlineMd.copyWith(
                  color: isOutOfStock ? AppTheme.error : AppTheme.onSurface,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          AppStyles.gapW16,

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppStyles.gap4,
                Row(
                  children: [
                    if (product.category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          product.category,
                          style: AppTheme.labelBold.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      AppStyles.gapW8,
                    ],
                    Text(
                      product.barcode,
                      style: AppTheme.bodySm.copyWith(
                        color: AppTheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          AppStyles.gapW12,

          // Price + status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(product.price),
                style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
              AppStyles.gap4,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutOfStock ? AppTheme.error : AppTheme.black,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  isOutOfStock ? 'OUT' : 'LOW',
                  style: AppTheme.labelBold.copyWith(
                    color: AppTheme.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
