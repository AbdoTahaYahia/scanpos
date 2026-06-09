import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/store_service.dart';
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
  final StoreService _storeService = StoreService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);

  List<Product> _lowStockProducts = [];
  bool _isLoading = true;
  int _threshold = 5;
  String _thresholdType = 'units'; // 'units' or 'percent'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) {
      _loadLowStock();
      return;
    }

    try {
      final store = await _storeService.getStore(storeId);
      if (store != null && mounted) {
        setState(() {
          _threshold = store.lowStockThreshold;
          _thresholdType = store.lowStockThresholdType;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings from cloud: $e');
    }
    _loadLowStock();
  }

  Future<void> _saveSettings() async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    try {
      await _storeService.updateStoreLowStockSettings(storeId, _threshold, _thresholdType);
    } catch (e) {
      debugPrint('Error saving settings to cloud: $e');
    }
  }

  Future<void> _loadLowStock() async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      List<Product> products;
      if (_thresholdType == 'units') {
        products = await _productService.getLowStockProducts(
          storeId: storeId,
          threshold: _threshold,
        );
      } else {
        // Percentage based: fetch all products and filter client-side
        final allProducts = await _productService.getAllProducts(storeId: storeId);
        products = allProducts.where((p) {
          final initialQty = p.initialQuantity > 0 ? p.initialQuantity : 1;
          final percent = (p.quantityInStock / initialQty) * 100;
          return percent <= _threshold;
        }).toList();

        // Sort by quantityInStock ascending
        products.sort((a, b) => a.quantityInStock.compareTo(b.quantityInStock));
      }

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mode Selector ( ≤ vs % )
                    Row(
                      children: [
                        _buildTypeChip('units', ' ≤ '),
                        AppStyles.gapW8,
                        _buildTypeChip('percent', ' % '),
                      ],
                    ),
                    // Adjuster ( [-] [value] [+] )
                    Row(
                      children: [
                        // Decrease
                        GestureDetector(
                          onTap: _threshold > 1
                              ? () {
                                  setState(() => _threshold--);
                                  _saveSettings();
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
                        // Clickable value display
                        GestureDetector(
                          onTap: _showEditThresholdDialog,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '≤ $_threshold${_thresholdType == 'percent' ? '%' : ''}',
                                  style: AppTheme.headlineMd.copyWith(fontSize: 18),
                                ),
                                AppStyles.gapW4,
                                const Icon(Icons.edit_outlined, size: 12, color: AppTheme.outline),
                              ],
                            ),
                          ),
                        ),
                        // Increase
                        GestureDetector(
                          onTap: (_thresholdType == 'percent' && _threshold >= 100)
                              ? null
                              : () {
                                  setState(() => _threshold++);
                                  _saveSettings();
                                  _loadLowStock();
                                },
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: (_thresholdType == 'percent' && _threshold >= 100)
                                  ? AppTheme.surfaceContainer
                                  : AppTheme.black,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: (_thresholdType == 'percent' && _threshold >= 100)
                                  ? AppTheme.outline
                                  : AppTheme.white,
                            ),
                          ),
                        ),
                      ],
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
                                showPercentInfo: _thresholdType == 'percent',
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

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _thresholdType == type;
    return GestureDetector(
      onTap: () {
        if (_thresholdType != type) {
          setState(() {
            _thresholdType = type;
            if (type == 'percent' && _threshold > 100) {
              _threshold = 100;
            }
          });
          _saveSettings();
          _loadLowStock();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.black : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.black : AppTheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.labelBold.copyWith(
            color: isSelected ? AppTheme.white : AppTheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  void _showEditThresholdDialog() {
    final controller = TextEditingController(text: _threshold.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _thresholdType == 'percent' ? 'Edit Low Stock Percentage' : 'Edit Low Stock Units',
                  style: AppTheme.headlineMd,
                ),
                AppStyles.gap8,
                Text(
                  _thresholdType == 'percent'
                      ? 'Enter the required percentage (1 to 100)'
                      : 'Enter the required number of units (1 or more)',
                  style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
                ),
                AppStyles.gap16,
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: _thresholdType == 'percent' ? 'e.g. 10' : 'e.g. 5',
                    suffixText: _thresholdType == 'percent' ? '%' : 'units',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
                AppStyles.gap24,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.outline)),
                    ),
                    AppStyles.gapW12,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.black,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                      onPressed: () {
                        final val = int.tryParse(controller.text.trim());
                        if (val == null || val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid positive number')),
                          );
                          return;
                        }
                        if (_thresholdType == 'percent' && val > 100) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Percentage cannot exceed 100%')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() {
                          _threshold = val;
                        });
                        _saveSettings();
                        _loadLowStock();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            _thresholdType == 'percent'
                ? 'No products below $_threshold% of initial stock'
                : 'No products below $_threshold units',
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
  final bool showPercentInfo;

  const _LowStockProductCard({
    required this.product,
    required this.currencyFormat,
    required this.showPercentInfo,
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
                      Flexible(
                        child: Container(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      AppStyles.gapW8,
                    ],
                    Flexible(
                      child: Text(
                        product.barcode,
                        style: AppTheme.bodySm.copyWith(
                          color: AppTheme.outline,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showPercentInfo) ...[
                      AppStyles.gapW8,
                      Text(
                        '(${((product.quantityInStock / (product.initialQuantity > 0 ? product.initialQuantity : 1)) * 100).toStringAsFixed(0)}% of ${product.initialQuantity})',
                        style: AppTheme.bodySm.copyWith(
                          color: AppTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
