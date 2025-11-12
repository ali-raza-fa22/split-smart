import 'package:flutter/material.dart';
import 'csv_export_button.dart';
import 'user_list_item.dart';
import '../services/chat_service.dart';

class ExpenseDetailsModal extends StatefulWidget {
  final Map<String, dynamic> expenseData;
  final VoidCallback? onExpenseUpdated;

  const ExpenseDetailsModal({
    super.key,
    required this.expenseData,
    this.onExpenseUpdated,
  });

  @override
  State<ExpenseDetailsModal> createState() => _ExpenseDetailsModalState();
}

class _ExpenseDetailsModalState extends State<ExpenseDetailsModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _paymentDetails = [];
  bool _isLoadingPaymentDetails = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _loadPaymentDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      final details = await _chatService.getExpenseDetailsWithPaymentStatus(
        widget.expenseData['id'],
      );
      if (mounted) {
        setState(() {
          _paymentDetails = details;
          _isLoadingPaymentDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingPaymentDetails = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.expenseData['title'] ?? 'Unknown Expense';
    final amount =
        (widget.expenseData['total_amount'] as num?)?.toDouble() ?? 0.0;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header
                  _buildHeader(title, amount, theme),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildPaymentStatusSection(theme)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, double amount, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.onPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Details',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Save button
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CsvExportButton(
                groupId: widget.expenseData['group_id'],
                groupName: widget.expenseData['group_name'] ?? 'Group',
                expensesCount: 1, // At least this expense exists
                customIcon: Icons.download_outlined,
                isCompact: true,
                onExportComplete: () {
                  // Optional: Add any completion logic here
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Rs ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusSection(ThemeData theme) {
    if (_isLoadingPaymentDetails) {
      return Container(
        padding: const EdgeInsets.all(11),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Loading payment details...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error loading payment details.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    final paidMembers =
        _paymentDetails.where((member) => member['is_paid'] == true).toList();
    final unpaidMembers =
        _paymentDetails.where((member) => member['is_paid'] == false).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_paymentDetails.length} members',
                  style: TextStyle(
                    color: theme.colorScheme.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Paid members
          if (paidMembers.isNotEmpty) ...[
            _buildPaymentSection(
              'Paid (${paidMembers.length})',
              paidMembers,
              theme.colorScheme.primary,
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 12),
          ],

          // Unpaid members
          if (unpaidMembers.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildPaymentSection(
              'Pending (${unpaidMembers.length})',
              unpaidMembers,
              theme.colorScheme.onSurface,
              Icons.pending_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection(
    String title,
    List<Map<String, dynamic>> members,
    Color color,
    IconData icon,
  ) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children:
                members.map((member) {
                  final profile = member['profiles'] as Map<String, dynamic>?;
                  final displayName = profile?['display_name'] ?? 'Unknown';
                  final userId = profile?['id'] ?? '';
                  final amount = (member['amount_owed'] as num).toDouble();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: UserListItem(
                      userId: userId,
                      name: displayName,
                      avatarUrl: profile?['avatar_url'],
                      amount: 'Rs ${amount.toStringAsFixed(2)}',
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// Helper function to show the expense details modal
void showExpenseDetailsModal(
  BuildContext context,
  Map<String, dynamic> expenseData, {
  VoidCallback? onExpenseUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => ExpenseDetailsModal(
          expenseData: expenseData,
          onExpenseUpdated: onExpenseUpdated,
        ),
  );
}
