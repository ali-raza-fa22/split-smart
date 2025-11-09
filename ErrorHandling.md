# Error Handling Strategy for Split Smart

## Overview
This document outlines a production-ready error handling strategy for the Split Smart Flutter application. The goal is to provide a robust error handling system that:
- Protects sensitive information from being exposed to users
- Logs errors for debugging while maintaining security
- Provides user-friendly error messages
- Handles different types of errors appropriately

## Table of Contents
1. [Error Types](#error-types)
2. [Error Handling Architecture](#error-handling-architecture)
3. [Implementation Guide](#implementation-guide)
4. [Code Examples](#code-examples)
5. [Testing Error Scenarios](#testing-error-scenarios)
6. [Monitoring & Logging](#monitoring--logging)

---

## Error Types

### 1. Authentication Errors
- Invalid credentials
- Email not verified
- Token expired
- Account locked/suspended

### 2. Network Errors
- No internet connection
- Timeout
- Server unreachable
- DNS resolution failure

### 3. Database Errors (Supabase)
- RLS (Row Level Security) policy violations
- Foreign key constraints
- Unique constraint violations
- Query timeout

### 4. Validation Errors
- Invalid email format
- Password too weak
- Required fields missing
- Invalid data format

### 5. Business Logic Errors
- Insufficient balance
- Group member limit exceeded
- Cannot remove group admin
- Expense already paid

### 6. Unknown/Unexpected Errors
- Unhandled exceptions
- Null pointer exceptions
- Type casting errors

---

## Error Handling Architecture

### 1. Create Custom Error Classes

Create a file: `/lib/utils/app_exceptions.dart`

```dart
/// Base class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Authentication related errors
class AuthException extends AppException {
  AuthException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Network related errors
class NetworkException extends AppException {
  NetworkException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Database related errors
class DatabaseException extends AppException {
  DatabaseException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Validation errors
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(String message, {this.fieldErrors, String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Business logic errors
class BusinessLogicException extends AppException {
  BusinessLogicException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Unknown errors
class UnknownException extends AppException {
  UnknownException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}
```

### 2. Create Error Handler Service

Create a file: `/lib/services/error_handler_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_exceptions.dart';
import 'logger_service.dart';

class ErrorHandlerService {
  final LoggerService _logger = LoggerService();

  /// Convert Supabase/Dart exceptions to custom AppException
  AppException handleError(dynamic error, {String? context}) {
    // Log the error with full details (including sensitive info for debugging)
    _logger.error('Error occurred in $context', error: error);

    // Handle Supabase Auth exceptions
    if (error is AuthException) {
      return _handleAuthException(error);
    }

    // Handle Supabase PostgrestException (database errors)
    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }

    // Handle Supabase StorageException
    if (error is StorageException) {
      return _handleStorageException(error);
    }

    // Handle network exceptions
    if (error is SocketException || 
        error is TimeoutException ||
        error is HttpException) {
      return NetworkException(
        'Unable to connect. Please check your internet connection.',
        originalError: error,
      );
    }

    // Handle format exceptions
    if (error is FormatException) {
      return ValidationException(
        'Invalid data format.',
        originalError: error,
      );
    }

    // Default: Unknown error
    return UnknownException(
      'An unexpected error occurred. Please try again.',
      originalError: error,
    );
  }

  /// Handle Supabase Auth exceptions
  AuthException _handleAuthException(AuthException error) {
    final message = error.message.toLowerCase();

    // Map specific auth errors to user-friendly messages
    if (message.contains('invalid login credentials') || 
        message.contains('invalid email or password')) {
      return AuthException(
        'Invalid email or password. Please try again.',
        code: 'INVALID_CREDENTIALS',
        originalError: error,
      );
    }

    if (message.contains('email not confirmed')) {
      return AuthException(
        'Please verify your email before logging in.',
        code: 'EMAIL_NOT_CONFIRMED',
        originalError: error,
      );
    }

    if (message.contains('user already registered')) {
      return AuthException(
        'This email is already registered. Please login instead.',
        code: 'USER_EXISTS',
        originalError: error,
      );
    }

    if (message.contains('invalid refresh token') || 
        message.contains('token expired')) {
      return AuthException(
        'Your session has expired. Please login again.',
        code: 'SESSION_EXPIRED',
        originalError: error,
      );
    }

    if (message.contains('password') && message.contains('weak')) {
      return AuthException(
        'Password is too weak. Please use a stronger password.',
        code: 'WEAK_PASSWORD',
        originalError: error,
      );
    }

    if (message.contains('too many requests')) {
      return AuthException(
        'Too many attempts. Please try again later.',
        code: 'RATE_LIMIT',
        originalError: error,
      );
    }

    // Generic auth error
    return AuthException(
      'Authentication failed. Please try again.',
      code: 'AUTH_ERROR',
      originalError: error,
    );
  }

  /// Handle Supabase Postgrest (database) exceptions
  DatabaseException _handlePostgrestException(PostgrestException error) {
    final message = error.message?.toLowerCase() ?? '';
    final code = error.code ?? '';

    // RLS policy violation
    if (code == '42501' || message.contains('row-level security')) {
      return DatabaseException(
        'You do not have permission to perform this action.',
        code: 'PERMISSION_DENIED',
        originalError: error,
      );
    }

    // Foreign key constraint violation
    if (code == '23503' || message.contains('foreign key')) {
      return DatabaseException(
        'This action cannot be completed due to related data.',
        code: 'CONSTRAINT_VIOLATION',
        originalError: error,
      );
    }

    // Unique constraint violation
    if (code == '23505' || message.contains('unique constraint')) {
      return DatabaseException(
        'This record already exists.',
        code: 'DUPLICATE_RECORD',
        originalError: error,
      );
    }

    // Not null constraint violation
    if (code == '23502' || message.contains('null value')) {
      return DatabaseException(
        'Required information is missing.',
        code: 'MISSING_DATA',
        originalError: error,
      );
    }

    // Query timeout
    if (message.contains('timeout') || message.contains('timed out')) {
      return DatabaseException(
        'The operation took too long. Please try again.',
        code: 'TIMEOUT',
        originalError: error,
      );
    }

    // No rows returned
    if (message.contains('no rows') || code == 'PGRST116') {
      return DatabaseException(
        'The requested data was not found.',
        code: 'NOT_FOUND',
        originalError: error,
      );
    }

    // Generic database error
    return DatabaseException(
      'A database error occurred. Please try again.',
      code: 'DATABASE_ERROR',
      originalError: error,
    );
  }

  /// Handle Supabase Storage exceptions
  DatabaseException _handleStorageException(StorageException error) {
    final message = error.message.toLowerCase();

    if (message.contains('file size') || message.contains('too large')) {
      return DatabaseException(
        'File is too large. Maximum size is 5MB.',
        code: 'FILE_TOO_LARGE',
        originalError: error,
      );
    }

    if (message.contains('file type') || message.contains('invalid')) {
      return DatabaseException(
        'Invalid file type. Please upload an image.',
        code: 'INVALID_FILE_TYPE',
        originalError: error,
      );
    }

    if (message.contains('permission') || message.contains('unauthorized')) {
      return DatabaseException(
        'You do not have permission to upload files.',
        code: 'UPLOAD_PERMISSION_DENIED',
        originalError: error,
      );
    }

    return DatabaseException(
      'Failed to upload file. Please try again.',
      code: 'UPLOAD_ERROR',
      originalError: error,
    );
  }

  /// Get user-friendly message for business logic errors
  String getBusinessLogicMessage(String errorType, {Map<String, dynamic>? params}) {
    switch (errorType) {
      case 'INSUFFICIENT_BALANCE':
        final required = params?['required'] ?? 0;
        final current = params?['current'] ?? 0;
        return 'Insufficient balance. You need Rs $required but have Rs $current.';
      
      case 'GROUP_MEMBER_LIMIT':
        final max = params?['max'] ?? 10;
        return 'Group has reached maximum member limit of $max.';
      
      case 'CANNOT_REMOVE_ADMIN':
        return 'Group admin cannot be removed. Transfer admin rights first.';
      
      case 'EXPENSE_ALREADY_PAID':
        return 'This expense has already been paid.';
      
      case 'CANNOT_DELETE_GROUP_WITH_EXPENSES':
        return 'Cannot delete group with pending expenses.';
      
      case 'INVALID_AMOUNT':
        return 'Please enter a valid amount greater than zero.';
      
      case 'REPAY_EXCEEDS_LOAN':
        final loan = params?['loan'] ?? 0;
        return 'Cannot repay more than outstanding loan of Rs $loan.';
      
      default:
        return 'Operation failed. Please try again.';
    }
  }
}

// Import statements needed for the above code
import 'dart:io';
import 'dart:async';
```

### 3. Create Logger Service

Create a file: `/lib/services/logger_service.dart`

```dart
import 'package:flutter/foundation.dart';

/// Service for logging errors and debugging information
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Log info message
  void info(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[INFO] $message');
      if (data != null) {
        print('[DATA] $data');
      }
    }
    // In production, send to logging service (Firebase Crashlytics, Sentry, etc.)
  }

  /// Log error with full details
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('[ERROR] $message');
      if (error != null) {
        print('[ERROR_DETAILS] $error');
      }
      if (stackTrace != null) {
        print('[STACK_TRACE] $stackTrace');
      }
    }

    // In production, send to error tracking service
    // Example: FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // Example: Sentry.captureException(error, stackTrace: stackTrace);
  }

  /// Log warning
  void warning(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[WARNING] $message');
      if (data != null) {
        print('[DATA] $data');
      }
    }
  }

  /// Log debug information (only in debug mode)
  void debug(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[DEBUG] $message');
      if (data != null) {
        print('[DATA] $data');
      }
    }
  }
}
```

---

## Implementation Guide

### Step 1: Update Service Methods

Update all service methods to use the error handler. Example for `auth.dart`:

```dart
import '../services/error_handler_service.dart';
import '../utils/app_exceptions.dart';

class AuthService {
  final supabase = Supabase.instance.client;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Login with error handling
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      // Convert to custom exception and rethrow
      throw _errorHandler.handleError(e, context: 'AuthService.login');
    }
  }

  /// Register with error handling
  Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
      );
      return response;
    } catch (e) {
      throw _errorHandler.handleError(e, context: 'AuthService.register');
    }
  }

  /// Update profile with validation and error handling
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      if (currentUser == null) {
        throw AuthException('No user logged in', code: 'NO_USER');
      }

      // Validation
      if (username != null && username.trim().isEmpty) {
        throw ValidationException(
          'Username cannot be empty',
          code: 'INVALID_USERNAME',
        );
      }

      if (displayName != null && displayName.trim().isEmpty) {
        throw ValidationException(
          'Display name cannot be empty',
          code: 'INVALID_DISPLAY_NAME',
        );
      }

      final updates = {
        if (username != null) 'username': username.trim(),
        if (displayName != null) 'display_name': displayName.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabase.from('profiles').upsert({
        'id': currentUser!.id.toString(),
        ...updates,
      }).select();
    } catch (e) {
      // If it's already an AppException, rethrow it
      if (e is AppException) {
        rethrow;
      }
      // Otherwise, handle it
      throw _errorHandler.handleError(e, context: 'AuthService.updateProfile');
    }
  }
}
```

### Step 2: Update Balance Service

Example for `balance_service.dart`:

```dart
class BalanceService {
  final supabase = Supabase.instance.client;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Add balance with business logic validation
  Future<Map<String, dynamic>> addBalance({
    required double amount,
    required String title,
    String? description,
  }) async {
    try {
      // Validation
      if (amount <= 0) {
        throw BusinessLogicException(
          _errorHandler.getBusinessLogicMessage('INVALID_AMOUNT'),
          code: 'INVALID_AMOUNT',
        );
      }

      if (title.trim().isEmpty) {
        throw ValidationException(
          'Title cannot be empty',
          code: 'INVALID_TITLE',
        );
      }

      // Get current balance to check for outstanding loans
      final currentBalance = await getUserBalance();
      final totalLoans = (currentBalance?['total_loans'] as num?)?.toDouble() ?? 0.0;
      final totalRepaid = (currentBalance?['total_repaid'] as num?)?.toDouble() ?? 0.0;
      final outstandingLoan = totalLoans - totalRepaid;

      if (outstandingLoan > 0) {
        final amountToRepay = outstandingLoan > amount ? amount : outstandingLoan;
        final remainingAmount = amount - amountToRepay;

        await supabase.from('balance_transactions').insert({
          'user_id': supabase.auth.currentUser!.id,
          'transaction_type': 'repay',
          'amount': amountToRepay,
          'title': 'Auto-repay: $title',
          'description': description ?? 'Automatic loan repayment',
        });

        if (remainingAmount > 0) {
          await supabase.from('balance_transactions').insert({
            'user_id': supabase.auth.currentUser!.id,
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
        await supabase.from('balance_transactions').insert({
          'user_id': supabase.auth.currentUser!.id,
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
      if (e is AppException) {
        rethrow;
      }
      throw _errorHandler.handleError(e, context: 'BalanceService.addBalance');
    }
  }

  /// Repay loan with validation
  Future<void> repayLoan({
    required double amount,
    required String title,
    String? description,
  }) async {
    try {
      if (amount <= 0) {
        throw BusinessLogicException(
          _errorHandler.getBusinessLogicMessage('INVALID_AMOUNT'),
          code: 'INVALID_AMOUNT',
        );
      }

      final currentBalance = await getUserBalance();
      final totalLoans = (currentBalance?['total_loans'] as num?)?.toDouble() ?? 0.0;
      final totalRepaid = (currentBalance?['total_repaid'] as num?)?.toDouble() ?? 0.0;
      final outstandingLoan = totalLoans - totalRepaid;

      if (amount > outstandingLoan) {
        throw BusinessLogicException(
          _errorHandler.getBusinessLogicMessage(
            'REPAY_EXCEEDS_LOAN',
            params: {'loan': outstandingLoan},
          ),
          code: 'REPAY_EXCEEDS_LOAN',
        );
      }

      await supabase.from('balance_transactions').insert({
        'user_id': supabase.auth.currentUser!.id,
        'transaction_type': 'repay',
        'amount': amount,
        'title': title,
        'description': description,
      });
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw _errorHandler.handleError(e, context: 'BalanceService.repayLoan');
    }
  }
}
```

### Step 3: Update UI Error Handling

Create a helper widget for displaying errors:

Create file: `/lib/widgets/error_display.dart`

```dart
import 'package:flutter/material.dart';
import '../utils/app_exceptions.dart';

class ErrorDisplay {
  /// Show error as SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = _getErrorMessage(error);
    
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error as Dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final message = _getErrorMessage(error);

    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Error'),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show success message
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: duration,
      ),
    );
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }

    // Fallback for unexpected errors
    return 'An unexpected error occurred. Please try again.';
  }
}

/// Widget to display error state with retry option
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Step 4: Update Screen Implementation

Example: Update `login_screen.dart`:

```dart
import '../widgets/error_display.dart';

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // Clear any existing errors
    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() => _isLoading = true);

    try {
      final response = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        // Check email verification
        if (response.user!.emailConfirmedAt == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // Show auth-specific error
        ErrorDisplay.showErrorSnackBar(context, e);
      }
    } on NetworkException catch (e) {
      if (mounted) {
        // Show network error with retry option
        ErrorDisplay.showErrorDialog(
          context,
          e,
          title: 'Connection Error',
          onRetry: _handleLogin,
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        // Show generic app error
        ErrorDisplay.showErrorSnackBar(context, e);
      }
    } catch (e) {
      if (mounted) {
        // Unexpected error
        ErrorDisplay.showErrorSnackBar(
          context,
          UnknownException('An unexpected error occurred'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... build UI
  }
}
```

Example: Update `home_screen.dart` with error state:

```dart
class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  double? _balance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final balance = await _balanceService.getCurrentBalance();
      setState(() {
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorDisplay._getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage!,
        onRetry: _loadUserData,
      );
    }

    // Normal UI
    return ListView(
      // ... content
    );
  }
}
```

---

## Code Examples

### Example 1: Chat Service with Error Handling

```dart
class ChatService {
  final supabase = Supabase.instance.client;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      // Validation
      if (name.trim().isEmpty) {
        throw ValidationException(
          'Group name cannot be empty',
          code: 'INVALID_GROUP_NAME',
        );
      }

      if (memberIds.isEmpty) {
        throw ValidationException(
          'Please add at least one member',
          code: 'NO_MEMBERS',
        );
      }

      if (memberIds.length > AppConstants.maxMembersAllowed) {
        throw BusinessLogicException(
          _errorHandler.getBusinessLogicMessage(
            'GROUP_MEMBER_LIMIT',
            params: {'max': AppConstants.maxMembersAllowed},
          ),
          code: 'GROUP_MEMBER_LIMIT',
        );
      }

      // Create group
      final groupResponse = await supabase
          .from('groups')
          .insert({
            'name': name.trim(),
            'created_by': supabase.auth.currentUser!.id,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      final groupId = groupResponse['id'];

      // Add members
      final members = [
        {
          'group_id': groupId,
          'user_id': supabase.auth.currentUser!.id,
          'is_admin': true,
        },
        ...memberIds.map((id) => {
          'group_id': groupId,
          'user_id': id,
          'is_admin': false,
        }),
      ];

      await supabase.from('group_members').insert(members);

      return groupId;
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw _errorHandler.handleError(e, context: 'ChatService.createGroup');
    }
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Check if current user is admin
      final isAdmin = await isGroupAdmin(groupId);
      if (!isAdmin) {
        throw BusinessLogicException(
          'Only admins can remove members',
          code: 'NOT_ADMIN',
        );
      }

      // Prevent admin from removing themselves
      if (userId == supabase.auth.currentUser!.id) {
        throw BusinessLogicException(
          _errorHandler.getBusinessLogicMessage('CANNOT_REMOVE_ADMIN'),
          code: 'CANNOT_REMOVE_ADMIN',
        );
      }

      await supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw _errorHandler.handleError(
        e,
        context: 'ChatService.removeMemberFromGroup',
      );
    }
  }
}
```

### Example 2: Form Validation with Field-Specific Errors

```dart
class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _titleError;
  String? _amountError;

  Future<void> _submitExpense() async {
    setState(() {
      _titleError = null;
      _amountError = null;
    });

    try {
      // Validate
      if (_titleController.text.trim().isEmpty) {
        throw ValidationException(
          'Please enter an expense title',
          fieldErrors: {'title': 'Title is required'},
          code: 'INVALID_TITLE',
        );
      }

      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        throw ValidationException(
          'Please enter a valid amount',
          fieldErrors: {'amount': 'Amount must be greater than zero'},
          code: 'INVALID_AMOUNT',
        );
      }

      // Create expense
      await _chatService.createExpense(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        totalAmount: amount,
        paidBy: _selectedPaidBy!,
      );

      if (mounted) {
        ErrorDisplay.showSuccessSnackBar(
          context,
          'Expense added successfully!',
        );
        Navigator.pop(context, true);
      }
    } on ValidationException catch (e) {
      if (mounted) {
        // Show field-specific errors
        setState(() {
          _titleError = e.fieldErrors?['title'];
          _amountError = e.fieldErrors?['amount'];
        });
        ErrorDisplay.showErrorSnackBar(context, e);
      }
    } catch (e) {
      if (mounted) {
        ErrorDisplay.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Expense Title',
                errorText: _titleError,
              ),
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                errorText: _amountError,
              ),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _submitExpense,
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Testing Error Scenarios

### Manual Testing Checklist

- [ ] **Authentication Errors**
  - Try login with wrong password
  - Try login with unverified email
  - Try register with existing email
  - Try password reset with invalid email
  - Simulate session expiration

- [ ] **Network Errors**
  - Turn off internet and try operations
  - Simulate slow network
  - Test timeout scenarios

- [ ] **Database Errors**
  - Try accessing data without permission
  - Try creating duplicate records
  - Try deleting records with foreign key constraints

- [ ] **Validation Errors**
  - Submit empty forms
  - Enter invalid email formats
  - Enter negative amounts
  - Upload oversized images

- [ ] **Business Logic Errors**
  - Try spending more than balance
  - Try adding more than max group members
  - Try removing group admin
  - Try repaying more than loan amount

### Unit Testing Examples

Create file: `/test/services/error_handler_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:SPLITSMART/services/error_handler_service.dart';
import 'package:SPLITSMART/utils/app_exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late ErrorHandlerService errorHandler;

  setUp(() {
    errorHandler = ErrorHandlerService();
  });

  group('ErrorHandlerService', () {
    test('handles auth exception for invalid credentials', () {
      final error = AuthException('Invalid login credentials');
      final result = errorHandler.handleError(error);

      expect(result, isA<AuthException>());
      expect(result.message, contains('Invalid email or password'));
      expect((result as AuthException).code, 'INVALID_CREDENTIALS');
    });

    test('handles database exception for RLS violation', () {
      final error = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
      final result = errorHandler.handleError(error);

      expect(result, isA<DatabaseException>());
      expect(result.message, contains('permission'));
      expect((result as DatabaseException).code, 'PERMISSION_DENIED');
    });

    test('handles business logic error messages', () {
      final message = errorHandler.getBusinessLogicMessage(
        'INSUFFICIENT_BALANCE',
        params: {'required': 500, 'current': 100},
      );

      expect(message, contains('500'));
      expect(message, contains('100'));
    });
  });
}
```

---

## Monitoring & Logging

### Production Error Tracking Setup

#### Option 1: Firebase Crashlytics (Recommended)

Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^latest
  firebase_crashlytics: ^latest
```

Update `logger_service.dart`:
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LoggerService {
  /// Log error to Crashlytics in production
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('[ERROR] $message');
      if (error != null) print('[ERROR_DETAILS] $error');
      if (stackTrace != null) print('[STACK_TRACE] $stackTrace');
    } else {
      // Production: Send to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
        fatal: false,
      );
    }
  }

  /// Set user context for error tracking
  void setUserContext(String userId, String email) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
      // Don't log sensitive PII like email in production
    }
  }
}
```

#### Option 2: Sentry

Add to `pubspec.yaml`:
```yaml
dependencies:
  sentry_flutter: ^latest
```

Initialize in `main.dart`:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.tracesSampleRate = 1.0;
      options.beforeSend = (event, hint) {
        // Filter sensitive data before sending
        return event;
      };
    },
    appRunner: () => runApp(const MyApp()),
  );
}
```

### Dashboard Metrics to Monitor

1. **Error Rate by Type**
   - Authentication errors
   - Network errors
   - Database errors
   - Business logic errors

2. **Most Common Errors**
   - Top 10 error messages
   - Error frequency over time

3. **User Impact**
   - Number of users affected
   - Error rate per user
   - Critical vs non-critical errors

4. **Performance**
   - Average response time
   - Timeout occurrences
   - Slow query detection

---

## Best Practices Summary

1. ✅ **Never expose sensitive information** in user-facing error messages
2. ✅ **Always log full error details** (including stack traces) for debugging
3. ✅ **Provide actionable error messages** (e.g., "Check internet connection")
4. ✅ **Use specific error types** instead of generic "Something went wrong"
5. ✅ **Implement retry mechanisms** for recoverable errors (network, timeout)
6. ✅ **Validate input early** to prevent unnecessary API calls
7. ✅ **Use consistent error handling patterns** across the app
8. ✅ **Test error scenarios** as thoroughly as success scenarios
9. ✅ **Monitor production errors** with proper error tracking tools
10. ✅ **Document error codes** for easier debugging and support

---

## Migration Checklist

- [ ] Create `app_exceptions.dart` with custom exception classes
- [ ] Create `error_handler_service.dart` with error mapping logic
- [ ] Create `logger_service.dart` for logging
- [ ] Create `error_display.dart` widget helpers
- [ ] Update all service files to use error handler
- [ ] Update all screens to handle specific error types
- [ ] Add error state widgets to loading screens
- [ ] Write unit tests for error handling
- [ ] Set up Firebase Crashlytics or Sentry
- [ ] Test all error scenarios manually
- [ ] Update documentation with error codes
- [ ] Train support team on common error messages
