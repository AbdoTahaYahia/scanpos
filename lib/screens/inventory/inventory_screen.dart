import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_input.dart';
import '../../widgets/product_chip.dart';
import '../../widgets/rounded_card.dart';
import 'add_edit_product_screen.dart';
import '../settings/settings_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<InventoryProvider>().fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);

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
                  Text('Inventory', style: AppTheme.headlineLg),
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

            // ─── Search Bar ──────────────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: PillInput(
                hint: 'Search by name or barcode...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.outline, size: 22),
                onChanged: (query) =>
                    inventoryProvider.setSearchQuery(query),
              ),
            ),

            AppStyles.gap16,

            // ─── Category Filter ─────────────────────────────────
            if (inventoryProvider.categories.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: AppStyles.paddingHorizontal,
                  itemCount: inventoryProvider.categories.length + 1,
                  separatorBuilder: (_, _a) => AppStyles.gapW8,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ProductChip(
                        label: 'All',
                        isSelected:
                            inventoryProvider.selectedCategory == null,
                        onTap: () => inventoryProvider.setCategory(null),
                      );
                    }
                    final category =
                        inventoryProvider.categories[index - 1];
                    return ProductChip(
                      label: category,
                      isSelected:
                          inventoryProvider.selectedCategory == category,
                      onTap: () =>
                          inventoryProvider.setCategory(category),
                    );
                  },
                ),
              ),

            AppStyles.gap16,

            // ─── Product Count ───────────────────────────────────
            Padding(
              padding: AppStyles.paddingHorizontal,
              child: Text(
                '${inventoryProvider.products.length} products',
                style: AppTheme.labelBold.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),

            AppStyles.gap8,

            // ─── Product List ────────────────────────────────────
            Expanded(
              child: inventoryProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.black,
                      ),
                    )
                  : inventoryProvider.products.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppTheme.black,
                          backgroundColor: AppTheme.white,
                          onRefresh: () => inventoryProvider.refreshProducts(),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                            // Add 1 to itemCount if fetching more to show spinner
                            itemCount: inventoryProvider.products.length + (inventoryProvider.isFetchingMore ? 1 : 0),
                            separatorBuilder: (_, _a) => AppStyles.gap12,
                            itemBuilder: (context, index) {
                              if (index == inventoryProvider.products.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(color: AppTheme.black),
                                  ),
                                );
                              }
                              final product = inventoryProvider.products[index];
                              return _ProductCard(
                                product: product,
                                currencyFormat: currencyFormat,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),

      // ─── FAB ───────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AddEditProductScreen(),
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.inventory_2_outlined,
              size: 36,
              color: AppTheme.outline,
            ),
          ),
          AppStyles.gap16,
          Text(
            'No products yet',
            style: AppTheme.headlineMd.copyWith(color: AppTheme.outline),
          ),
          AppStyles.gap8,
          Text(
            'Tap + to add your first product',
            style: AppTheme.bodySm.copyWith(color: AppTheme.outline),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat currencyFormat;

  const _ProductCard({
    required this.product,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddEditProductScreen(product: product),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
            child: Container(
              width: 64,
              height: 64,
              color: AppTheme.surfaceContainer,
              child: const Icon(
                Icons.inventory_2_rounded,
                color: AppTheme.outline,
                size: 28,
              ),
            ),
          ),

          AppStyles.gapW16,

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppStyles.gap4,
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
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
                    if (product.size != null && product.size!.isNotEmpty) ...[
                      AppStyles.gapW8,
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            product.size!,
                            style: AppTheme.labelBold.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    AppStyles.gapW8,
                    Text(
                      'Stock: ${product.quantityInStock}',
                      style: AppTheme.bodySm.copyWith(
                        color: product.quantityInStock <= 5
                            ? AppTheme.error
                            : AppTheme.onSurfaceVariant,
                        fontWeight: product.quantityInStock <= 5
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Price
          Text(
            currencyFormat.format(product.price),
            style: AppTheme.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
