import 'package:flutter/material.dart';
import 'package:split_smart_supabase/utils/date_formatter.dart';
import '../services/chat_service.dart';
import 'csv_export_button.dart';
import '../utils/avatar_utils.dart';

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
    final description = widget.expenseData['description'] as String?;
    final paidByProfile =
        widget.expenseData['profiles'] as Map<String, dynamic>?;
    final paidByName = paidByProfile?['display_name'] ?? 'Unknown';
    final createdAt =
        DateTime.tryParse(widget.expenseData['created_at'] ?? '') ??
        DateTime.now();

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
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
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
                    margin: const EdgeInsets.only(top: 14),
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
                        children: [
                          // Basic Details Section
                          _buildBasicDetailsSection(
                            paidByName,
                            createdAt,
                            description,
                            theme,
                          ),

                          const SizedBox(height: 14),

                          // Payment Status Section
                          _buildPaymentStatusSection(theme),
                        ],
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
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Details',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                customIcon: Icons.download,
                isCompact: true,
                onExportComplete: () {
                  // Optional: Add any completion logic here
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Rs ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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

  Widget _buildBasicDetailsSection(
    String paidByName,
    DateTime createdAt,
    String? description,
    ThemeData theme,
  ) {
    final paidByProfile =
        widget.expenseData['profiles'] as Map<String, dynamic>?;
    final paidById = paidByProfile?['id'] ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            'Paid by',
            paidByName,
            Icons.person,
            theme,
            leading: AvatarUtils.buildUserAvatar(
              paidById,
              paidByName,
              avatarUrl: paidByProfile?['avatar_url'],
              theme,
              radius: 16,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Date',
            DateFormatter.formatDate(createdAt),
            Icons.calendar_today,
            theme,
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDetailRow(
              'Description',
              description,
              Icons.description,
              theme,
            ),
          ],
        ],
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
                'Error loading payment details: $_errorMessage',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payment,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_paymentDetails.length} members',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
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
              theme.colorScheme.onPrimary,
              Icons.check_circle,
              theme,
            ),
            const SizedBox(height: 14),
          ],

          // Unpaid members
          if (unpaidMembers.isNotEmpty) ...[
            _buildPaymentSection(
              'Pending (${unpaidMembers.length})',
              unpaidMembers,
              theme.colorScheme.onPrimary,
              Icons.pending,
              theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          leading ??
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 18),
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(
    String title,
    List<Map<String, dynamic>> members,
    Color color,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                members.map((member) {
                  final profile = member['profiles'] as Map<String, dynamic>?;
                  final displayName = profile?['display_name'] ?? 'Unknown';
                  final userId = profile?['id'] ?? '';
                  final amount = (member['amount_owed'] as num).toDouble();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarUtils.buildUserAvatar(
                          userId,
                          displayName,
                          avatarUrl: profile?['avatar_url'],
                          theme,
                          radius: 12,
                          fontSize: 11,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(Rs ${amount.toStringAsFixed(2)})',
                          style: TextStyle(
                            fontSize: 12,
                            color: color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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
