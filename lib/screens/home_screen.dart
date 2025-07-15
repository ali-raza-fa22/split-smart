import 'package:flutter/material.dart';
import 'package:SPLITSMART/screens/stats_screen.dart';
import 'package:SPLITSMART/screens/profile_screen.dart';
import 'package:SPLITSMART/theme/theme.dart';
import 'package:SPLITSMART/widgets/ui/main_scaffold.dart';
import '../services/auth.dart';
import '../services/balance_service.dart';
import '../widgets/ui/balance_display.dart';
import '../widgets/add_balance_dialog.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';
import '../utils/app_utils.dart';
import '../utils/date_formatter.dart';
import '../widgets/ui/unread_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final BalanceService _balanceService = BalanceService();
  final ChatService _chatService = ChatService();

  String? _displayName;
  double? _balance;
  double? _outstandingLoan;
  bool _isLoading = true;
  List<Map<String, dynamic>> _defaultBalanceTitles = [];
  List<Map<String, dynamic>> _recentExpenses = [];
  List<Map<String, dynamic>> _userExpenseShares = [];
  bool _isLoadingExpenses = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentExpenses();
    _loadUserExpenseShares();
  }

  Future<void> _loadUserExpenseShares() async {
    try {
      final shares = await _chatService.getUserExpenseShares();
      setState(() {
        _userExpenseShares = shares;
      });
    } catch (e) {
      // ignore error
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final profile = await _authService.getUserProfile();
      final balance = await _balanceService.getCurrentBalance();
      final outstandingLoan = await _balanceService.getOutstandingLoan();
      setState(() {
        _displayName =
            (profile?['display_name'] as String?)?.split(' ').first ?? 'User';
        _balance = balance;
        _outstandingLoan = outstandingLoan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentExpenses() async {
    setState(() {
      _isLoadingExpenses = true;
    });
    try {
      final allExpenses = await _chatService.getAllUserExpenses().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Timeout while fetching expenses');
        },
      );
      setState(() {
        _recentExpenses = allExpenses.take(6).toList();
        _isLoadingExpenses = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingExpenses = false;
        _recentExpenses = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading expenses.')));
      }
    }
  }

  Future<void> _showAddBalanceDialog() async {
    if (_defaultBalanceTitles.isEmpty) {
      try {
        _defaultBalanceTitles = await _balanceService.getDefaultBalanceTitles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Something bad happened, please try again.'),
            ),
          );
        }
        return;
      }
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => AddBalanceDialog(
              defaultBalanceTitles: _defaultBalanceTitles,
              onAdd: (amount, title, description) async {
                Navigator.of(context).pop();
                try {
                  final result = await _balanceService.addBalance(
                    amount: amount,
                    title: title,
                    description: description,
                  );
                  await _loadUserData();
                  String message;
                  if (result['had_outstanding_loan']) {
                    final amountRepaid = result['amount_repaid'] as double;
                    final amountToBalance =
                        result['amount_to_balance'] as double;
                    if (amountToBalance > 0) {
                      message =
                          'Auto-repaid Rs ${amountRepaid.toStringAsFixed(2)} of loan and added Rs ${amountToBalance.toStringAsFixed(2)} to balance';
                    } else {
                      message =
                          'Auto-repaid Rs ${amountRepaid.toStringAsFixed(2)} of loan';
                    }
                  } else {
                    message =
                        'Added Rs ${amount.toStringAsFixed(2)} to balance';
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Something bad happened.')),
                    );
                  }
                }
              },
            ),
      );
    }
  }

  void _showExpenseDetailsModal(Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseDetailsModal(expenseData: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return MainScaffold(
      currentIndex: 0,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'profile':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                break;
              case 'stats':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
                break;
              case 'logout':
                _authService
                    .logout()
                    .then((_) {
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    })
                    .catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Something bad happened')),
                        );
                      }
                    });
                break;
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 8),
                      Text('Stats'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.more_vert),
          ),
        ),
      ],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadUserData(), _loadRecentExpenses()]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 18),
              // Greeting & Balance (with partial loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isLoading
                            ? Text(
                              'Loading...',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : Text(
                              'Hi ${_displayName ?? 'User'}',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        const SizedBox(width: 8),
                        const Text('👋', style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _isLoading
                            ? const BalanceDisplay(amount: null, fontSize: 28)
                            : BalanceDisplay(
                              amount: _balance,
                              color: colorScheme.primary,
                              fontSize: 28,
                            ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _loadUserData,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 16,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to update',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionButton(
                      icon: Icons.add,
                      label: 'Add Balance',
                      onTap: _showAddBalanceDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Loan Alert Card
              if ((_outstandingLoan ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Loan Active',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Outstanding Loan: Rs ${_outstandingLoan?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Active loan: Spend wisely, repay steadily.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer
                                        .withValues(alpha: 0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Quick Actions Grid
              Container(
                // color: colorScheme.primary,
                decoration: BoxDecoration(
                  color: AppColors.greyish,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Expenses',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child:
                          _isLoadingExpenses
                              ? GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 6,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio:
                                          1.2, // slightly taller for more content
                                    ),
                                itemBuilder:
                                    (context, i) =>
                                        const _ExpenseSkeletonCard(),
                              )
                              : _recentExpenses.isEmpty
                              ? Center(
                                child: Text(
                                  'No expenses found.',
                                  style: textTheme.bodyMedium,
                                ),
                              )
                              : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentExpenses.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio:
                                          1.2, // slightly taller for more content
                                    ),
                                itemBuilder:
                                    (context, i) => _HomeExpenseCard(
                                      expense: _recentExpenses[i],
                                      onTap:
                                          () => _showExpenseDetailsModal(
                                            _recentExpenses[i],
                                          ),
                                      userExpenseShares: _userExpenseShares,
                                    ),
                              ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Material(
          color: AppColors.greyish,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: colorScheme.primary, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _HomeExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback onTap;
  final List<Map<String, dynamic>> userExpenseShares;
  const _HomeExpenseCard({
    required this.expense,
    required this.onTap,
    required this.userExpenseShares,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = expense['title'] ?? 'Expense';
    final amount = (expense['total_amount'] as num?)?.toDouble() ?? 0.0;
    dynamic rawCreatedAt = expense['created_at'];
    DateTime createdAt;
    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    // Find if user has an unpaid share for this expense (amount_owed > 0 and is_paid == false)
    final unpaidShare = userExpenseShares.firstWhere(
      (share) =>
          share['expense_id'] == expense['id'] &&
          share['is_paid'] == false &&
          (share['amount_owed'] as num?) != null &&
          (share['amount_owed'] as num) > 0,
      orElse: () => {},
    );
    final showBadge = unpaidShare.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppUtils.formatCurrency(amount),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormatter.formatFullDateTime(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showBadge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: UnreadBadge(
                      count: 1,
                      size: 16,
                      color: theme.colorScheme.error,
                      showCount: false,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseSkeletonCard extends StatelessWidget {
  const _ExpenseSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 14,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
