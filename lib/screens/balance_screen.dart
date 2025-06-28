import 'package:flutter/material.dart';
import 'package:split_smart_supabase/utils/constants.dart';
import '../services/balance_service.dart';
import '../utils/date_formatter.dart';
import 'balance_transaction_detail_screen.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen>
    with SingleTickerProviderStateMixin {
  final BalanceService _balanceService = BalanceService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Map<String, dynamic>? _userBalance;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _balanceStats;
  bool _isLoading = true;
  bool _isLoanSectionExpanded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _balanceService.getUserBalance(),
        _balanceService.getTransactionHistory(limit: 50),
        _balanceService.getBalanceStatistics(),
      ]);

      setState(() {
        _userBalance = results[0] as Map<String, dynamic>?;
        _transactions = List<Map<String, dynamic>>.from(
          results[1] as List<dynamic>,
        );
        _balanceStats = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance data: $e')),
        );
      }
    }
  }

  Future<void> _addBalance() async {
    final amount = double.tryParse(_amountController.text);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    try {
      final result = await _balanceService.addBalance(
        amount: amount,
        title: title,
        description: description.isNotEmpty ? description : null,
      );

      _amountController.clear();
      _titleController.clear();
      _descriptionController.clear();

      await _loadData();

      if (mounted) {
        String message;
        if (result['had_outstanding_loan']) {
          final amountRepaid = result['amount_repaid'] as double;
          final amountToBalance = result['amount_to_balance'] as double;

          if (amountToBalance > 0) {
            message =
                'Auto-repaid Rs ${amountRepaid.toStringAsFixed(2)} of loan and added Rs ${amountToBalance.toStringAsFixed(2)} to balance';
          } else {
            message =
                'Auto-repaid Rs ${amountRepaid.toStringAsFixed(2)} of loan';
          }
        } else {
          message = 'Added Rs ${amount.toStringAsFixed(2)} to balance';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding balance: $e')));
      }
    }
  }

  Future<void> _repayLoan() async {
    final amount = double.tryParse(_amountController.text);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    try {
      await _balanceService.repayLoan(
        amount: amount,
        title: title,
        description: description.isNotEmpty ? description : null,
      );

      _amountController.clear();
      _titleController.clear();
      _descriptionController.clear();

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repaid Rs ${amount.toStringAsFixed(2)} of loan'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error repaying loan: $e';
        if (e.toString().contains(
          'Cannot repay more than the outstanding loan amount',
        )) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  void _showAddBalanceDialog() {
    _amountController.clear();
    _titleController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Balance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rs)',
                    prefixText: 'Rs ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Salary, Freelance',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Additional details',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _addBalance();
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showRepayLoanDialog() async {
    _amountController.clear();
    _titleController.clear();
    _descriptionController.clear();

    // Get current outstanding loan amount
    double outstandingLoan = 0.0;
    try {
      outstandingLoan = await _balanceService.getOutstandingLoan();
    } catch (e) {
      // Handle error silently
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Repay Loan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (outstandingLoan > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Outstanding loan: Rs ${outstandingLoan.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (Rs)',
                    prefixText: 'Rs ',
                    hintText:
                        outstandingLoan > 0
                            ? 'Max: ${outstandingLoan.toStringAsFixed(2)}'
                            : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Loan Repayment',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Additional details',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _repayLoan();
                },
                child: const Text('Repay'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Balance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SizedBox(height: 16),
                  _buildBalanceCard(theme),
                  const SizedBox(height: 16),
                  _buildRecentTransactionsSection(theme),
                ],
              ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    final currentBalance =
        (_userBalance?['current_balance'] as num?)?.toDouble() ?? 0.0;
    final outstandingLoan =
        (_balanceStats?['outstanding_loan'] as num?)?.toDouble() ?? 0.0;

    // Show 0 instead of negative balance
    final displayBalance = currentBalance < 0 ? 0.0 : currentBalance;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Balance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${displayBalance.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (outstandingLoan > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Outstanding Loan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${outstandingLoan.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // Collapsible loan section
            if (outstandingLoan > 0) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                initiallyExpanded: _isLoanSectionExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isLoanSectionExpanded = expanded;
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loan Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Outstanding Amount:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs ${outstandingLoan.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Borrowed:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs ${(_balanceStats?['total_loans'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Repaid:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs ${(_balanceStats?['total_repaid'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showRepayLoanDialog,
                            icon: const Icon(Icons.payment),
                            label: const Text('Repay Loan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddBalanceDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text('No balance transactions.'),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'All Transactions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final tx = _transactions[index];
            final hasExpense = tx['expense_shares']?['expenses'] != null;
            final hasGroup = tx['expense_shares']?['groups'] != null;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  tx['transaction_type'] == 'add'
                      ? Icons.add
                      : tx['transaction_type'] == 'spend'
                      ? Icons.remove
                      : tx['transaction_type'] == 'loan'
                      ? Icons.trending_down
                      : Icons.autorenew,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                '${AppConstants.getTransactionTypeLabel(tx['transaction_type'])}: Rs ${(tx['amount'] as num?)?.toStringAsFixed(2) ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasExpense)
                    Text(
                      'Expense: ${tx['expense_shares']['expenses']['title']}',
                    ),
                  if (hasGroup)
                    Text('Group: ${tx['expense_shares']['groups']['name']}'),
                  Text(
                    'Date: ${DateFormatter.formatFullDateTime(tx['created_at'])}',
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            BalanceTransactionDetailScreen(transaction: tx),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
