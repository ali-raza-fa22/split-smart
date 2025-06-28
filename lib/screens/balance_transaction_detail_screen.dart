import 'package:flutter/material.dart';
import '../widgets/save_transaction_button.dart';
import '../widgets/transaction_details_card.dart';

class BalanceTransactionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const BalanceTransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: BalanceTransactionDetailCard(transaction: transaction),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: SaveTransactionButton(transaction: transaction),
            ),
          ],
        ),
      ),
    );
  }
}
