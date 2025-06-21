import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../services/chat_service.dart';
import '../widgets/expense_details_modal.dart';
import 'edit_profile_screen.dart';
import 'chat_list_screen.dart';
import 'all_expense_shares_screen.dart';
import 'all_created_expenses_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _expenseShares = [];
  List<Map<String, dynamic>> _createdExpenses = [];
  bool _isLoading = true;
  bool _isLoadingExpenses = true;
  bool _isLoadingCreatedExpenses = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadExpenseShares();
    _loadCreatedExpenses();
  }

  Future<void> _refreshExpenseData() async {
    await _loadExpenseShares();
    await _loadCreatedExpenses();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getUserProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _loadExpenseShares() async {
    try {
      setState(() {
        _isLoadingExpenses = true;
      });

      final shares = await _chatService.getUserExpenseShares();
      if (mounted) {
        setState(() {
          _expenseShares = shares;
          _isLoadingExpenses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExpenses = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expense shares: $e')),
        );
      }
    }
  }

  Future<void> _loadCreatedExpenses() async {
    try {
      setState(() {
        _isLoadingCreatedExpenses = true;
      });

      final expenses = await _chatService.getUserCreatedExpenses();
      if (mounted) {
        setState(() {
          _createdExpenses = expenses;
          _isLoadingCreatedExpenses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCreatedExpenses = false;
        });
      }
    }
  }

  Future<void> _markAsPaid(String expenseShareId) async {
    try {
      await _chatService.markExpenseShareAsPaid(expenseShareId);
      await _loadExpenseShares(); // Reload data
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked as paid!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking as paid: $e')));
      }
    }
  }

  void _showExpenseDetails(Map<String, dynamic> expenseData) {
    showExpenseDetailsModal(context, expenseData);
  }

  void _showAllExpenseShares() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllExpenseSharesScreen()),
    );
  }

  void _showAllCreatedExpenses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllCreatedExpensesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return const Center(child: Text('Profile not found'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              _loadProfile();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error logging out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadExpenseShares();
          await _loadCreatedExpenses();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _profile!['avatar_url'] != null
                          ? NetworkImage(_profile!['avatar_url'])
                          : null,
                  child:
                      _profile!['avatar_url'] == null
                          ? Text(
                            _profile!['display_name'][0].toUpperCase(),
                            style: const TextStyle(fontSize: 32),
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _profile!['display_name'] ?? 'No display name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _profile!['username'] ?? 'No username',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 32),

              // Expense Shares Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'My Expense Shares',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (_isLoadingExpenses)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_expenseShares.isEmpty && !_isLoadingExpenses)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_outlined,
                                size: 48,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No expense shares yet',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When you join groups with expenses, they\'ll appear here',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else if (_expenseShares.isNotEmpty)
                        ..._expenseShares.take(2).map((share) {
                          final expense =
                              share['expenses'] as Map<String, dynamic>;
                          final group =
                              expense['groups'] as Map<String, dynamic>;
                          final paidByProfile =
                              expense['profiles'] as Map<String, dynamic>?;
                          final paidByName =
                              paidByProfile?['display_name'] ?? 'Unknown';
                          final amountOwed =
                              (share['amount_owed'] as num).toDouble();
                          final isPaid = share['is_paid'] as bool;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color:
                                  isPaid
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3)
                                      : Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer
                                          .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isPaid
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.3)
                                        : Theme.of(context).colorScheme.tertiary
                                            .withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              onTap: () => _showExpenseDetails(expense),
                              leading: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      isPaid
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2)
                                          : Theme.of(context)
                                              .colorScheme
                                              .tertiary
                                              .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  isPaid ? Icons.check_circle : Icons.pending,
                                  size: 14,
                                  color:
                                      isPaid
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                ),
                              ),
                              title: Text(
                                expense['title'] ?? 'Untitled Expense',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${group['name'] ?? 'Unknown Group'} • \$${amountOwed.toStringAsFixed(2)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing:
                                  !isPaid
                                      ? SizedBox(
                                        height: 20,
                                        child: ElevatedButton(
                                          onPressed:
                                              () => _markAsPaid(share['id']),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Mark Paid',
                                            style: TextStyle(fontSize: 9),
                                          ),
                                        ),
                                      )
                                      : null,
                            ),
                          );
                        }),
                      if (_expenseShares.length > 2)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton.icon(
                              onPressed: () => _showAllExpenseShares(),
                              icon: const Icon(Icons.list, size: 14),
                              label: Text(
                                'View all ${_expenseShares.length} shares',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Created Expenses Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Expenses I Created',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (_isLoadingCreatedExpenses)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_createdExpenses.isEmpty &&
                          !_isLoadingCreatedExpenses)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 48,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No expenses created yet',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create expenses in your groups to see them here',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else if (_createdExpenses.isNotEmpty)
                        ..._createdExpenses.take(2).map((expense) {
                          final group =
                              expense['groups'] as Map<String, dynamic>;
                          final paidByProfile =
                              expense['profiles'] as Map<String, dynamic>?;
                          final paidByName =
                              paidByProfile?['display_name'] ?? 'Unknown';
                          final totalAmount =
                              (expense['total_amount'] as num).toDouble();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              onTap: () => _showExpenseDetails(expense),
                              leading: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.receipt,
                                  size: 14,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              title: Text(
                                expense['title'] ?? 'Untitled Expense',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${group['name'] ?? 'Unknown Group'} • \$${totalAmount.toStringAsFixed(2)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }),
                      if (_createdExpenses.length > 2)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton.icon(
                              onPressed: () => _showAllCreatedExpenses(),
                              icon: const Icon(Icons.list, size: 14),
                              label: Text(
                                'View all ${_createdExpenses.length} expenses',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Messages'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Edit Profile'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  );
                  _loadProfile();
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
