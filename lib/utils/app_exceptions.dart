/// Custom application exceptions used across the app.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

class AppAuthException extends AppException {
  AppAuthException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

class NetworkException extends AppException {
  NetworkException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

class DatabaseException extends AppException {
  DatabaseException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(
    String message, {
    this.fieldErrors,
    String? code,
    dynamic originalError,
  }) : super(message, code: code, originalError: originalError);
}

class BusinessLogicException extends AppException {
  BusinessLogicException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}

class UnknownException extends AppException {
  UnknownException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);
}
