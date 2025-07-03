import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../widgets/ui/brand_text_form_field.dart';
import '../widgets/ui/brand_filled_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getUserProfile();
      if (profile != null) {
        setState(() {
          _profile = profile;
          _usernameController.text = profile['username'] ?? '';
          _displayNameController.text = profile['display_name'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.updateProfile(
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), centerTitle: false),
      body:
          _isLoading && _profile == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandTextFormField(
                        controller: _usernameController,
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BrandTextFormField(
                        controller: _displayNameController,
                        labelText: 'Display Name',
                        hintText: 'Enter your display name',
                        prefixIcon: Icons.badge,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a display name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      BrandFilledButton(
                        text: 'Save Changes',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        onPressed: _isLoading ? null : _updateProfile,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
