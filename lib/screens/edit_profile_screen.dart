import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../widgets/ui/brand_text_form_field.dart';
import '../widgets/ui/brand_filled_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

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
  File? _pickedImage;

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
        ).showSnackBar(SnackBar(content: Text('Error loading profile')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final status =
        await Permission.photos.request(); // Request gallery permission
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant permission to access photos'),
          ),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No image selected')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image')));
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
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage:
                                  _pickedImage != null
                                      ? FileImage(_pickedImage!)
                                      : (_profile != null &&
                                          _profile!['avatar_url'] != null &&
                                          _profile!['avatar_url']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(_profile!['avatar_url'])
                                          as ImageProvider
                                      : null,
                              child:
                                  (_pickedImage == null &&
                                          (_profile == null ||
                                              _profile!['avatar_url'] == null ||
                                              _profile!['avatar_url']
                                                  .toString()
                                                  .isEmpty))
                                      ? const Icon(Icons.person, size: 48)
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isLoading ? null : _pickImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                        onPressed:
                            _isLoading
                                ? null
                                : () async {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _isLoading = true);
                                    try {
                                      String? avatarUrl =
                                          _profile != null
                                              ? _profile!['avatar_url']
                                              : null;
                                      final userId =
                                          Supabase
                                              .instance
                                              .client
                                              .auth
                                              .currentUser!
                                              .id;
                                      if (_pickedImage != null) {
                                        final fileExt =
                                            _pickedImage!.path
                                                .split('.')
                                                .last
                                                .toLowerCase(); // quick and dirty way
                                        final filePath =
                                            '$userId/avatar.$fileExt';
                                        final fileBytes =
                                            await _pickedImage!.readAsBytes();
                                        await Supabase.instance.client.storage
                                            .from('avatars')
                                            .uploadBinary(
                                              filePath,
                                              fileBytes,
                                              fileOptions: FileOptions(
                                                contentType:
                                                    fileExt == 'png'
                                                        ? 'image/png'
                                                        : 'image/jpeg',
                                                upsert: true,
                                              ),
                                            );
                                        avatarUrl = Supabase
                                            .instance
                                            .client
                                            .storage
                                            .from('avatars')
                                            .getPublicUrl(filePath);
                                      }
                                      await Supabase.instance.client
                                          .from('profiles')
                                          .update({
                                            'username':
                                                _usernameController.text.trim(),
                                            'display_name':
                                                _displayNameController.text
                                                    .trim(),
                                            'avatar_url': avatarUrl,
                                          })
                                          .eq('id', userId);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Profile updated successfully',
                                            ),
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Something bad happened.',
                                            ),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  }
                                },
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
