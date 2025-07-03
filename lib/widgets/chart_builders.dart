import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import '../utils/app_utils.dart';
import 'pie_chart_widget.dart';
import 'details_modal.dart';
import 'stat_item.dart';

class ChartBuilders {
  // Build expense overview pie chart
  static Widget buildExpenseOverviewChart(
    BuildContext context,
    List<Map<String, dynamic>> expenseShares,
    List<Map<String, dynamic>> createdExpenses,
    ThemeData theme,
  ) {
    final totalOwed = expenseShares
        .where((share) => !share['is_paid'])
        .fold(0.0, (sum, share) => sum + (share['amount_owed'] as num));

    final totalPaid = expenseShares
        .where((share) => share['is_paid'])
        .fold(0.0, (sum, share) => sum + (share['amount_owed'] as num));

    final totalCreated = createdExpenses.fold(
      0.0,
      (sum, expense) => sum + (expense['total_amount'] as num),
    );

    // Transform data for modals
    final owedExpenses = AppUtils.transformExpenseSharesForModal(
      expenseShares.where((share) => !share['is_paid']).toList(),
    );
    final paidExpenses = AppUtils.transformExpenseSharesForModal(
      expenseShares.where((share) => share['is_paid']).toList(),
    );
    final createdExpensesForModal = AppUtils.transformCreatedExpensesForModal(
      createdExpenses,
    );

    return PieChartWidget(
      data: [
        ChartDataItem(
          label: 'Owed',
          value: totalOwed,
          color: theme.colorScheme.error,
          icon: Icons.account_balance_wallet,
        ),
        ChartDataItem(
          label: 'Paid',
          value: totalPaid,
          color: theme.colorScheme.primary,
          icon: Icons.check_circle,
        ),
        ChartDataItem(
          label: 'Created',
          value: totalCreated,
          color: theme.colorScheme.secondary,
          icon: Icons.add_circle,
        ),
      ],
      title: 'Expense Overview',
      subtitle: 'Distribution of your expenses',
      size: AppConstants.defaultChartSize,
      onTap:
          () => _showExpenseOverviewModal(
            context,
            theme,
            totalOwed,
            totalPaid,
            totalCreated,
            owedExpenses,
            paidExpenses,
            createdExpensesForModal,
          ),
    );
  }

  // Build expense shares pie chart
  static Widget buildExpenseSharesChart(
    BuildContext context,
    List<Map<String, dynamic>> expenseShares,
    ThemeData theme,
  ) {
    final paidExpenses =
        expenseShares.where((share) => share['is_paid']).length;
    final pendingExpenses =
        expenseShares.where((share) => !share['is_paid']).length;

    return PieChartWidget(
      data: [
        ChartDataItem(
          label: 'Paid',
          value: paidExpenses.toDouble(),
          color: Colors.green,
          icon: Icons.check_circle,
        ),
        ChartDataItem(
          label: 'Pending',
          value: pendingExpenses.toDouble(),
          color: Colors.orange,
          icon: Icons.pending,
        ),
      ],
      title: 'Expense Shares',
      subtitle: 'Paid vs Pending',
      size: AppConstants.defaultChartSize,
      onTap: () => _showExpenseSharesModal(context, theme, expenseShares),
    );
  }

  // Build payment details pie chart
  static Widget buildPaymentDetailsChart(
    BuildContext context,
    List<Map<String, dynamic>> expenseShares,
    ThemeData theme,
  ) {
    return PieChartWidget(
      data: [
        ChartDataItem(
          label: 'Average',
          value: AppUtils.calculateAverageAmount(expenseShares, 'amount_owed'),
          color: theme.colorScheme.primary,
          icon: Icons.calculate,
        ),
        ChartDataItem(
          label: 'Maximum',
          value: AppUtils.calculateMaxAmount(expenseShares, 'amount_owed'),
          color: theme.colorScheme.error,
          icon: Icons.trending_up,
        ),
      ],
      title: 'Payment Details',
      subtitle: 'Average vs Maximum Amount',
      size: AppConstants.defaultChartSize,
      onTap: () => _showPaymentDetailsModal(context, theme, expenseShares),
    );
  }

