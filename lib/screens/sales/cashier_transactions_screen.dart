import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/rounded_card.dart';
import 'edit_transaction_screen.dart';

class CashierTransactionsScreen extends StatefulWidget {
  const CashierTransactionsScreen({super.key});

  @override
  State<CashierTransactionsScreen> createState() => _CashierTransactionsScreenState();
}

class _CashierTransactionsScreenState extends State<CashierTransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  final _currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  final _dateFormat = DateFormat('h:mm a');
  final _fullDateFormat = DateFormat('MMM d, yyyy • h:mm a');

  List<SaleTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final user = context.read<AuthProvider>().appUser;
    if (user?.storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final transactions = await _transactionService.getCashierRecentTransactions(
        user!.storeId!,
        user.uid,
      );
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cashier transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _openEditScreen(SaleTransaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group transactions by date
    final grouped = <String, List<SaleTransaction>>{};
    final today = DateTime.now();
    for (final tx in _transactions) {
      final isToday = tx.timestamp.day == today.day &&
          tx.timestamp.month == today.month &&
          tx.timestamp.year == today.year;
      final key = isToday ? 'Today' : DateFormat('MMM d, yyyy').format(tx.timestamp);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppStyles.gapW8,
                  Expanded(
                    child: Text('My Transactions', style: AppTheme.headlineLg),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Last 24h',
                      style: AppTheme.labelBold.copyWith(color: AppTheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            AppStyles.gap16,

            // ─── Transaction List ────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.black),
                    )
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppTheme.black,
                          onRefresh: _loadTransactions,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: grouped.keys.length,
                            itemBuilder: (context, sectionIndex) {
                              final dateKey = grouped.keys.elementAt(sectionIndex);
                              final items = grouped[dateKey]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (sectionIndex > 0) AppStyles.gap16,
                                  Text(
                                    dateKey,
                                    style: AppTheme.labelBold.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                  AppStyles.gap12,
                                  ...items.map((tx) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CashierTransactionCard(
                                      transaction: tx,
                                      currencyFormat: _currencyFormat,
                                      timeFormat: _dateFormat,
                                      fullDateFormat: _fullDateFormat,
                                      onEdit: () => _openEditScreen(tx),
                                    ),
                                  )),
                                ],
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
            child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppTheme.outline),
          ),
          AppStyles.gap16,
          Text(
            'No transactions',
            style: AppTheme.headlineMd.copyWith(color: AppTheme.outline),
          ),
          AppStyles.gap8,
          Text(
            'Your recent sales will appear here',
            style: AppTheme.bodySm.copyWith(color: AppTheme.outline),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Card ──────────────────────────────────────────────────
class _CashierTransactionCard extends StatefulWidget {
  final SaleTransaction transaction;
  final NumberFormat currencyFormat;
  final DateFormat timeFormat;
  final DateFormat fullDateFormat;
  final VoidCallback onEdit;

  const _CashierTransactionCard({
    required this.transaction,
    required this.currencyFormat,
    required this.timeFormat,
    required this.fullDateFormat,
    required this.onEdit,
  });

  @override
  State<_CashierTransactionCard> createState() => _CashierTransactionCardState();
}

class _CashierTransactionCardState extends State<_CashierTransactionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;

    return RoundedCard(
      onTap: () => setState(() => _expanded = !_expanded),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time & amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.timeFormat.format(tx.timestamp),
                      style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
                    ),
                    AppStyles.gap4,
                    Text(
                      widget.currencyFormat.format(tx.totalAmount),
                      style: AppTheme.headlineMd,
                    ),
                  ],
                ),
              ),

              // Item count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text('${tx.itemCount} items', style: AppTheme.labelBold),
              ),

              AppStyles.gapW8,

              // Edit button
              GestureDetector(
                onTap: widget.onEdit,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppTheme.white, size: 18),
                ),
              ),

              AppStyles.gapW8,

              // Expand chevron
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.black),
              ),
            ],
          ),

          // Expanded items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  const Divider(color: AppTheme.outlineVariant),
                  AppStyles.gap8,
                  ...tx.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.productName, style: AppTheme.bodySm),
                        ),
                        Text(
                          'x${item.quantity}',
                          style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                        AppStyles.gapW16,
                        Text(
                          widget.currencyFormat.format(item.subtotal),
                          style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
