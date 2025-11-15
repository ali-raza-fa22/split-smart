import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseManager
///
/// Lightweight singleton-style helpers around the shared Supabase client
/// and the currently authenticated user.
///
/// Usage:
/// ```dart
/// // Make sure Supabase is initialized in `main()` before using this.
/// final supabase = SupabaseManager.client; // SupabaseClient
/// final user = SupabaseManager.currentUser; // User? (null if not signed in)
/// final id = SupabaseManager.userId; // String? user id
/// final signedIn = SupabaseManager.isSignedIn; // bool
///
/// // Listen for auth changes:
/// SupabaseManager.auth.onAuthStateChange.listen((event, session) {
///   // react to sign-in / sign-out
/// });
///
/// // Sign out helper:
/// await SupabaseManager.signOut();
/// ```
///
/// Note: initialize Supabase in `main()` like:
/// ```dart
/// await Supabase.initialize(
///   url: dotenv.env['SUPABASE_URL']!,
///   anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
/// );
/// ```
class SupabaseManager {
  SupabaseManager._(); // private constructor - utility-only class

  /// Shared Supabase client
  /// Use this anywhere in the app to perform DB, Auth or Storage operations.
  static SupabaseClient get client => Supabase.instance.client;

  /// Shorthand for the auth API
  static get auth => client.auth;

  /// Returns the current authenticated user, or null if not authenticated.
  ///
  /// Example: `final user = SupabaseManager.currentUser;`
  static User? get currentUser => auth.currentUser;

  /// User id (nullable)
  static String? get userId => currentUser?.id;

  /// True if a user is signed in
  static bool get isSignedIn => currentUser != null;

  /// Convenience sign-out helper
  static Future<void> signOut() async {
    await auth.signOut();
  }
}
