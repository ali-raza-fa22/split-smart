import 'dart:io';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../utils/app_exceptions.dart';
import 'logger_service.dart';

/// Convert low-level exceptions (Supabase/Postgrest/Network) into
/// AppException types with user-friendly messages and codes.
class ErrorHandlerService {
  final LoggerService _logger = LoggerService();

  AppException handleError(dynamic error, {String? context}) {
    _logger.error('Error in ${context ?? 'unknown'}', error: error);
    print("----------------------------");

    // Supabase Postgrest errors
    if (error is supa.PostgrestException) {
      final msg = error.message.toLowerCase();
      final code = error.code;

      if (code == '42501' || msg.contains('row-level security')) {
        return DatabaseException(
          'You do not have permission to perform this action.',
          code: 'PERMISSION_DENIED',
          originalError: error,
        );
      }

      if (code == '23505' || msg.contains('unique')) {
        return DatabaseException(
          'This record already exists.',
          code: 'DUPLICATE_RECORD',
          originalError: error,
        );
      }

      if (msg.contains('timeout') || msg.contains('timed out')) {
        return DatabaseException(
          'The operation timed out.',
          code: 'TIMEOUT',
          originalError: error,
        );
      }

      return DatabaseException(
        msg,
        code: 'DATABASE_ERROR',
        originalError: error,
      );
    }

    // Supabase auth related errors (fall back to message mapping)
    if (error is supa.AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid') && message.contains('password')) {
        return AppAuthException(
          error.message,
          code: 'INVALID_CREDENTIALS',
          originalError: error,
        );
      }

      if (message.contains('email') && message.contains('confirm')) {
        return AppAuthException(
          'Please verify your email before logging in.',
          code: 'EMAIL_NOT_CONFIRMED',
          originalError: error,
        );
      }

      return AppAuthException(
        error.message,
        code: 'AUTH_ERROR',
        originalError: error,
      );
    }

    // Storage errors
    if (error is supa.StorageException) {
      final m = (error.message).toLowerCase();
      if (m.contains('permission') || m.contains('unauthorized')) {
        return DatabaseException(
          'You do not have permission to upload files.',
          code: 'UPLOAD_PERMISSION_DENIED',
          originalError: error,
        );
      }

      return DatabaseException(
        'Failed to upload file.',
        code: 'UPLOAD_ERROR',
        originalError: error,
      );
    }

    // Network related
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return NetworkException(
        'Unable to connect. Please check your internet connection.',
        code: 'NETWORK_ERROR',
        originalError: error,
      );
    }

    if (error is FormatException) {
      return ValidationException(
        'Invalid data format.',
        originalError: error,
        code: 'FORMAT_ERROR',
      );
    }

    if (error is AppException) {
      return error;
    }

    return UnknownException(
      'An unexpected error occurred.',
      originalError: error,
    );
  }
}
