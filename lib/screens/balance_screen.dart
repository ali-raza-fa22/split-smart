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
  bool _isLoading = true;
  bool _isLoanSectionExpanded = false;
  List<Map<String, dynamic>> _defaultBalanceTitles = [];
  String? _selectedBalanceTitle;
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
        _balanceService.getBalanceStatistics(),
        _balanceService.getDefaultBalanceTitles(),
      ]);

      setState(() {
        _userBalance = results[0] as Map<String, dynamic>?;
        _balanceStats = results[2] as Map<String, dynamic>?;
        _defaultBalanceTitles = List<Map<String, dynamic>>.from(
          results[3] as List<dynamic>,
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
    _selectedBalanceTitle = null;

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
    _selectedBalanceTitle = null;

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
        String? localSelectedTitle = _selectedBalanceTitle;

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
                      DropdownButtonFormField<String>(
                        value: localSelectedTitle,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select a title or type custom'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'Loan Repayment',
                            child: Row(
                              children: [
                                Icon(Icons.payment, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text('Loan Repayment')),
                              ],
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Partial Loan Repayment',
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text('Partial Loan Repayment')),
                              ],
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Full Loan Repayment',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text('Full Loan Repayment')),
                              ],
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'custom',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text('Custom title...')),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            localSelectedTitle = value;
                            if (value != null && value != 'custom') {
                              localTitleController.text = value;
                              if (value == 'Full Loan Repayment' &&
                                  outstandingLoan > 0) {
                                localAmountController.text = outstandingLoan
                                    .toStringAsFixed(2);
                              }
                            } else {
                              localTitleController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (localSelectedTitle == 'custom')
                        TextField(
                          controller: localTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Custom Title',
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
                    _titleController.text =
                        localSelectedTitle == 'custom'
                            ? localTitleController.text
                            : (localSelectedTitle ?? '');
                    _descriptionController.text =
                        localDescriptionController.text;
                    _selectedBalanceTitle = localSelectedTitle;
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
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.2),
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
}
