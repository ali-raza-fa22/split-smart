import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:split_smart_supabase/screens/home_screen.dart';
import 'package:split_smart_supabase/screens/all_balance_transactions_screen.dart';
import 'package:split_smart_supabase/screens/chat_list_screen.dart';
import 'package:split_smart_supabase/screens/all_expenses_screen.dart';

class MainScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final String? title;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;
  final Widget? titleWidget;
  const MainScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.title,
    this.floatingActionButton,
    this.bottom,
    this.actions,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(left: 12),
          child: SvgPicture.asset('assets/icons/SPLITSMART.svg', height: 18),
        ),
        centerTitle: false,
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.7),
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          Widget screen;
          switch (index) {
            case 0:
              screen = const HomeScreen();
              break;
            case 1:
              screen = const AllBalanceTransactionsScreen();
              break;
            case 2:
              screen = const ChatListScreen();
              break;
            case 3:
              screen = const AllExpensesScreen();
              break;
            default:
              screen = const HomeScreen();
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}
