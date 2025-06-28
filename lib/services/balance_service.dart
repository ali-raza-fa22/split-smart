import 'package:supabase_flutter/supabase_flutter.dart';

class BalanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get user's current balance
  Future<Map<String, dynamic>?> getUserBalance() async {
    try {
      final balance =
          await _supabase
              .from('user_balances')
              .select('*')
              .eq('user_id', _supabase.auth.currentUser!.id)
              .single();
      return balance;
    } catch (e) {
      // If balance doesn't exist, create it
      if (e.toString().contains('No rows returned')) {
        return await createUserBalance();
      }
      rethrow;
    }
  }

  // Create user balance (called automatically by trigger, but available for manual creation)
  Future<Map<String, dynamic>> createUserBalance() async {
    try {
      final balance =
          await _supabase
              .from('user_balances')
              .insert({'user_id': _supabase.auth.currentUser!.id})
              .select()
              .single();
      return balance;
    } catch (e) {
      rethrow;
    }
  }

  // Add balance to user account (automatically repays loans first)
  Future<Map<String, dynamic>> addBalance({
    required double amount,
    required String title,
    String? description,
  }) async {
    try {
      // Get current balance to check for outstanding loans
      final currentBalance = await getUserBalance();
      final totalLoans =
          (currentBalance?['total_loans'] as num?)?.toDouble() ?? 0.0;
      final totalRepaid =
          (currentBalance?['total_repaid'] as num?)?.toDouble() ?? 0.0;
      final outstandingLoan = totalLoans - totalRepaid;

      if (outstandingLoan > 0) {
        // There's an outstanding loan, repay it first
        final amountToRepay =
            outstandingLoan > amount ? amount : outstandingLoan;
        final remainingAmount = amount - amountToRepay;

        // Repay loan
        await _supabase.from('balance_transactions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'transaction_type': 'repay',
          'amount': amountToRepay,
          'title': 'Auto-repay: $title',
          'description': description ?? 'Automatic loan repayment',
        });

        // Add remaining amount to balance (if any)
        if (remainingAmount > 0) {
          await _supabase.from('balance_transactions').insert({
            'user_id': _supabase.auth.currentUser!.id,
            'transaction_type': 'add',
            'amount': remainingAmount,
            'title': title,
            'description': description,
          });
        }

        return {
          'success': true,
          'amount_added': amount,
          'amount_repaid': amountToRepay,
          'amount_to_balance': remainingAmount,
          'had_outstanding_loan': true,
        };
      } else {
        // No outstanding loan, add directly to balance
        await _supabase.from('balance_transactions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'transaction_type': 'add',
          'amount': amount,
          'title': title,
          'description': description,
        });

        return {
          'success': true,
          'amount_added': amount,
          'amount_repaid': 0.0,
          'amount_to_balance': amount,
          'had_outstanding_loan': false,
        };
      }
    } catch (e) {
      rethrow;
    }
  }

  // Spend from balance (for expense payments)
  Future<Map<String, dynamic>> spendFromBalance({
    required double amount,
    required String title,
    String? description,
    String? expenseShareId,
    String? groupId,
  }) async {
    try {
      final currentBalance = await getUserBalance();
      final availableBalance =
          (currentBalance?['current_balance'] as num?)?.toDouble() ?? 0.0;

      if (availableBalance >= amount) {
        // Sufficient balance - spend from balance
        await _supabase.from('balance_transactions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'transaction_type': 'spend',
          'amount': amount,
          'title': title,
          'description': description,
          'expense_share_id': expenseShareId,
          'group_id': groupId,
        });

        return {
          'success': true,
          'payment_method': 'balance',
          'amount_paid_from_balance': amount,
          'amount_paid_from_loan': 0.0,
          'remaining_balance': availableBalance - amount,
        };
      } else {
        // Insufficient balance - use loan for remaining amount
        final amountFromBalance = availableBalance;
        final amountFromLoan = amount - availableBalance;

        // Spend remaining balance
        if (amountFromBalance > 0) {
          await _supabase.from('balance_transactions').insert({
            'user_id': _supabase.auth.currentUser!.id,
            'transaction_type': 'spend',
            'amount': amountFromBalance,
            'title': '$title (from balance)',
            'description': description,
            'expense_share_id': expenseShareId,
            'group_id': groupId,
          });
        }

        // Add loan for remaining amount
        await _supabase.from('balance_transactions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'transaction_type': 'loan',
          'amount': amountFromLoan,
          'title': '$title (loan)',
          'description': description,
          'expense_share_id': expenseShareId,
          'group_id': groupId,
        });

        return {
          'success': true,
          'payment_method': 'mixed',
          'amount_paid_from_balance': amountFromBalance,
          'amount_paid_from_loan': amountFromLoan,
          'remaining_balance': 0.0,
        };
      }
    } catch (e) {
      rethrow;
    }
  }

  // Repay loan from balance
  Future<void> repayLoan({
    required double amount,
    required String title,
    String? description,
  }) async {
    try {
      // Get current balance to check outstanding loan
      final currentBalance = await getUserBalance();
      final totalLoans =
          (currentBalance?['total_loans'] as num?)?.toDouble() ?? 0.0;
      final totalRepaid =
          (currentBalance?['total_repaid'] as num?)?.toDouble() ?? 0.0;
      final outstandingLoan = totalLoans - totalRepaid;

      // Validate that we're not repaying more than outstanding
      if (amount > outstandingLoan) {
        throw Exception(
          'Cannot repay more than the outstanding loan amount (Rs ${outstandingLoan.toStringAsFixed(2)})',
        );
      }

      await _supabase.from('balance_transactions').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'transaction_type': 'repay',
        'amount': amount,
        'title': title,
        'description': description,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get user's transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    String? transactionType,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _supabase
          .from('balance_transactions')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id);

      if (transactionType != null && transactionType.isNotEmpty) {
        query = query.eq('transaction_type', transactionType);
      }

      var finalQuery = query.order('created_at', ascending: false);
      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }
      if (offset != null) {
        finalQuery = finalQuery.range(offset, offset + (limit ?? 50) - 1);
      }
      final transactions = await finalQuery;
      return List<Map<String, dynamic>>.from(transactions);
    } catch (e) {
      rethrow;
    }
  }

  // Get default balance titles
  Future<List<Map<String, dynamic>>> getDefaultBalanceTitles({
    String? category,
  }) async {
    try {
      final titles = await _supabase
          .from('default_balance_titles')
          .select('*')
          .eq('is_active', true)
          .eq('category', category ?? 'income')
          .order('title');

      return List<Map<String, dynamic>>.from(titles);
    } catch (e) {
      rethrow;
    }
  }

  // Get balance statistics
  Future<Map<String, dynamic>> getBalanceStatistics() async {
    try {
      final balance = await getUserBalance();
      final transactions = await getTransactionHistory(limit: 100);

      // Calculate monthly statistics
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);
      final lastMonth = DateTime(now.year, now.month - 1);

      double thisMonthAdded = 0;
      double thisMonthSpent = 0;
      double lastMonthAdded = 0;
      double lastMonthSpent = 0;

      for (final transaction in transactions) {
        final createdAt = DateTime.parse(transaction['created_at']);
        final amount = (transaction['amount'] as num).toDouble();

        if (createdAt.isAfter(thisMonth)) {
          if (transaction['transaction_type'] == 'add') {
            thisMonthAdded += amount;
          } else if (transaction['transaction_type'] == 'spend') {
            thisMonthSpent += amount;
          }
        } else if (createdAt.isAfter(lastMonth) &&
            createdAt.isBefore(thisMonth)) {
          if (transaction['transaction_type'] == 'add') {
            lastMonthAdded += amount;
          } else if (transaction['transaction_type'] == 'spend') {
            lastMonthSpent += amount;
          }
        }
      }

      return {
        'current_balance': balance?['current_balance'] ?? 0.0,
        'total_added': balance?['total_added'] ?? 0.0,
        'total_spent': balance?['total_spent'] ?? 0.0,
        'total_loans': balance?['total_loans'] ?? 0.0,
        'total_repaid': balance?['total_repaid'] ?? 0.0,
        'this_month_added': thisMonthAdded,
        'this_month_spent': thisMonthSpent,
        'last_month_added': lastMonthAdded,
        'last_month_spent': lastMonthSpent,
        'outstanding_loan':
            (balance?['total_loans'] ?? 0.0) -
            (balance?['total_repaid'] ?? 0.0),
      };
    } catch (e) {
      rethrow;
    }
  }

  // Get transactions for a specific expense share
  Future<List<Map<String, dynamic>>> getTransactionsForExpenseShare(
    String expenseShareId,
  ) async {
    try {
      final transactions = await _supabase
          .from('balance_transactions')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .eq('expense_share_id', expenseShareId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(transactions);
    } catch (e) {
      rethrow;
    }
  }

  // Get transactions for a specific group
  Future<List<Map<String, dynamic>>> getTransactionsForGroup(
    String groupId,
  ) async {
    try {
      final transactions = await _supabase
          .from('balance_transactions')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(transactions);
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has sufficient balance for a payment
  Future<bool> hasSufficientBalance(double amount) async {
    try {
      final balance = await getUserBalance();
      final currentBalance =
          (balance?['current_balance'] as num?)?.toDouble() ?? 0.0;
      return currentBalance >= amount;
    } catch (e) {
      return false;
    }
  }

  // Get current balance amount
  Future<double> getCurrentBalance() async {
    try {
      final balance = await getUserBalance();
      return (balance?['current_balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get outstanding loan amount
  Future<double> getOutstandingLoan() async {
    try {
      final balance = await getUserBalance();
      final totalLoans = (balance?['total_loans'] as num?)?.toDouble() ?? 0.0;
      final totalRepaid = (balance?['total_repaid'] as num?)?.toDouble() ?? 0.0;
      return totalLoans - totalRepaid;
    } catch (e) {
      return 0.0;
    }
  }

  // Get detailed transaction history with expense, group, and share info
  Future<List<Map<String, dynamic>>> getDetailedTransactionHistory({
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from('balance_transactions')
        .select('*, expense_shares(*, expenses(title, group_id), groups(name))')
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(limit)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }
}
