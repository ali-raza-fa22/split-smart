import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import '../utils/app_utils.dart';
import 'pie_chart_widget.dart';
import 'details_modal.dart';
import 'stat_item.dart';

class ChartBuilders {
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
          color: Theme.of(context).colorScheme.tertiary,
          icon: Icons.check_circle_outline,
        ),
        ChartDataItem(
          label: 'Pending',
          value: pendingExpenses.toDouble(),
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.pending_outlined,
        ),
      ],
      title: 'Your expenses',
      subtitle: 'Paid vs Pending',
      size: AppConstants.defaultChartSize,
      onTap: () => _showExpenseSharesModal(context, theme, expenseShares),
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
          color: Theme.of(context).colorScheme.tertiary,
          icon: Icons.chat_outlined,
        ),
      if (inactiveGroups > 0)
        ChartDataItem(
          label: 'Inactive',
          value: inactiveGroups.toDouble(),
          color: Colors.grey,
          icon: Icons.group_outlined,
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
      subtitle: 'Breakdown of your expenses',
      totalAmount: totalExpenses.toString(),
      icon: Icons.pie_chart_outline,
      children: [
        StatItem(
          label: 'Total Shares',
          value: totalExpenses.toString(),
          icon: Icons.list_outlined,
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
          icon: Icons.trending_up_outlined,

          onTap: null,
        ),
        StatItem(
          label: 'Paid',
          value: paidExpenses.toString(),
          icon: Icons.check_circle_outline,
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
          icon: Icons.pending_outlined,
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

    showDetailsModal(
      context,
      title: 'Group Activity',
      subtitle: 'Breakdown of your groups',
      totalAmount: totalGroups.toString(),
      icon: Icons.group_outlined,
      children: [
        StatItem(
          label: 'Total Groups',
          value: totalGroups.toString(),
          icon: Icons.list_outlined,
          onTap: null,
        ),

        if (activeGroups.isNotEmpty)
          StatItem(
            label: 'Active Groups',
            value: activeGroups.length.toString(),
            icon: Icons.chat_outlined,
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
            icon: Icons.group_outlined,
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
      icon: Icons.group_outlined,
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
              icon: Icons.group_outlined,
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
      icon: Icons.receipt_long_outlined,
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
              icon: isPaid ? Icons.check_circle_outline : Icons.pending,
              onTap: null,
            );
          }).toList(),
      isEmpty: expenses.isEmpty,
      emptyTitle: 'No expenses found',
      emptySubtitle: 'There are no expenses in this category yet',
      emptyIcon: Icons.inbox_outlined,
    );
  }
}
