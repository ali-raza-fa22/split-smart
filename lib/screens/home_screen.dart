import 'package:flutter/material.dart';
import 'package:split_smart_supabase/screens/stats_screen.dart';
import 'package:split_smart_supabase/screens/profile_screen.dart';
import 'package:split_smart_supabase/widgets/ui/main_scaffold.dart';
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
      setState(() {
        _displayName =
            (profile?['display_name'] as String?)?.split(' ').first ?? 'User';
        _balance = balance;
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
        ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
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
            SnackBar(content: Text('Error loading balance titles: $e')),
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
                      SnackBar(content: Text('Error adding balance: $e')),
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
                          SnackBar(content: Text('Error logging out: $e')),
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
                            ? Container(
                              width: 90,
                              height: 28,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 24),
              // Quick Actions Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Expenses',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                                      childAspectRatio: 1.4,
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
                                      childAspectRatio: 1.4,
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
          color: colorScheme.surface,
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
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    DateFormatter.formatFullDateTime(createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
