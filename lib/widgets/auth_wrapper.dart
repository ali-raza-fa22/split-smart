import 'package:flutter/material.dart';
import 'package:SPLITSMART/screens/home_screen.dart';
import 'package:SPLITSMART/screens/login_screen.dart';
import 'package:SPLITSMART/screens/verify_email_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            // User is logged in, check if email is verified
            final user = session.user;
            if (user.emailConfirmedAt == null) {
              // Email not verified, show verify email screen
              return VerifyEmailScreen(email: user.email ?? '');
            }
            // Email is verified, show chat list
            return const HomeScreen();
          }
        }
        // User is not logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}
