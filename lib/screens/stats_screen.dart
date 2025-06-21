import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import '../widgets/stats_card.dart';
import '../widgets/stat_item.dart';
import '../widgets/profile_card.dart';
import '../widgets/details_modal.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _expenseShares = [];
  List<Map<String, dynamic>> _createdExpenses = [];
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _authService.getUserProfile(),
        _chatService.getUserExpenseShares(),
        _chatService.getUserCreatedExpenses(),
        _chatService.getUserGroupsWithDetails(),
      ]);

      if (mounted) {
        setState(() {
          _profile = futures[0] as Map<String, dynamic>;
          _expenseShares = futures[1] as List<Map<String, dynamic>>;
          _createdExpenses = futures[2] as List<Map<String, dynamic>>;
          _groups = futures[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showExpenseDetailsModal(
    String title,
    List<Map<String, dynamic>> expenses,
  ) {
    final totalAmount = expenses.fold(
      0.0,
      (sum, expense) =>
          sum + (expense['amount_owed'] ?? expense['total_amount'] ?? 0),
    );

    final expenseItems =
        expenses.map((expense) {
          final amount = expense['amount_owed'] ?? expense['total_amount'] ?? 0;
          final expenseName = expense['expense_name'] ?? 'Unknown Expense';
          final groupName = expense['group_name'] ?? 'Unknown Group';
          final isPaid = expense['is_paid'] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPaid
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.receipt,
                  color:
                      isPaid
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              title: Text(
                expenseName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    groupName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isPaid ? Colors.green : Colors.orange).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          );
        }).toList();

    showDetailsModal(
      context,
      title: title,
      subtitle: '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
      totalAmount: '\$${totalAmount.toStringAsFixed(2)}',
      icon: Icons.receipt_long,
      children: expenseItems,
      isEmpty: expenses.isEmpty,
      emptyTitle: 'No expenses found',
      emptySubtitle: 'There are no expenses in this category yet',
      emptyIcon: Icons.inbox_outlined,
    );
  }

  void _showGroupDetailsModal(String title, List<Map<String, dynamic>> groups) {
    final activeGroups =
        groups.where((group) => group['last_message_at'] != null).length;

    final groupItems =
        groups.map((group) {
          final groupName = group['name'] ?? 'Unknown Group';
          final isActive = group['last_message_at'] != null;
          final memberCount = group['member_count'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isActive ? Colors.green : Colors.grey).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.chat : Icons.group,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 18,
                ),
              ),
              title: Text(
                groupName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '$memberCount member${memberCount != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? Colors.green : Colors.grey).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              trailing:
                  isActive
                      ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.circle,
                          color: Colors.green,
                          size: 12,
                        ),
                      )
                      : null,
            ),
          );
        }).toList();

    showDetailsModal(
      context,
      title: title,
      subtitle:
          '${groups.length} group${groups.length != 1 ? 's' : ''} • $activeGroups active',
      totalAmount:
          '${(activeGroups / groups.length * 100).toStringAsFixed(0)}%',
      icon: Icons.group,
      children: groupItems,
      isEmpty: groups.isEmpty,
      emptyTitle: 'No groups found',
      emptySubtitle: 'There are no groups in this category yet',
      emptyIcon: Icons.group_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading statistics...',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileCard(profile: _profile),
                        const SizedBox(height: 20),
                        _buildOverviewStats(theme),
                        const SizedBox(height: 20),
                        _buildExpenseStats(theme),
                        const SizedBox(height: 20),
                        _buildPaymentStats(theme),
                        const SizedBox(height: 20),
                        _buildGroupStats(theme),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildOverviewStats(ThemeData theme) {
    final totalOwed = _expenseShares
        .where((share) => !share['is_paid'])
        .fold(0.0, (sum, share) => sum + (share['amount_owed'] as num));

    final totalPaid = _expenseShares
        .where((share) => share['is_paid'])
        .fold(0.0, (sum, share) => sum + (share['amount_owed'] as num));

    final totalCreated = _createdExpenses.fold(
      0.0,
      (sum, expense) => sum + (expense['total_amount'] as num),
    );

    // Transform expense shares to include expense details for modals
    final owedExpenses =
        _expenseShares
            .where((share) => !share['is_paid'])
            .map(
              (share) => {
                'expense_name':
                    share['expenses']?['title'] ?? 'Unknown Expense',
                'group_name':
                    share['expenses']?['groups']?['name'] ?? 'Unknown Group',
                'amount_owed': share['amount_owed'],
                'is_paid': share['is_paid'],
              },
            )
            .toList();

    final paidExpenses =
        _expenseShares
            .where((share) => share['is_paid'])
            .map(
              (share) => {
                'expense_name':
                    share['expenses']?['title'] ?? 'Unknown Expense',
                'group_name':
                    share['expenses']?['groups']?['name'] ?? 'Unknown Group',
                'amount_owed': share['amount_owed'],
                'is_paid': share['is_paid'],
              },
            )
            .toList();

    // Transform created expenses for modal
    final createdExpensesForModal =
        _createdExpenses
            .map(
              (expense) => {
                'expense_name': expense['title'] ?? 'Unknown Expense',
                'group_name': expense['groups']?['name'] ?? 'Unknown Group',
                'total_amount': expense['total_amount'],
                'is_paid':
                    true, // Created expenses are considered "paid" by creator
              },
            )
            .toList();

    return StatsCard(
      title: 'Overview',
      icon: Icons.analytics,
      color: theme.colorScheme.primary,
      children: [
        StatItem(
          label: 'Total Owed',
          value: '\$${totalOwed.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet,
          color: theme.colorScheme.error,
          onTap:
              () => _showExpenseDetailsModal('Expenses You Owe', owedExpenses),
        ),
        StatItem(
          label: 'Total Paid',
          value: '\$${totalPaid.toStringAsFixed(2)}',
          icon: Icons.check_circle,
          color: theme.colorScheme.primary,
          onTap:
              () => _showExpenseDetailsModal('Expenses You Paid', paidExpenses),
        ),
        StatItem(
          label: 'Total Created',
          value: '\$${totalCreated.toStringAsFixed(2)}',
          icon: Icons.add_circle,
          color: theme.colorScheme.secondary,
          onTap:
              () => _showExpenseDetailsModal(
                'Expenses You Created',
                createdExpensesForModal,
              ),
        ),
      ],
    );
  }

  Widget _buildExpenseStats(ThemeData theme) {
    final totalExpenses = _expenseShares.length;
    final paidExpenses =
        _expenseShares.where((share) => share['is_paid']).length;
    final pendingExpenses = totalExpenses - paidExpenses;
    final paymentRate =
        totalExpenses > 0 ? (paidExpenses / totalExpenses * 100) : 0.0;

    // Transform expense shares for modals
    final allExpenseSharesForModal =
        _expenseShares
            .map(
              (share) => {
                'expense_name':
                    share['expenses']?['title'] ?? 'Unknown Expense',
                'group_name':
                    share['expenses']?['groups']?['name'] ?? 'Unknown Group',
                'amount_owed': share['amount_owed'],
                'is_paid': share['is_paid'],
              },
            )
            .toList();

    final paidExpenseList =
        allExpenseSharesForModal.where((share) => share['is_paid']).toList();

    final pendingExpenseList =
        allExpenseSharesForModal.where((share) => !share['is_paid']).toList();

    return StatsCard(
      title: 'Expense Statistics',
      icon: Icons.receipt_long,
      color: theme.colorScheme.secondary,
      children: [
        StatItem(
          label: 'Total Shares',
          value: totalExpenses.toString(),
          icon: Icons.list,
          color: theme.colorScheme.tertiary,
          onTap:
              () => _showExpenseDetailsModal(
                'All Expense Shares',
                allExpenseSharesForModal,
              ),
        ),
        StatItem(
          label: 'Payment Rate',
          value: '${paymentRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: theme.colorScheme.primary,
          onTap: null, // No details for percentage
        ),
        StatItem(
          label: 'Paid',
          value: paidExpenses.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
          onTap:
              () => _showExpenseDetailsModal('Paid Expenses', paidExpenseList),
        ),
        StatItem(
          label: 'Pending',
          value: pendingExpenses.toString(),
          icon: Icons.pending,
          color: Colors.orange,
          onTap:
              () => _showExpenseDetailsModal(
                'Pending Expenses',
                pendingExpenseList,
              ),
        ),
      ],
    );
  }

  Widget _buildPaymentStats(ThemeData theme) {
    final avgAmountOwed =
        _expenseShares.isNotEmpty
            ? _expenseShares.fold(
                  0.0,
                  (sum, share) => sum + (share['amount_owed'] as num),
                ) /
                _expenseShares.length
            : 0.0;

    final maxAmountOwed =
        _expenseShares.isNotEmpty
            ? _expenseShares.fold(
              0.0,
              (max, share) =>
                  (share['amount_owed'] as num) > max
                      ? (share['amount_owed'] as num).toDouble()
                      : max,
            )
            : 0.0;

    return StatsCard(
      title: 'Payment Details',
      icon: Icons.payment,
      color: theme.colorScheme.tertiary,
      children: [
        StatItem(
          label: 'Avg Amount',
          value: '\$${avgAmountOwed.toStringAsFixed(2)}',
          icon: Icons.calculate,
          color: theme.colorScheme.primary,
          onTap: null, // No details for average
        ),
        StatItem(
          label: 'Max Amount',
          value: '\$${maxAmountOwed.toStringAsFixed(2)}',
          icon: Icons.trending_up,
          color: theme.colorScheme.error,
          onTap: null, // No details for max
        ),
      ],
    );
  }

  Widget _buildGroupStats(ThemeData theme) {
    final totalGroups = _groups.length;
    final activeGroups =
        _groups.where((group) => group['last_message_at'] != null).length;

    final activeGroupList =
        _groups.where((group) => group['last_message_at'] != null).toList();

    return StatsCard(
      title: 'Group Statistics',
      icon: Icons.group,
      color: theme.colorScheme.primary,
      children: [
        StatItem(
          label: 'Total Groups',
          value: totalGroups.toString(),
          icon: Icons.group,
          color: theme.colorScheme.primary,
          onTap: () => _showGroupDetailsModal('All Groups', _groups),
        ),
        StatItem(
          label: 'Active Groups',
          value: activeGroups.toString(),
          icon: Icons.chat,
          color: theme.colorScheme.secondary,
          onTap: () => _showGroupDetailsModal('Active Groups', activeGroupList),
        ),
      ],
    );
  }
}
