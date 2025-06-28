import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:split_smart_supabase/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_formatter.dart';

class CsvExportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get the documents directory path
  Future<String> _getDocumentsPath() async {
    if (Platform.isAndroid) {
      final documentsPath = AppConstants.documentsPath;

      // Create the directory if it doesn't exist
      final documentsDir = Directory(AppConstants.documentsPath);
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      return documentsPath;
    } else {
      // For other platforms, use the app documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  // Export group expenses to CSV
  Future<String?> exportGroupExpensesToCsv(
    String groupId,
    String groupName,
  ) async {
    try {
      // Get comprehensive group data
      final groupData = await _getComprehensiveGroupData(groupId);

      if (groupData['expenses'].isEmpty) {
        throw Exception('No expenses found for this group');
      }

      // Generate CSV content with better formatting
      final csvContent = _generateComprehensiveCsvContent(groupData);

      // Get file path with new naming convention
      final documentsPath = await _getDocumentsPath();
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName =
          '${groupName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}-expenses-$timestamp.csv';
      final filePath = '$documentsPath/$fileName';

      // Write CSV file
      final file = File(filePath);
      await file.writeAsString(csvContent, encoding: utf8);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  // Get comprehensive group data including all user information
  Future<Map<String, dynamic>> _getComprehensiveGroupData(
    String groupId,
  ) async {
    try {
      // Get group information
      final groupResponse =
          await _supabase.from('groups').select('*').eq('id', groupId).single();

      // Get expenses with expense shares
      final expensesResponse = await _supabase
          .from('expenses')
          .select('''
            *,
            expense_shares (*)
          ''')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      // Get group members
      final membersResponse = await _supabase
          .from('group_members')
          .select('*')
          .eq('group_id', groupId);

      // Get all user IDs from expenses, expense shares, and group members
      final allUserIds = <String>{};

      // Add user IDs from expenses (created_by and paid_by)
      for (final expense in expensesResponse) {
        allUserIds.add(expense['created_by']);
        allUserIds.add(expense['paid_by']);
      }

      // Add user IDs from expense shares
      for (final expense in expensesResponse) {
        final expenseShares = expense['expense_shares'] as List<dynamic>;
        for (final share in expenseShares) {
          allUserIds.add(share['user_id']);
        }
      }

      // Add user IDs from group members
      for (final member in membersResponse) {
        allUserIds.add(member['user_id']);
      }

      // Add group creator
      allUserIds.add(groupResponse['created_by']);

      // Fetch profiles with email
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, display_name, username, email')
          .inFilter('id', allUserIds.toList());

      // Create a map of user IDs to profiles
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['id']] = profile;
      }

      // Create a map of user IDs to emails
      Map<String, String> emailsMap = {};
      for (final userId in allUserIds) {
        final profile = profilesMap[userId];
        // Use email from profile if available, otherwise fall back to username
        emailsMap[userId] =
            profile?['email'] ?? profile?['username'] ?? 'Unknown';
      }

      // Process expenses and add user details
      final processedExpenses = <Map<String, dynamic>>[];
      for (final expense in expensesResponse) {
        final expenseShares = expense['expense_shares'] as List<dynamic>;
        final processedShares = <Map<String, dynamic>>[];

        for (final share in expenseShares) {
          final profile = profilesMap[share['user_id']];
          final email = emailsMap[share['user_id']] ?? 'Unknown';

          processedShares.add({
            ...share,
            'member_name': profile?['display_name'] ?? 'Unknown',
            'member_username': profile?['username'] ?? 'Unknown',
            'member_email': email,
          });
        }

        // Add creator and payer information
        final creatorProfile = profilesMap[expense['created_by']];
        final payerProfile = profilesMap[expense['paid_by']];
        final creatorEmail = emailsMap[expense['created_by']] ?? 'Unknown';
        final payerEmail = emailsMap[expense['paid_by']] ?? 'Unknown';

        processedExpenses.add({
          ...expense,
          'expense_shares': processedShares,
          'creator_name': creatorProfile?['display_name'] ?? 'Unknown',
          'creator_username': creatorProfile?['username'] ?? 'Unknown',
          'creator_email': creatorEmail,
          'payer_name': payerProfile?['display_name'] ?? 'Unknown',
          'payer_username': payerProfile?['username'] ?? 'Unknown',
          'payer_email': payerEmail,
        });
      }

      // Process group members
      final processedMembers = <Map<String, dynamic>>[];
      for (final member in membersResponse) {
        final profile = profilesMap[member['user_id']];
        final email = emailsMap[member['user_id']] ?? 'Unknown';

        processedMembers.add({
          ...member,
          'member_name': profile?['display_name'] ?? 'Unknown',
          'member_username': profile?['username'] ?? 'Unknown',
          'member_email': email,
        });
      }

      // Add group creator information
      final groupCreatorProfile = profilesMap[groupResponse['created_by']];
      final groupCreatorEmail =
          emailsMap[groupResponse['created_by']] ?? 'Unknown';

      return {
        'group': {
          ...groupResponse,
          'creator_name': groupCreatorProfile?['display_name'] ?? 'Unknown',
          'creator_username': groupCreatorProfile?['username'] ?? 'Unknown',
          'creator_email': groupCreatorEmail,
        },
        'expenses': processedExpenses,
        'members': processedMembers,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Generate comprehensive CSV content with better formatting
  String _generateComprehensiveCsvContent(Map<String, dynamic> groupData) {
    final buffer = StringBuffer();
    final group = groupData['group'] as Map<String, dynamic>;
    final expenses = groupData['expenses'] as List<Map<String, dynamic>>;
    final members = groupData['members'] as List<Map<String, dynamic>>;

    // Add comprehensive header
    _addReportHeader(buffer, group);

    // Add group information section
    _addGroupInformationSection(buffer, group);

    // Add members section
    _addMembersSection(buffer, members);

    // Add expense details section
    _addExpenseDetailsSection(buffer, expenses);

    // Add payment details section
    _addPaymentDetailsSection(buffer, expenses);

    // Add summary section
    _addSummarySection(buffer, expenses);

    return buffer.toString();
  }

  // Add report header
  void _addReportHeader(StringBuffer buffer, Map<String, dynamic> group) {
    buffer.writeln('=' * 30);
    buffer.writeln('SPLIT SMART - GROUP EXPENSES REPORT');
    buffer.writeln('=' * 30);
    buffer.writeln();
    buffer.writeln(
      'Report Generated: ${DateFormatter.formatFullDateTime(DateTime.now())}',
    );
    buffer.writeln();
  }

  // Add group information section
  void _addGroupInformationSection(
    StringBuffer buffer,
    Map<String, dynamic> group,
  ) {
    buffer.writeln('GROUP INFORMATION');
    buffer.writeln('-' * 20);
    buffer.writeln('Group Name,${_escapeCsvField(group['name'])}');
    buffer.writeln('Group ID,${group['id']}');
    buffer.writeln(
      'Created By,${_escapeCsvField(group['creator_name'])} (${group['creator_email']})',
    );
    buffer.writeln(
      'Created On,${DateFormatter.formatFullDateTime(DateTime.parse(group['created_at']).toLocal())}',
    );
    buffer.writeln();
  }

  // Add members section
  void _addMembersSection(
    StringBuffer buffer,
    List<Map<String, dynamic>> members,
  ) {
    buffer.writeln('GROUP MEMBERS');
    buffer.writeln('-' * 20);
    buffer.writeln('Name,Username,Email,Role,Joined Date');

    for (final member in members) {
      final joinedDate = DateFormatter.formatFullDateTime(
        DateTime.parse(member['created_at']).toLocal(),
      );

      buffer.writeln(
        [
          _escapeCsvField(member['member_name']),
          _escapeCsvField(member['member_username']),
          _escapeCsvField(member['member_email']),
          member['is_admin'] == true ? 'Admin' : 'Member',
          joinedDate,
        ].join(','),
      );
    }
    buffer.writeln();
  }

  // Add expense details section
  void _addExpenseDetailsSection(
    StringBuffer buffer,
    List<Map<String, dynamic>> expenses,
  ) {
    buffer.writeln('EXPENSE DETAILS');
    buffer.writeln('-' * 20);
    buffer.writeln(
      'Expense ID,Title,Description,Total Amount,Currency,Paid By,Paid By Email,Created By,Created By Email,Created Date',
    );

    for (final expense in expenses) {
      final createdDate = DateFormatter.formatFullDateTime(
        DateTime.parse(expense['created_at']).toLocal(),
      );

      buffer.writeln(
        [
          expense['id'],
          _escapeCsvField(expense['title']),
          _escapeCsvField(expense['description'] ?? ''),
          'Rs ${(expense['total_amount'] as num).toStringAsFixed(2)}',
          'USD',
          _escapeCsvField(expense['payer_name']),
          _escapeCsvField(expense['payer_email']),
          _escapeCsvField(expense['creator_name']),
          _escapeCsvField(expense['creator_email']),
          createdDate,
        ].join(','),
      );
    }
    buffer.writeln();
  }

  // Add payment details section
  void _addPaymentDetailsSection(
    StringBuffer buffer,
    List<Map<String, dynamic>> expenses,
  ) {
    buffer.writeln('PAYMENT DETAILS');
    buffer.writeln('-' * 20);
    buffer.writeln(
      'Expense ID,Expense Title,Member Name,Member Email,Share Amount,Is Paid,Paid Date',
    );

    for (final expense in expenses) {
      final expenseShares = expense['expense_shares'] as List<dynamic>;

      for (final share in expenseShares) {
        final paidDate =
            share['paid_at'] != null
                ? DateFormatter.formatFullDateTime(
                  DateTime.parse(share['paid_at']).toLocal(),
                )
                : '';

        buffer.writeln(
          [
            expense['id'],
            _escapeCsvField(expense['title']),
            _escapeCsvField(share['member_name']),
            _escapeCsvField(share['member_email']),
            'Rs ${(share['amount_owed'] as num).toStringAsFixed(2)}',
            share['is_paid'] == true ? 'Yes' : 'No',
            paidDate,
          ].join(','),
        );
      }
    }
    buffer.writeln();
  }

  // Add summary section
  void _addSummarySection(
    StringBuffer buffer,
    List<Map<String, dynamic>> expenses,
  ) {
    buffer.writeln('SUMMARY');
    buffer.writeln('-' * 20);

    // Calculate totals
    double totalAmount = 0;
    double totalPaid = 0;
    int totalShares = 0;
    int paidShares = 0;
    Map<String, double> memberTotals = {};
    Map<String, double> memberPaid = {};

    for (final expense in expenses) {
      totalAmount += (expense['total_amount'] as num);
      final expenseShares = expense['expense_shares'] as List<dynamic>;

      for (final share in expenseShares) {
        final memberName = share['member_name'] as String;
        final amount = (share['amount_owed'] as num).toDouble();

        totalShares++;
        memberTotals[memberName] = (memberTotals[memberName] ?? 0) + amount;

        if (share['is_paid'] == true) {
          paidShares++;
          totalPaid += amount;
          memberPaid[memberName] = (memberPaid[memberName] ?? 0) + amount;
        }
      }
    }

    // Overall summary
    buffer.writeln('Total Expenses,${expenses.length}');
    buffer.writeln('Total Amount,Rs ${totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Total Paid,Rs ${totalPaid.toStringAsFixed(2)}');
    buffer.writeln(
      'Total Outstanding,Rs ${(totalAmount - totalPaid).toStringAsFixed(2)}',
    );
    buffer.writeln('Total Shares,$totalShares');
    buffer.writeln('Paid Shares,$paidShares');
    buffer.writeln('Outstanding Shares,${totalShares - paidShares}');
    buffer.writeln(
      'Payment Progress,${((totalPaid / totalAmount) * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln();

    // Member-wise summary
    buffer.writeln('MEMBER SUMMARY');
    buffer.writeln(
      'Member Name,Total Owed,Total Paid,Outstanding,Payment Progress',
    );

    memberTotals.forEach((memberName, totalOwed) {
      final totalPaidByMember = memberPaid[memberName] ?? 0;
      final outstanding = totalOwed - totalPaidByMember;
      final progress =
          totalOwed > 0 ? ((totalPaidByMember / totalOwed) * 100) : 0;

      buffer.writeln(
        [
          _escapeCsvField(memberName),
          'Rs ${totalOwed.toStringAsFixed(2)}',
          'Rs ${totalPaidByMember.toStringAsFixed(2)}',
          'Rs ${outstanding.toStringAsFixed(2)}',
          '${progress.toStringAsFixed(1)}%',
        ].join(','),
      );
    });

    buffer.writeln();
    buffer.writeln('=' * 20);
    buffer.writeln('END OF REPORT');
    buffer.writeln('=' * 20);
  }

  // Escape CSV field to handle commas and quotes
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
