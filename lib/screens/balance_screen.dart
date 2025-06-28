import 'package:flutter/material.dart';
import '../services/balance_service.dart';
import '../widgets/add_balance_dialog.dart';

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
  Map<String, dynamic>? _balanceStats;
  List<Map<String, dynamic>> _defaultBalanceTitles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _balanceService.getUserBalance(),
        _balanceService.getBalanceStatistics(),
        _balanceService.getDefaultBalanceTitles(),
      ]);

      setState(() {
        _userBalance = results[0] as Map<String, dynamic>?;
        _balanceStats = results[1] as Map<String, dynamic>?;
        _defaultBalanceTitles = List<Map<String, dynamic>>.from(
          results[2] as List<dynamic>,
        );
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
      barrierDismissible: true,
      builder:
          (context) => AddBalanceDialog(
            defaultBalanceTitles: _defaultBalanceTitles,
            onAdd: (amount, title, description) {
              Navigator.of(context).pop();
              _addBalanceWithData(amount, title, description);
            },
          ),
    );
  }

  // Helper method to add balance with provided data
  Future<void> _addBalanceWithData(
    double amount,
    String title,
    String? description,
  ) async {
    try {
      final result = await _balanceService.addBalance(
        amount: amount,
        title: title,
        description: description,
      );

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
      builder: (context) {
        // Create controllers ONCE per dialog open
        final localAmountController = TextEditingController(
          text: _amountController.text,
        );
        final localTitleController = TextEditingController(
          text: _titleController.text,
        );
        final localDescriptionController = TextEditingController(
          text: _descriptionController.text,
        );

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Repay Loan'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (outstandingLoan > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.2),
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
                        controller: localAmountController,
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
                      const SizedBox(height: 20),
                      TextField(
                        controller: localTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g., Loan Repayment',
                        ),
                      ),
                      TextField(
                        controller: localDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Additional details',
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Copy local values to main controllers before submit
                    _amountController.text = localAmountController.text;
                    _titleController.text = localTitleController.text;
                    _descriptionController.text =
                        localDescriptionController.text;
                    Navigator.of(context).pop();
                    _repayLoan();
                  },
                  child: const Text('Repay'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Balance')),
      body: RefreshIndicator(
        onRefresh: _refreshBalanceAndStats,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 16),
            _buildBalanceCard(theme),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshBalanceAndStats() async {
    try {
      await Future.wait([
        _balanceService.getUserBalance(),
        _balanceService.getBalanceStatistics(),
      ]);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing balance: $e')));
      }
    }
  }

  Widget _buildBalanceCard(ThemeData theme) {
    final currentBalance =
        (_userBalance?['current_balance'] as num?)?.toDouble() ?? 0.0;
    final outstandingLoan =
        (_balanceStats?['outstanding_loan'] as num?)?.toDouble() ?? 0.0;
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
                      'My Wallet',
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
            const SizedBox(height: 24),
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
                if (outstandingLoan > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
