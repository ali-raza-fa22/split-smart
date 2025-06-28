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
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance data: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Balance')),
      body: RefreshIndicator(
        onRefresh: _refreshBalanceAndStats,
        child: ListView(
          children: [_buildBalanceCard(theme), const SizedBox(height: 16)],
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

  Widget _formatCurrencyWithSuperscript(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final rupees = parts[0];
    final paise = parts[1];

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 28,
        ),
        children: [
          TextSpan(text: 'Rs $rupees'),
          TextSpan(
            text: '.$paise',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget _formatCurrencyWithSuperscriptSmall(double amount, {Color? color}) {
    final parts = amount.toStringAsFixed(2).split('.');
    final rupees = parts[0];
    final paise = parts[1];

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color ?? Theme.of(context).colorScheme.error,
          fontSize: 20,
        ),
        children: [
          TextSpan(text: 'Rs $rupees'),
          TextSpan(
            text: '.$paise',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    final currentBalance =
        (_userBalance?['current_balance'] as num?)?.toDouble() ?? 0.0;
    final outstandingLoan =
        (_balanceStats?['outstanding_loan'] as num?)?.toDouble() ?? 0.0;
    final displayBalance = currentBalance < 0 ? 0.0 : currentBalance;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main balance section
          Padding(
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
                        _formatCurrencyWithSuperscript(displayBalance),
                      ],
                    ),
                    if (outstandingLoan > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Loan Active',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Buttons row
                Column(
                  children: [
                    // Add Balance button (always visible)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddBalanceDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Balance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsible loan details section
          if (outstandingLoan > 0)
            ExpansionTile(
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
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Outstanding Loan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          _formatCurrencyWithSuperscriptSmall(outstandingLoan),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This loan will be automatically repaid when you add balance to your account.',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
