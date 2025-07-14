import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:SPLITSMART/screens/home_screen.dart';
import 'package:SPLITSMART/screens/all_balance_transactions_screen.dart';
import 'package:SPLITSMART/screens/chat_list_screen.dart';
import 'package:SPLITSMART/screens/all_expenses_screen.dart';

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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6), // Padding from above
          NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
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
            height: 70,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primary,
            // Use Theme to override selected icon/label color
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined,
                  color:
                      currentIndex == 0
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(Icons.home, color: colorScheme.onPrimary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color:
                      currentIndex == 1
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.onPrimary,
                ),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color:
                      currentIndex == 2
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(
                  Icons.chat_bubble,
                  color: colorScheme.onPrimary,
                ),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.receipt_long_outlined,
                  color:
                      currentIndex == 3
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(
                  Icons.receipt_long,
                  color: colorScheme.onPrimary,
                ),
                label: 'Expenses',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
