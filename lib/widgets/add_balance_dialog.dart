import 'package:flutter/material.dart';

class AddBalanceDialog extends StatefulWidget {
  final List<Map<String, dynamic>> defaultBalanceTitles;
  final Function(double amount, String title, String? description) onAdd;

  const AddBalanceDialog({
    super.key,
    required this.defaultBalanceTitles,
    required this.onAdd,
  });

  @override
  State<AddBalanceDialog> createState() => _AddBalanceDialogState();
}

class _AddBalanceDialogState extends State<AddBalanceDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedBalanceTitle;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Helper method to convert icon names to IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'computer':
        return Icons.computer;
      case 'trending_up':
        return Icons.trending_up;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'money_off':
        return Icons.money_off;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'movie':
        return Icons.movie;
      case 'receipt':
        return Icons.receipt;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'flight':
        return Icons.flight;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'music_note':
        return Icons.music_note;
      case 'book':
        return Icons.book;
      case 'gaming':
        return Icons.games;
      default:
        return Icons.attach_money;
    }
  }

  void _handleAdd() {
    final amount = double.tryParse(_amountController.text);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    widget.onAdd(amount, title, description.isNotEmpty ? description : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Balance'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: double.maxFinite,

        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs)',
                  prefixText: 'Rs ',
                ),
              ),
              const SizedBox(height: 20),
              // Dropdown for balance titles
              DropdownButtonFormField<String>(
                value: _selectedBalanceTitle,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select a title or type custom'),
                isExpanded: true,
                items: [
                  ...widget.defaultBalanceTitles.map((title) {
                    final iconName = title['icon'] as String?;
                    final titleText = title['title'] as String;
                    return DropdownMenuItem<String>(
                      value: titleText,
                      child: Row(
                        children: [
                          if (iconName != null) ...[
                            Icon(_getIconData(iconName), size: 20),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: Text(titleText)),
                        ],
                      ),
                    );
                  }),
                  // Custom option
                  const DropdownMenuItem<String>(
                    value: 'custom',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('Custom title...')),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBalanceTitle = value;
                    if (value != null && value != 'custom') {
                      _titleController.text = value;
                    } else {
                      _titleController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedBalanceTitle == 'custom')
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Title',
                    hintText: 'e.g., Salary, Freelance',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _selectedBalanceTitle = 'custom';
                      });
                    }
                  },
                ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Additional details',
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _handleAdd, child: const Text('Add')),
      ],
    );
  }
}
