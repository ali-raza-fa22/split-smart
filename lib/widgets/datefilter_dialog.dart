import 'package:flutter/material.dart';
import 'package:split_smart_supabase/utils/date_formatter.dart';

class DateFilterDialog extends StatefulWidget {
  final String selected;
  final DateTime? customStart;
  final DateTime? customEnd;
  const DateFilterDialog({
    super.key,
    required this.selected,
    this.customStart,
    this.customEnd,
  });
  @override
  State<DateFilterDialog> createState() => DateFilterDialogState();
}

class DateFilterDialogState extends State<DateFilterDialog> {
  late String _selected;
  DateTime? _customStart;
  DateTime? _customEnd;
  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _customStart = widget.customStart;
    _customEnd = widget.customEnd;
  }

  Future<void> _pickCustomDateRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (start != null) {
      final end = await showDatePicker(
        context: context,
        initialDate: _customEnd ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
      );
      if (end != null) {
        setState(() {
          _customStart = start;
          _customEnd = end;
          _selected = 'custom';
        });
        Navigator.pop(context, {
          'filter': 'custom',
          'customStart': start,
          'customEnd': end,
        });
      }
    }
  }

  Widget _buildOption(String value, String label) {
    final isSelected = _selected == value;
    return ListTile(
      onTap: () async {
        if (value == 'custom') {
          await _pickCustomDateRange();
        } else {
          setState(() => _selected = value);
          Navigator.pop(context, {'filter': value});
        }
      },
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor:
          isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Date Filter', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            _buildOption('all', 'All Time'),
            _buildOption('today', 'Today'),
            _buildOption('this_week', 'This Week'),
            _buildOption('this_month', 'This Month'),
            _buildOption('custom', 'Custom Range'),
            if (_selected == 'custom') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _customStart ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _customStart = date);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _customStart != null
                            ? DateFormatter.formatDate(_customStart!)
                            : 'Start Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _customEnd ?? (_customStart ?? DateTime.now()),
                          firstDate: _customStart ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _customEnd = date);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _customEnd != null
                            ? DateFormatter.formatDate(_customEnd!)
                            : 'End Date',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    (_customStart != null && _customEnd != null)
                        ? () => Navigator.pop(context, {
                          'filter': 'custom',
                          'customStart': _customStart,
                          'customEnd': _customEnd,
                        })
                        : null,
                child: const Text('Apply Custom Range'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
