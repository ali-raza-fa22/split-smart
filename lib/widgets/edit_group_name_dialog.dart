import 'package:flutter/material.dart';
import 'ui/brand_text_form_field.dart';

class EditGroupNameDialog extends StatefulWidget {
  final String initialName;
  const EditGroupNameDialog({super.key, required this.initialName});

  @override
  State<EditGroupNameDialog> createState() => _EditGroupNameDialogState();
}

class _EditGroupNameDialogState extends State<EditGroupNameDialog> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  void _saveGroupName() {
    _clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _controller.text.trim();

    // Check if name is the same as initial
    if (newName == widget.initialName) {
      Navigator.of(context).pop();
      return;
    }

    // Validate name length
    if (newName.length < 2) {
      setState(() {
        _errorText = 'Group name must be at least 2 characters long';
      });
      return;
    }

    if (newName.length > 50) {
      setState(() {
        _errorText = 'Group name must be less than 50 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate loading for better UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pop(newName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Rename Group',
        style: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a new name for your group',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            BrandTextFormField(
              controller: _controller,
              labelText: 'Group Name',
              hintText: 'Enter group name',
              prefixIcon: Icons.group,
              errorText: _errorText,
              onChanged: (value) => _clearError(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                if (value.trim().length < 2) {
                  return 'Group name must be at least 2 characters long';
                }
                if (value.trim().length > 50) {
                  return 'Group name must be less than 50 characters';
                }
                return null;
              },
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _saveGroupName,
          child:
              _isLoading
                  ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  )
                  : Text('Save', style: TextStyle(color: colorScheme.primary)),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