  // Build payment status pie chart
  static Widget buildPaymentStatusChart(
    BuildContext context,
    List<Map<String, dynamic>> expenseShares,
    ThemeData theme,
  ) {
    final paidExpenses =
        expenseShares.where((share) => share['is_paid']).length;
    final pendingExpenses =
        expenseShares.where((share) => !share['is_paid']).length;

    final chartData = <ChartDataItem>[
      if (paidExpenses > 0)
        ChartDataItem(
          label: 'Paid',
          value: paidExpenses.toDouble(),
          color: Colors.green,
          icon: Icons.check_circle,
        ),
      if (pendingExpenses > 0)
        ChartDataItem(
          label: 'Pending',
          value: pendingExpenses.toDouble(),
          color: Colors.orange,
          icon: Icons.pending,
        ),
    ];

    return PieChartWidget(
      data: chartData,
      title: 'Payment Status',
      subtitle: 'Distribution of expense payments',
      centerText: 'Total',
      size: AppConstants.defaultChartSize,
      onTap:
          () => _showPaymentStatusModal(
            context,
            theme,
            paidExpenses,
            pendingExpenses,
          ),
    );
  }

  // Build group activity pie chart
  static Widget buildGroupActivityChart(
    BuildContext context,
    List<Map<String, dynamic>> groups,
    ThemeData theme,
  ) {
    final activeGroups =
        groups.where((group) {
          final lastMessage = group['last_message'];
          if (lastMessage == null) return false;
          return AppUtils.isItemActive(lastMessage, 'created_at');
        }).length;

    final inactiveGroups =
        groups.where((group) {
          final lastMessage = group['last_message'];
          if (lastMessage == null) {
            return true; // Groups with no messages are inactive
          } else {
            return !AppUtils.isItemActive(lastMessage, 'created_at');
          }
        }).length;

    final chartData = <ChartDataItem>[
      if (activeGroups > 0)
        ChartDataItem(
          label: 'Active',
          value: activeGroups.toDouble(),
          color: Colors.green,
          icon: Icons.chat,
        ),
      if (inactiveGroups > 0)
        ChartDataItem(
          label: 'Inactive',
          value: inactiveGroups.toDouble(),
          color: Colors.grey,
          icon: Icons.group,
        ),
    ];

    return PieChartWidget(
      data: chartData,
      title: 'Group Activity',
      subtitle: 'Distribution of group activity',
      centerText: 'Groups',
      size: AppConstants.defaultChartSize,
      onTap: () => _showGroupActivityModal(context, theme, groups),
    );
  }

