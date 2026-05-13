import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/rounded_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/circle_button.dart';

class EditTransactionScreen extends StatefulWidget {
  final SaleTransaction transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TransactionService _transactionService = TransactionService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  late List<_EditableItem> _items;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _items = widget.transaction.items
        .map((item) => _EditableItem(
              productId: item.productId,
              productName: item.productName,
              price: item.price,
              originalQuantity: item.quantity,
              quantity: item.quantity,
            ))
        .toList();
  }

  double get _newTotal =>
      _items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

  double get _originalTotal => widget.transaction.totalAmount;

  int get _totalItems =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity);

  bool get _allRemoved => _items.every((item) => item.quantity <= 0);

  void _incrementQuantity(int index) {
    setState(() {
      _items[index].quantity++;
      _hasChanges = true;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (_items[index].quantity > 0) {
        _items[index].quantity--;
        _hasChanges = true;
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].quantity = 0;
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    final user = context.read<AuthProvider>().appUser;
    if (user?.storeId == null) return;

    // Build updated items list (only items with quantity > 0)
    final updatedItems = _items
        .where((item) => item.quantity > 0)
        .map((item) => {
              'productId': item.productId,
              'productName': item.productName,
              'price': item.price,
              'quantity': item.quantity,
              'subtotal': item.price * item.quantity,
            })
        .toList();

    // Confirm action
    final isDelete = updatedItems.isEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDelete ? Icons.delete_forever_rounded : Icons.edit_rounded,
                size: 48,
                color: isDelete ? AppTheme.error : AppTheme.black,
              ),
              AppStyles.gap16,
              Text(
                isDelete ? 'Delete Transaction?' : 'Save Changes?',
                style: AppTheme.headlineMd,
              ),
              AppStyles.gap8,
              Text(
                isDelete
                    ? 'This transaction will be deleted and all items will be returned to stock.'
                    : 'The transaction will be updated and stock will be adjusted accordingly.',
                style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (!isDelete) ...[
                AppStyles.gap12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currencyFormat.format(_originalTotal),
                      style: AppTheme.bodySm.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: AppTheme.outline,
                      ),
                    ),
                    AppStyles.gapW8,
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.black),
                    AppStyles.gapW8,
                    Text(
                      _currencyFormat.format(_newTotal),
                      style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
              AppStyles.gap24,
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: isDelete ? 'Delete' : 'Save',
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

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await _transactionService.editTransaction(
        storeId: user!.storeId!,
        transactionId: widget.transaction.id,
        cashierId: user.uid,
        updatedItems: updatedItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDelete
                ? 'Transaction deleted successfully'
                : 'Transaction updated successfully'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  AppStyles.gapW8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Transaction', style: AppTheme.headlineLg),
                        Text(
                          _dateFormat.format(widget.transaction.timestamp),
                          style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AppStyles.gap16,

            // ─── Change Summary ──────────────────────────────────
            if (_hasChanges)
              Padding(
                padding: AppStyles.paddingHorizontal,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _allRemoved ? AppTheme.errorContainer : AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: _allRemoved ? AppTheme.error : AppTheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _allRemoved ? Icons.delete_forever_rounded : Icons.info_outline_rounded,
                        color: _allRemoved ? AppTheme.error : AppTheme.onSurfaceVariant,
                        size: 20,
                      ),
                      AppStyles.gapW12,
                      Expanded(
                        child: Text(
                          _allRemoved
                              ? 'All items removed — transaction will be deleted'
                              : 'Stock will be adjusted when you save',
                          style: AppTheme.bodySm.copyWith(
                            color: _allRemoved ? AppTheme.error : AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_hasChanges) AppStyles.gap12,

            // ─── Items List ──────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => AppStyles.gap12,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isRemoved = item.quantity <= 0;
                  final isChanged = item.quantity != item.originalQuantity;

                  return AnimatedOpacity(
                    opacity: isRemoved ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: RoundedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Product icon
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: isRemoved
                                      ? AppTheme.errorContainer
                                      : AppTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isRemoved
                                      ? Icons.remove_shopping_cart_rounded
                                      : Icons.inventory_2_rounded,
                                  color: isRemoved ? AppTheme.error : AppTheme.outline,
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
                                      item.productName,
                                      style: AppTheme.bodyLg.copyWith(
                                        fontWeight: FontWeight.w700,
                                        decoration: isRemoved
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _currencyFormat.format(item.price),
                                          style: AppTheme.bodySm.copyWith(
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (isChanged && !isRemoved) ...[
                                          AppStyles.gapW8,
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.black,
                                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                            ),
                                            child: Text(
                                              '${item.originalQuantity} → ${item.quantity}',
                                              style: AppTheme.labelBold.copyWith(
                                                color: AppTheme.white,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (!isRemoved) ...[
                                // Quantity controls
                                Row(
                                  children: [
                                    CircleButton.icon(
                                      icon: Icons.remove,
                                      size: 36,
                                      iconSize: 18,
                                      onPressed: () => _decrementQuantity(index),
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
                                      onPressed: () => _incrementQuantity(index),
                                    ),
                                  ],
                                ),

                                AppStyles.gapW12,

                                // Delete button
                                GestureDetector(
                                  onTap: () => _removeItem(index),
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_rounded,
                                      color: AppTheme.error,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Undo button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _items[index].quantity = _items[index].originalQuantity;
                                      _hasChanges = _items.any(
                                        (i) => i.quantity != i.originalQuantity,
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.black,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                    ),
                                    child: Text(
                                      'Undo',
                                      style: AppTheme.labelBold.copyWith(color: AppTheme.white),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Subtotal row
                          if (!isRemoved) ...[
                            AppStyles.gap8,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Subtotal: ',
                                  style: AppTheme.bodySm.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(item.price * item.quantity),
                                  style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ─── Bottom Bar ──────────────────────────────────────
            if (_hasChanges)
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
                      if (!_allRemoved)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Total',
                                  style: AppTheme.bodySm.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(_newTotal),
                                  style: AppTheme.priceDisplay,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Was ${_currencyFormat.format(_originalTotal)}',
                                  style: AppTheme.bodySm.copyWith(
                                    color: AppTheme.outline,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                AppStyles.gap4,
                                Text(
                                  '$_totalItems items',
                                  style: AppTheme.bodyLg.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (!_allRemoved) AppStyles.gap16,
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: PillButton(
                          label: _allRemoved ? 'Delete Transaction' : 'Save Changes',
                          icon: _allRemoved
                              ? Icons.delete_forever_rounded
                              : Icons.check_rounded,
                          onPressed: _isSaving ? null : _saveChanges,
                          isLoading: _isSaving,
                          height: 56,
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
}

/// Internal model for tracking editable item state
class _EditableItem {
  final String productId;
  final String productName;
  final double price;
  final int originalQuantity;
  int quantity;

  _EditableItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.originalQuantity,
    required this.quantity,
  });
}
