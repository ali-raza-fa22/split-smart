import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../screens/verify_email_screen.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Register with email and password
  Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
      );
      // Do NOT create profile here. Only after email is verified.
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Send OTP for email verification
  Future<void> sendOTP(String email) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      // After successful verification, create profile if not exists
      if (response.user != null) {
        final userId = response.user!.id;
        final existing =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('id', userId)
                .maybeSingle();
        if (existing == null) {
          await _supabase.from('profiles').insert({
            'id': userId,
            'username': email.split('@')[0],
            'display_name': email.split('@')[0],
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
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
      await _supabase.auth.refreshSession();

      // Check if email is confirmed after refresh
      return _supabase.auth.currentUser?.emailConfirmedAt != null;
    } catch (e) {
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response =
          await _supabase
              .from('profiles')
              .select()
              .eq('id', currentUser!.id.toString())
              .single();
      return response;
    } catch (e) {
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

      await _supabase.from('profiles').upsert({
        'id': currentUser!.id.toString(),
        ...updates,
      }).select();
    } catch (e) {
      rethrow;
    }
  }

  // Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
    } catch (e) {
      rethrow;
    }
  }

  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      rethrow;
    }
  }

  // Get email confirmation status
  Future<bool> checkEmailConfirmation() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Refresh the user data
      await _supabase.auth.refreshSession();
      return _supabase.auth.currentUser?.emailConfirmedAt != null;
    } catch (e) {
      return false;
    }
  }

  // Send OTP for password reset
  Future<void> sendPasswordResetOTP(String email) async {
    try {
      await _supabase.auth.signInWithOtp(email: email, emailRedirectTo: null);
    } catch (e) {
      rethrow;
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
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );

      if (response.user != null) {
        // Update the password
        await _supabase.auth.updateUser(UserAttributes(password: newPassword));

        // Sign out the user to ensure they login with new password
        await _supabase.auth.signOut();
      } else {
        throw Exception('Failed to verify OTP');
      }
    } catch (e) {
      rethrow;
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
    } catch (e) {
      // On error, allow access to prevent blocking the user
      return true;
    }
  }
}
