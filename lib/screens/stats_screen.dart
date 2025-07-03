import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import '../services/balance_service.dart';
import '../widgets/stats_card.dart';
import '../widgets/stat_item.dart';
import '../widgets/profile_card.dart';
import '../widgets/chart_builders.dart';
import '../utils/app_constants.dart';
import '../utils/app_utils.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final BalanceService _balanceService = BalanceService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _expenseShares = [];
  List<Map<String, dynamic>> _createdExpenses = [];
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _balanceStats;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
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
        _balanceService.getBalanceStatistics(),
      ]);

      if (mounted) {
        setState(() {
          _profile = futures[0] as Map<String, dynamic>;
          _expenseShares = futures[1] as List<Map<String, dynamic>>;
          _createdExpenses = futures[2] as List<Map<String, dynamic>>;
          _groups = futures[3] as List<Map<String, dynamic>>;
          _balanceStats = futures[4] as Map<String, dynamic>;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppConstants.loadingError}$e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                      AppConstants.loadingMessage,
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
                        const SizedBox(height: AppConstants.defaultSpacing),
                        ChartBuilders.buildExpenseOverviewChart(
                          context,
                          _expenseShares,
                          _createdExpenses,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.defaultSpacing),
                        ChartBuilders.buildExpenseSharesChart(
                          context,
                          _expenseShares,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.defaultSpacing),
                        ChartBuilders.buildPaymentDetailsChart(
                          context,
                          _expenseShares,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.defaultSpacing),
                        _buildTransactionStats(theme),
                        const SizedBox(height: AppConstants.defaultSpacing),
                        ChartBuilders.buildPaymentStatusChart(
                          context,
                          _expenseShares,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.largeSpacing),
                        ChartBuilders.buildGroupActivityChart(
                          context,
                          _groups,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.largeSpacing),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildTransactionStats(ThemeData theme) {
    if (_balanceStats == null) {
      return const SizedBox.shrink();
    }

    final thisMonthAdded =
        (_balanceStats!['this_month_added'] as num?)?.toDouble() ?? 0.0;
    final thisMonthSpent =
        (_balanceStats!['this_month_spent'] as num?)?.toDouble() ?? 0.0;
    final lastMonthAdded =
        (_balanceStats!['last_month_added'] as num?)?.toDouble() ?? 0.0;
    final lastMonthSpent =
        (_balanceStats!['last_month_spent'] as num?)?.toDouble() ?? 0.0;
    final outstandingLoan =
        (_balanceStats!['outstanding_loan'] as num?)?.toDouble() ?? 0.0;
    final totalLoans =
        (_balanceStats!['total_loans'] as num?)?.toDouble() ?? 0.0;
    final totalRepaid =
        (_balanceStats!['total_repaid'] as num?)?.toDouble() ?? 0.0;

    final monthlyIncome = thisMonthAdded;
    final monthlyOutflow = thisMonthSpent;
    final monthlySavingsRate = AppUtils.calculateSavingsRate(
      monthlyIncome,
      monthlyOutflow,
    );
    final monthlyAddedChange = AppUtils.calculatePercentageChange(
      thisMonthAdded,
      lastMonthAdded,
    );
    final monthlySpentChange = AppUtils.calculatePercentageChange(
      thisMonthSpent,
      lastMonthSpent,
    );
    final overallRepaymentRate = AppUtils.calculateRate(
      totalLoans,
      totalRepaid,
    );

    return StatsCard(
      title: 'Transactions',
      color: theme.colorScheme.tertiary,
      children: [
        StatItem(
          label: 'Added This Month',
          value: AppUtils.formatCurrency(thisMonthAdded),
          icon: Icons.add_circle,
          color: Colors.green,
          onTap: null,
        ),
        StatItem(
          label: 'Spent This Month',
          value: AppUtils.formatCurrency(thisMonthSpent),
          icon: Icons.remove_circle,
          color: Colors.red,
          onTap: null,
        ),
        StatItem(
          label: 'Monthly Savings Rate',
          value: AppUtils.formatPercentage(monthlySavingsRate),
          icon: Icons.trending_up,
          color: AppUtils.getStatusColor(monthlySavingsRate),
          onTap: null,
        ),
        if (monthlyAddedChange != 0) ...[
          StatItem(
            label: 'Added vs Last Month',
            value: AppUtils.formatPercentageWithSign(monthlyAddedChange),
            icon: Icons.trending_up,
            color: AppUtils.getStatusColor(monthlyAddedChange),
            onTap: null,
          ),
        ],
        if (monthlySpentChange != 0) ...[
          StatItem(
            label: 'Spent vs Last Month',
            value: AppUtils.formatPercentageWithSign(monthlySpentChange),
            icon: Icons.trending_down,
            color: AppUtils.getStatusColor(
              monthlySpentChange,
              isPositive: false,
            ),
            onTap: null,
          ),
        ],
        if (totalLoans > 0) ...[
          StatItem(
            label: 'Total Loans Taken',
            value: AppUtils.formatCurrency(totalLoans),
            icon: Icons.credit_card,
            color: theme.colorScheme.error,
            onTap: null,
          ),
          StatItem(
            label: 'Total Repaid',
            value: AppUtils.formatCurrency(totalRepaid),
            icon: Icons.check_circle,
            color: Colors.green,
            onTap: null,
          ),
          StatItem(
            label: 'Overall Repayment Rate',
            value: AppUtils.formatPercentage(overallRepaymentRate),
            icon: Icons.percent,
            color: AppUtils.getRateColor(overallRepaymentRate),
            onTap: null,
          ),
        ],
        if (outstandingLoan > 0) ...[
          StatItem(
            label: 'Outstanding Loan',
            value: AppUtils.formatCurrency(outstandingLoan),
            icon: Icons.warning_amber,
            color: theme.colorScheme.error,
            onTap: null,
          ),
        ],
      ],
    );
  }
}
