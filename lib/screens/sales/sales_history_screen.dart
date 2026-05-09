import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/rounded_card.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final TransactionService _transactionService = TransactionService();
  final ScrollController _scrollController = ScrollController();
  final currencyFormat = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  static const int _pageSize = 10;

  final List<SaleTransaction> _transactions = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user is near the bottom (200px threshold)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _transactionService.getTransactionsPaginated(
        storeId,
        limit: _pageSize,
      );

      final docs = snapshot.docs;
      _transactions.clear();
      _transactions.addAll(
        docs.map((doc) => SaleTransaction.fromMap(doc.data())),
      );
      _lastDocument = docs.isNotEmpty ? docs.last : null;
      _hasMore = docs.length == _pageSize;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    final storeId = context.read<AuthProvider>().appUser?.storeId;
    if (storeId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await _transactionService.getTransactionsPaginated(
        storeId,
        limit: _pageSize,
        startAfter: _lastDocument,
      );

      final docs = snapshot.docs;
      _transactions.addAll(
        docs.map((doc) => SaleTransaction.fromMap(doc.data())),
      );
      _lastDocument = docs.isNotEmpty ? docs.last : null;
      _hasMore = docs.length == _pageSize;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppStyles.gapW8,
                  Text('Sales History', style: AppTheme.headlineLg),
                ],
              ),
            ),
            AppStyles.gap16,
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.black),
                    )
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppTheme.black,
                          onRefresh: _loadInitial,
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: _transactions.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, _a) => AppStyles.gap12,
                            itemBuilder: (context, index) {
                              // Loading indicator at the bottom
                              if (index == _transactions.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: _isLoadingMore
                                        ? const CircularProgressIndicator(
                                            color: AppTheme.black,
                                            strokeWidth: 2.5,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }

                              final tx = _transactions[index];
                              return _TransactionCard(
                                transaction: tx,
                                currencyFormat: currencyFormat,
                                dateFormat: dateFormat,
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
          Text('No sales yet', style: AppTheme.headlineMd.copyWith(color: AppTheme.outline)),
          AppStyles.gap8,
          Text('Transactions will appear here', style: AppTheme.bodySm.copyWith(color: AppTheme.outline)),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final SaleTransaction transaction;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _TransactionCard({
    required this.transaction,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dateFormat.format(tx.timestamp),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tx.cashierName, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  AppStyles.gap4,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text('${tx.itemCount} items', style: AppTheme.labelBold),
                  ),
                ],
              ),
              AppStyles.gapW8,
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.black),
              ),
            ],
          ),

          // Expanded item list
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
                        Text('x${item.quantity}', style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant)),
                        AppStyles.gapW16,
                        Text(widget.currencyFormat.format(item.subtotal), style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700)),
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
