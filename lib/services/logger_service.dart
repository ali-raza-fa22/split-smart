import 'package:flutter/foundation.dart';

/// Minimal logger service. In debug mode prints to console. In production
/// you can wire this to Crashlytics, Sentry, etc.
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  void info(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[INFO] $message');
      if (data != null) print('[DATA] $data');
    }
  }

  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('[ERROR] $message');
      print("====================");
      if (error != null) print('[ERROR_DETAILS] $error');
      if (stackTrace != null) print('[STACK_TRACE] $stackTrace');
    }
  }

  void warning(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[WARNING] $message');
      if (data != null) print('[DATA] $data');
    }
  }

  void debug(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('[DEBUG] $message');
      if (data != null) print('[DATA] $data');
    }
  }
}
