import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Create initial profile
      if (response.user != null) {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'username': email.split('@')[0], // Use part of email as username
          'display_name':
              email.split('@')[0], // Use part of email as display name
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

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
}
