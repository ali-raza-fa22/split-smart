import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../screens/verify_email_screen.dart';

import '../utils/app_exceptions.dart';
import 'error_handler_service.dart';
import 'logger_service.dart';

class AuthService {
  final supabase = Supabase.instance.client;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final LoggerService _logger = LoggerService();

  // Get current user
  User? get currentUser => supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => supabase.auth.currentSession;

  // Register with email and password
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
      // Do NOT create profile here. Only after email is verified.
      return response;
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('register failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.register');
    }
  }

  // Send OTP for email verification
  Future<void> sendOTP(String email) async {
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('sendOTP failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.sendOTP');
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      // After successful verification, create profile if not exists
      if (response.user != null) {
        final userId = response.user!.id;
        final existing =
            await supabase
                .from('profiles')
                .select('id')
                .eq('id', userId)
                .maybeSingle();
        if (existing == null) {
          await supabase.from('profiles').insert({
            'id': userId,
            'username': email.split('@')[0],
            'display_name': email.split('@')[0],
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
      print("username: ${email.split('@')[0]}");
      return response;
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('verifyOTP failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.verifyOTP');
    }
  }

  // Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print(response);
      return response;
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('login failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.login');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('logout failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.logout');
    }
  }

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Check if email is confirmed
  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  // Check if current user's email is verified (with session refresh)
  Future<bool> isCurrentUserEmailVerified() async {
    try {
      if (currentUser == null) return false;

      // Refresh the session to get the latest email confirmation status
      await supabase.auth.refreshSession();

      // Check if email is confirmed after refresh
      return supabase.auth.currentUser?.emailConfirmedAt != null;
    } catch (e, st) {
      _logger.error(
        'isCurrentUserEmailVerified failed',
        error: e,
        stackTrace: st,
      );
      // don't rethrow - this is a safe check used in UI flows; return false
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response =
          await supabase
              .from('profiles')
              .select()
              .eq('id', currentUser!.id.toString())
              .single();
      return response;
    } catch (e, st) {
      _logger.error('getUserProfile failed', error: e, stackTrace: st);
      // Keep prior behaviour of returning null on error but log it
      return null;
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      if (currentUser == null) throw Exception('No user logged in');

      final updates = {
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabase.from('profiles').upsert({
        'id': currentUser!.id.toString(),
        ...updates,
      }).select();
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('updateProfile failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.updateProfile');
    }
  }

  // Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      await supabase.auth.updateUser(UserAttributes(email: newEmail));
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('updateEmail failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.updateEmail');
    }
  }

  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('updatePassword failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(e, context: 'AuthService.updatePassword');
    }
  }

  // Get email confirmation status
  Future<bool> checkEmailConfirmation() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      // Refresh the user data
      await supabase.auth.refreshSession();
      return supabase.auth.currentUser?.emailConfirmedAt != null;
    } catch (e, st) {
      _logger.error('checkEmailConfirmation failed', error: e, stackTrace: st);
      return false;
    }
  }

  // Send OTP for password reset
  Future<void> sendPasswordResetOTP(String email) async {
    try {
      await supabase.auth.signInWithOtp(email: email, emailRedirectTo: null);
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('sendPasswordResetOTP failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(
        e,
        context: 'AuthService.sendPasswordResetOTP',
      );
    }
  }

  // Reset password with OTP and update password
  Future<void> resetPasswordWithOTP({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      // First verify the OTP which signs the user in
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );

      if (response.user != null) {
        // Update the password
        await supabase.auth.updateUser(UserAttributes(password: newPassword));

        // Sign out the user to ensure they login with new password
        await supabase.auth.signOut();
      } else {
        throw AppAuthException('Failed to verify OTP', code: 'VERIFY_FAILED');
      }
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.error('resetPasswordWithOTP failed', error: e, stackTrace: st);
      throw _errorHandler.handleError(
        e,
        context: 'AuthService.resetPasswordWithOTP',
      );
    }
  }

  // Check if user needs email verification and handle redirect
  Future<bool> checkAndHandleEmailVerification(BuildContext context) async {
    try {
      if (currentUser == null) return true; // No user logged in, allow access

      // Check if email is verified
      final isVerified = await isCurrentUserEmailVerified();

      if (!isVerified) {
        // Email not verified, redirect to verification screen
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      VerifyEmailScreen(email: currentUser?.email ?? ''),
            ),
          );
        }
        return false; // Don't allow access
      }

      return true; // Email verified, allow access
    } catch (e, st) {
      _logger.error(
        'checkAndHandleEmailVerification failed',
        error: e,
        stackTrace: st,
      );
      // On error, allow access to prevent blocking the user
      return true;
    }
  }
}
