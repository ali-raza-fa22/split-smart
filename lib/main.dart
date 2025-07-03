import 'package:flutter/material.dart';
import 'package:split_smart_supabase/screens/home_screen.dart';
import 'package:split_smart_supabase/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_email_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: dotenv.env['PROJECT_URL']!,
    anonKey: dotenv.env['API_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Split Smart',
      debugShowCheckedModeBanner: false,
      theme: getAppTheme(),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home_screen': (context) => const HomeScreen(),
        '/chat_list': (context) => const ChatListScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/verify_email': (context) => const VerifyEmailScreen(email: ''),
      },
    );
  }
}
