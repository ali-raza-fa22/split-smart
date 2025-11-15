import 'package:SPLITSMART/utils/app_utils.dart';
import 'package:SPLITSMART/widgets/brand_button_2.dart';
import 'package:SPLITSMART/widgets/categoryfilter_dialog.dart';
import 'package:SPLITSMART/widgets/datefilter_dialog.dart';
import 'package:SPLITSMART/widgets/ui/main_scaffold.dart';
import 'package:flutter/material.dart';

import '../services/balance_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/save_transaction_button.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final BalanceService _balanceService = BalanceService();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // Filter states
  String _selectedDateFilter = 'all';
  String _selectedCategoryFilter = 'all';
  String _selectedDirection = 'all';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final txs = await _balanceService.getTransactionHistory();
      // Normalize transaction types: only keep 'add' and 'spend'.
      // Any non-'add' type is treated as 'spend' to safely remove other types.
      final normalized =
          txs.map((tx) {
            final t = Map<String, dynamic>.from(tx);
            final type = (t['transaction_type'] as String?) ?? 'spend';
            t['transaction_type'] = type == 'add' ? 'add' : 'spend';
            return t;
          }).toList();

      setState(() {
        _transactions = normalized;
        _filteredTransactions = normalized;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_transactions);

    // Apply date filter
    if (_selectedDateFilter != 'all') {
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      switch (_selectedDateFilter) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'custom':
          startDate = _customStartDate;
          endDate = _customEndDate;
          break;
      }

      if (startDate != null && endDate != null) {
        filtered =
            filtered.where((tx) {
              final txDate = DateTime.parse(tx['created_at']);
              return txDate.isAfter(
                    startDate!.subtract(const Duration(seconds: 1)),
                  ) &&
                  txDate.isBefore(endDate!.add(const Duration(seconds: 1)));
            }).toList();
      }
    }

    // Apply direction filter. Since we only support 'add' and 'spend',
    // received => 'add', sent => 'spend'.
    if (_selectedDirection == 'received') {
      filtered =
          filtered.where((tx) => tx['transaction_type'] == 'add').toList();
    } else if (_selectedDirection == 'sent') {
      filtered =
          filtered.where((tx) => tx['transaction_type'] == 'spend').toList();
    } else {
      // Apply category filter only if direction is 'all'
      if (_selectedCategoryFilter != 'all') {
        filtered =
            filtered.where((tx) {
              return tx['transaction_type'] == _selectedCategoryFilter;
            }).toList();
      }
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  void _showDateFilterDialog() async {
    if (_selectedDateFilter != 'all') {
      setState(() {
        _selectedDateFilter = 'all';
        _customStartDate = null;
        _customEndDate = null;
      });
      _applyFilters();
      return;
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DateFilterDialog(
            selected: _selectedDateFilter,
            customStart: _customStartDate,
            customEnd: _customEndDate,
          ),
    );
    if (result != null && result['filter'] != null) {
      setState(() {
        _selectedDateFilter = result['filter'];
        if (result['filter'] == 'custom') {
          _customStartDate = result['customStart'];
          _customEndDate = result['customEnd'];
        } else {
          _customStartDate = null;
          _customEndDate = null;
        }
      });
      _applyFilters();
    }
  }

  void _showCategoryFilterDialog() async {
    if (_selectedCategoryFilter != 'all') {
      setState(() {
        _selectedCategoryFilter = 'all';
      });
      _applyFilters();
      return;
    }
    String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CategoryFilterDialog(selected: _selectedCategoryFilter),
    );
    if (selected != null) {
      setState(() {
        _selectedCategoryFilter = selected;
        _selectedDirection = 'all';
      });
      _applyFilters();
    }
  }

  void _showDirectionDialog(String direction) {
    if (_selectedDirection == direction) {
      setState(() {
        _selectedDirection = 'all';
      });
      _applyFilters();
      return;
    }
    setState(() {
      _selectedDirection = direction;
      _selectedCategoryFilter = 'all';
    });
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _selectedDateFilter = 'all';
      _selectedCategoryFilter = 'all';
      _selectedDirection = 'all';
      _customStartDate = null;
      _customEndDate = null;
      _filteredTransactions = _transactions;
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'add':
        return Icons.south_west;
      case 'spend':
        return Icons.north_east;
      default:
        // Treat unknown types as 'spend' visually
        return Icons.north_east;
    }
  }

  Color _colorForType(BuildContext context, String type) {
    switch (type) {
      case 'add':
        return Theme.of(context).colorScheme.tertiary;
      case 'spend':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  List<Map<String, dynamic>> _getTabFilteredTransactions(int tabIndex) {
    if (tabIndex == 1) {
      // Spendings: only 'spend' transactions
      return _transactions
          .where((tx) => tx['transaction_type'] == 'spend')
          .toList();
    }
    // All Payments: use filtered transactions
    return _filteredTransactions;
  }

  String _getFilterSummary() {
    final hasDateFilter = _selectedDateFilter != 'all';
    final hasCategoryFilter = _selectedCategoryFilter != 'all';
    final hasDirectionFilter = _selectedDirection != 'all';

    if (!hasDateFilter && !hasCategoryFilter && !hasDirectionFilter) return '';

    final parts = <String>[];
    if (hasDateFilter) {
      switch (_selectedDateFilter) {
        case 'today':
          parts.add('Today');
          break;
        case 'this_week':
          parts.add('This Week');
          break;
        case 'this_month':
          parts.add('This Month');
          break;
        case 'custom':
          if (_customStartDate != null && _customEndDate != null) {
            parts.add(
              '${DateFormatter.formatDate(_customStartDate!)} - ${DateFormatter.formatDate(_customEndDate!)}',
            );
          } else {
            parts.add('Custom Range');
          }
          break;
      }
    }
    if (hasCategoryFilter) {
      parts.add(
        _selectedCategoryFilter[0].toUpperCase() +
            _selectedCategoryFilter.substring(1),
      );
    }
    if (hasDirectionFilter) {
      if (_selectedDirection == 'received') {
        parts.add('Received');
      } else if (_selectedDirection == 'sent') {
        parts.add('Sent');
      }
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterSummary = _getFilterSummary();

    return MainScaffold(
      currentIndex: 1,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [Tab(text: 'All Payments'), Tab(text: 'Spendings')],
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.onPrimary,
        // unselectedLabelColor: Theme.of(context).colorScheme.tertiary,
      ),
      body: Column(
        children: [
          // Filter indicator
          if (filterSummary.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: theme.colorScheme.tertiary,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: theme.colorScheme.onTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filterSummary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    color: theme.colorScheme.onPrimaryContainer,
                    tooltip: 'Clear all filters',
                    onPressed: _clearFilters,
                  ),
                ],
              ),
            ),

          // Results count
          if (_filteredTransactions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                '${_filteredTransactions.length} transaction${_filteredTransactions.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),

          // Main content
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text('Someting bad happened.'))
                    : _filteredTransactions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            filterSummary.isNotEmpty
                                ? 'No transactions match your filters'
                                : 'No transactions found.',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (filterSummary.isNotEmpty) ...[
                            FilledButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Filters'),
                            ),
                          ],
                        ],
                      ),
                    )
                    : TabBarView(
                      controller: _tabController,
                      children: List.generate(2, (tabIndex) {
                        final tabFiltered = _getTabFilteredTransactions(
                          tabIndex,
                        );

                        return Column(
                          children: [
                            // Filter buttons - only show on All Payments tab
                            if (tabIndex == 0)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      BrandButton2(
                                        label: 'Date',
                                        icon: Icons.arrow_drop_down,
                                        isActive: _selectedDateFilter != 'all',
                                        onPressed: _showDateFilterDialog,
                                      ),
                                      const SizedBox(width: 6),
                                      BrandButton2(
                                        label: 'Categories',
                                        icon: Icons.arrow_drop_down,
                                        isActive:
                                            _selectedCategoryFilter != 'all',
                                        onPressed: _showCategoryFilterDialog,
                                      ),
                                      const SizedBox(width: 6),
                                      BrandButton2(
                                        label: 'Received',
                                        icon: Icons.south_west,
                                        isActive:
                                            _selectedDirection == 'received',
                                        onPressed:
                                            () => _showDirectionDialog(
                                              'received',
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      BrandButton2(
                                        label: 'Sent',
                                        icon: Icons.north_east,
                                        isActive: _selectedDirection == 'sent',
                                        onPressed:
                                            () => _showDirectionDialog('sent'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Transaction list
                            Expanded(
                              child:
                                  tabFiltered.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              tabIndex == 1
                                                  ? Icons.remove_circle_outline
                                                  : Icons
                                                      .account_balance_wallet,
                                              size: 64,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No ${tabIndex == 1 ? 'spending' : 'payment'} transactions found.',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ],
                                        ),
                                      )
                                      : RefreshIndicator(
                                        onRefresh: _loadTransactions,

                                        child: ListView.builder(
                                          itemCount:
                                              tabFiltered.length +
                                              (tabIndex == 1 &&
                                                      tabFiltered.isNotEmpty
                                                  ? 1
                                                  : 0),
                                          itemBuilder: (context, i) {
                                            if (tabIndex == 1 &&
                                                tabFiltered.isNotEmpty &&
                                                i == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                // child: Text("ali"),
                                              );
                                            }

                                            // Adjust index for transaction items when pie chart is present
                                            final txIndex =
                                                tabIndex == 1 &&
                                                        tabFiltered.isNotEmpty
                                                    ? i - 1
                                                    : i;
                                            final tx = tabFiltered[txIndex];
                                            final type =
                                                tx['transaction_type']
                                                    as String? ??
                                                '';
                                            final amount =
                                                (tx['amount'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final title =
                                                tx['title'] as String? ?? '';
                                            final date =
                                                tx['created_at'] as String?;

                                            return Column(
                                              children: [
                                                if (i > 0 || tabIndex == 0)
                                                  const Divider(height: 0),
                                                ListTile(
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                  leading: Icon(
                                                    _iconForType(type),
                                                    color: _colorForType(
                                                      context,
                                                      type,
                                                    ),
                                                    size: 28,
                                                  ),
                                                  title: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        title,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        AppUtils.formatCurrency(
                                                          amount,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        type[0].toUpperCase() +
                                                            type.substring(1),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: _colorForType(
                                                            context,
                                                            type,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        DateFormatter.formatFullDateTime(
                                                          date,
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  trailing:
                                                      SaveTransactionButton(
                                                        transaction: tx,
                                                        isCompact: true,
                                                      ),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                TransactionDetailScreen(
                                                                  transaction:
                                                                      tx,
                                                                ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                            ),
                          ],
                        );
                      }),
                    ),
          ),
        ],
      ),
    );
  }
}