  // Private modal methods
  static void _showExpenseOverviewModal(
    BuildContext context,
    ThemeData theme,
    double totalOwed,
    double totalPaid,
    double totalCreated,
    List<Map<String, dynamic>> owedExpenses,
    List<Map<String, dynamic>> paidExpenses,
    List<Map<String, dynamic>> createdExpensesForModal,
  ) {
    showDetailsModal(
      context,
      title: 'Expense Overview',
      subtitle: 'Detailed breakdown of your expenses',
      icon: Icons.pie_chart,
      children: [
        StatItem(
          label: 'Total Owed',
          value: AppUtils.formatCurrency(totalOwed),
          icon: Icons.account_balance_wallet,
          color: theme.colorScheme.error,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'Expenses You Owe',
                owedExpenses,
              ),
        ),
        StatItem(
          label: 'Total Paid',
          value: AppUtils.formatCurrency(totalPaid),
          icon: Icons.check_circle,
          color: theme.colorScheme.primary,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'Expenses You Paid',
                paidExpenses,
              ),
        ),
        StatItem(
          label: 'Total Created',
          value: AppUtils.formatCurrency(totalCreated),
          icon: Icons.add_circle,
          color: theme.colorScheme.secondary,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'Expenses You Created',
                createdExpensesForModal,
              ),
        ),
      ],
      isEmpty: false,
      totalAmount: AppUtils.formatCurrency(
        totalOwed + totalPaid + totalCreated,
      ),
      emptyTitle: 'No expenses found',
      emptySubtitle: 'You haven\'t recorded any expenses yet',
      emptyIcon: Icons.receipt_outlined,
    );
  }

  static void _showExpenseSharesModal(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> expenseShares,
  ) {
    final totalExpenses = expenseShares.length;
    final paidExpenses =
        expenseShares.where((share) => share['is_paid']).length;
    final pendingExpenses = totalExpenses - paidExpenses;
    final paymentRate =
        totalExpenses > 0 ? (paidExpenses / totalExpenses * 100) : 0.0;

    final allExpenseSharesForModal = AppUtils.transformExpenseSharesForModal(
      expenseShares,
    );
    final paidExpenseList =
        allExpenseSharesForModal.where((share) => share['is_paid']).toList();
    final pendingExpenseList =
        allExpenseSharesForModal.where((share) => !share['is_paid']).toList();

    showDetailsModal(
      context,
      title: 'Expense Shares',
      subtitle: 'Breakdown of your expense shares',
      totalAmount: totalExpenses.toString(),
      icon: Icons.pie_chart,
      children: [
        StatItem(
          label: 'Total Shares',
          value: totalExpenses.toString(),
          icon: Icons.list,
          color: theme.colorScheme.tertiary,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'All Expense Shares',
                allExpenseSharesForModal,
              ),
        ),
        StatItem(
          label: 'Payment Rate',
          value: AppUtils.formatPercentage(paymentRate),
          icon: Icons.trending_up,
          color: theme.colorScheme.primary,
          onTap: null,
        ),
        StatItem(
          label: 'Paid',
          value: paidExpenses.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'Paid Expenses',
                paidExpenseList,
              ),
        ),
        StatItem(
          label: 'Pending',
          value: pendingExpenses.toString(),
          icon: Icons.pending,
          color: Colors.orange,
          onTap:
              () => _showExpenseDetailsModal(
                context,
                'Pending Expenses',
                pendingExpenseList,
              ),
        ),
      ],
      isEmpty: totalExpenses == 0,
      emptyTitle: 'No expense shares found',
      emptySubtitle: 'You have no expense shares yet',
      emptyIcon: Icons.inbox_outlined,
    );
  }

  static void _showPaymentDetailsModal(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> expenseShares,
  ) {
    final avgAmountOwed = AppUtils.calculateAverageAmount(
      expenseShares,
      'amount_owed',
    );
    final maxAmountOwed = AppUtils.calculateMaxAmount(
      expenseShares,
      'amount_owed',
    );

    showDetailsModal(
      context,
      title: 'Payment Details',
      subtitle: 'Amount statistics',
      totalAmount: AppUtils.formatCurrency(avgAmountOwed + maxAmountOwed),
      icon: Icons.payment,
      children: [
        StatItem(
          label: 'Average Amount',
          value: AppUtils.formatCurrency(avgAmountOwed),
          icon: Icons.calculate,
          color: theme.colorScheme.primary,
          onTap: null,
        ),
        StatItem(
          label: 'Maximum Amount',
          value: AppUtils.formatCurrency(maxAmountOwed),
          icon: Icons.trending_up,
          color: theme.colorScheme.error,
          onTap: null,
        ),
      ],
      isEmpty: expenseShares.isEmpty,
      emptyTitle: 'No payment data',
      emptySubtitle: 'You have no expense shares yet',
      emptyIcon: Icons.payment_outlined,
    );
  }

  static void _showPaymentStatusModal(
    BuildContext context,
    ThemeData theme,
    int paidExpenses,
    int pendingExpenses,
  ) {
    final total = paidExpenses + pendingExpenses;
    if (total > 0) {
      showDetailsModal(
        context,
        title: 'Payment Status',
        subtitle: 'Breakdown of expense payment status',
        totalAmount: total.toString(),
        icon: Icons.payment,
        children: [
          if (paidExpenses > 0)
            _buildPaymentBreakdownItem(
              context,
              'Paid',
              paidExpenses,
              total,
              Colors.green,
              Icons.check_circle,
            ),
          if (pendingExpenses > 0)
            _buildPaymentBreakdownItem(
              context,
              'Pending',
              pendingExpenses,
              total,
              Colors.orange,
              Icons.pending,
            ),
        ],
        isEmpty: false,
        emptyTitle: 'No expenses found',
        emptySubtitle: 'You haven\'t recorded any expenses yet',
        emptyIcon: Icons.receipt_outlined,
      );
    }
  }

  static void _showGroupActivityModal(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> groups,
  ) {
    final activeGroups =
        groups.where((group) {
          final lastMessage = group['last_message'];
          if (lastMessage == null) return false;
          return AppUtils.isItemActive(lastMessage, 'created_at');
        }).toList();

    final inactiveGroups =
        groups.where((group) {
          final lastMessage = group['last_message'];
          if (lastMessage == null) return true;
          return !AppUtils.isItemActive(lastMessage, 'created_at');
        }).toList();

    final totalGroups = groups.length;
    final activityRate =
        totalGroups > 0 ? (activeGroups.length / totalGroups * 100) : 0.0;

    showDetailsModal(
      context,
      title: 'Group Activity',
      subtitle: 'Breakdown of your groups',
      totalAmount: totalGroups.toString(),
      icon: Icons.group,
      children: [
        StatItem(
          label: 'Total Groups',
          value: totalGroups.toString(),
          icon: Icons.list,
          color: theme.colorScheme.tertiary,
          onTap: null,
        ),
        StatItem(
          label: 'Activity Rate',
          value: AppUtils.formatPercentage(activityRate),
          icon: Icons.trending_up,
          color: theme.colorScheme.primary,
          onTap: null,
        ),
        if (activeGroups.isNotEmpty)
          StatItem(
            label: 'Active Groups',
            value: activeGroups.length.toString(),
            icon: Icons.chat,
            color: Colors.green,
            onTap:
                () => _showGroupListModal(
                  context,
                  'Active Groups',
                  activeGroups,
                  theme,
                ),
          ),
        if (inactiveGroups.isNotEmpty)
          StatItem(
            label: 'Inactive Groups',
            value: inactiveGroups.length.toString(),
            icon: Icons.group,
            color: Colors.grey,
            onTap:
                () => _showGroupListModal(
                  context,
                  'Inactive Groups',
                  inactiveGroups,
                  theme,
                ),
          ),
      ],
      isEmpty: groups.isEmpty,
      emptyTitle: 'No groups found',
      emptySubtitle: 'You have no groups yet',
      emptyIcon: Icons.group_outlined,
    );
  }

  static void _showGroupListModal(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> groups,
    ThemeData theme,
  ) {
    showDetailsModal(
      context,
      title: title,
      subtitle: '${groups.length} group${groups.length != 1 ? 's' : ''}',
      totalAmount: groups.length.toString(),
      icon: Icons.group,
      children:
          groups.map((group) {
            final groupName = group['name'] ?? 'Unknown Group';
            final memberCount = group['member_count'] ?? 0;
            final lastMessage = group['last_message'];
            String lastActivity = 'No messages';

            if (lastMessage != null) {
              try {
                final messageTime = DateTime.parse(lastMessage['created_at']);
                lastActivity = AppUtils.formatDateTime(messageTime);
              } catch (e) {
                lastActivity = 'Recent activity';
              }
            }

            return StatItem(
              label: '$groupName • $lastActivity',
              value: '$memberCount members',
              icon: Icons.group,
              color: theme.colorScheme.primary,
              onTap: null,
            );
          }).toList(),
      isEmpty: groups.isEmpty,
      emptyTitle: 'No groups found',
      emptySubtitle: 'There are no groups in this category',
      emptyIcon: Icons.group_outlined,
    );
  }

  static void _showExpenseDetailsModal(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> expenses,
  ) {
    showDetailsModal(
      context,
      title: title,
      subtitle: '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
      totalAmount: AppUtils.formatCurrency(
        expenses.fold(
          0.0,
          (sum, expense) =>
              sum + (expense['amount_owed'] ?? expense['total_amount'] ?? 0),
        ),
      ),
      icon: Icons.receipt_long,
      children:
          expenses.map((expense) {
            final expenseName = expense['expense_name'] ?? 'Unknown Expense';
            final groupName = expense['group_name'] ?? 'Unknown Group';
            final amount =
                expense['amount_owed'] ?? expense['total_amount'] ?? 0.0;
            final isPaid = expense['is_paid'] ?? false;

            return StatItem(
              label: '$expenseName • $groupName',
              value: AppUtils.formatCurrency(amount),
              icon: isPaid ? Icons.check_circle : Icons.pending,
              color: isPaid ? Colors.green : Colors.orange,
              onTap: null,
            );
          }).toList(),
      isEmpty: expenses.isEmpty,
      emptyTitle: 'No expenses found',
      emptySubtitle: 'There are no expenses in this category yet',
      emptyIcon: Icons.inbox_outlined,
    );
  }

  static Widget _buildPaymentBreakdownItem(
    BuildContext context,
    String label,
    int value,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$value expenses (${percentage.toStringAsFixed(1)}%)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
