import 'dart:io';

import 'package:SPLITSMART/utils/app_utils.dart';
import 'package:SPLITSMART/utils/supabase.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth.dart';
import '../widgets/ui/brand_filled_button.dart';
import '../widgets/ui/brand_text_form_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// Full screen image viewer used for previewing avatars.
class FullScreenImage extends StatelessWidget {
  final ImageProvider imageProvider;

  const FullScreenImage({super.key, required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  Map<String, dynamic>? _profile;
  File? _pickedImage;
  final _supabase = SupabaseManager.client;
  String _previewUsername = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Update preview as user types
    _usernameController.addListener(_updatePreviewUsername);
    _displayNameController.addListener(_updatePreviewUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _usernameController.removeListener(_updatePreviewUsername);
    _displayNameController.removeListener(_updatePreviewUsername);
    super.dispose();
  }

  void _updatePreviewUsername() {
    final raw =
        _usernameController.text.isNotEmpty
            ? _usernameController.text
            : _displayNameController.text;
    final normalized = AppUtils.normalizeUsername(raw.trim());
    if (mounted) setState(() => _previewUsername = normalized);
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getUserProfile();

      print(_supabase.auth.currentUser);
      if (profile != null) {
        setState(() {
          _profile = profile;
          final displayName = profile['display_name'] ?? '';
          // default username will be normalized display name when username missing
          final existingUsername = (profile['username'] ?? '').toString();
          _displayNameController.text = displayName;
          if (existingUsername.isNotEmpty) {
            _usernameController.text = existingUsername;
          } else {
            final defaultUsername = AppUtils.normalizeUsername(displayName);
            _usernameController.text = defaultUsername;
          }
          // initialize preview
          _previewUsername = AppUtils.normalizeUsername(
            _usernameController.text,
          );
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
    final theme = Theme.of(context);
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
                            // If there's an image (picked or from profile), make the avatar tappable
                            Builder(
                              builder: (context) {
                                final bool hasImage =
                                    _pickedImage != null ||
                                    (_profile != null &&
                                        _profile!['avatar_url'] != null &&
                                        _profile!['avatar_url']
                                            .toString()
                                            .isNotEmpty);
                                ImageProvider? imageProvider;
                                if (_pickedImage != null) {
                                  imageProvider = FileImage(_pickedImage!);
                                } else if (_profile != null &&
                                    _profile!['avatar_url'] != null &&
                                    _profile!['avatar_url']
                                        .toString()
                                        .isNotEmpty) {
                                  imageProvider = NetworkImage(
                                    _profile!['avatar_url'],
                                  );
                                }

                                final avatar = CircleAvatar(
                                  radius: 48,
                                  backgroundImage: imageProvider,
                                  child:
                                      imageProvider == null
                                          ? const Icon(
                                            Icons.person_outlined,
                                            size: 48,
                                          )
                                          : null,
                                );

                                if (!hasImage) return avatar;

                                return InkWell(
                                  onTap: () {
                                    if (!hasImage) return;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => FullScreenImage(
                                              imageProvider: imageProvider!,
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(48),
                                  child: avatar,
                                );
                              },
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isLoading ? null : _pickImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
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
                      // Email card (no shadow)
                      Builder(
                        builder: (context) {
                          final email =
                              _supabase.auth.currentUser?.email ??
                              (_profile != null
                                  ? (_profile!['email'] ?? '')
                                  : '');
                          if (email == null ||
                              email.toString().trim().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final verified =
                              _supabase
                                  .auth
                                  .currentUser
                                  ?.userMetadata?['email_verified']
                                  ?.toString() ??
                              '';
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email.toString(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (verified.isNotEmpty)
                                        Text(
                                          'Verified: $verified',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      BrandTextFormField(
                        controller: _usernameController,
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icons.person_outlined,
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return null; // optional
                          final normalized = AppUtils.normalizeUsername(v);
                          if (normalized.isEmpty)
                            return 'Please enter a valid username';
                          if (normalized.length < 2)
                            return 'Username must be at least 2 characters';
                          // optionally warn if normalization changed the value
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Live normalized username preview
                      if (_previewUsername.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            'Username: $_previewUsername',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      BrandTextFormField(
                        controller: _displayNameController,
                        labelText: 'Display Name',
                        hintText: 'Enter your display name',
                        prefixIcon: Icons.badge_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a display name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.only(left: 16.0, right: 16.0),
          child: BrandFilledButton(
            text: 'Save Changes',
            backgroundColor: theme.colorScheme.primary,
            onPressed:
                _isLoading
                    ? null
                    : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        try {
                          String? avatarUrl =
                              _profile != null ? _profile!['avatar_url'] : null;
                          final userId = _supabase.auth.currentUser!.id;
                          if (_pickedImage != null) {
                            final fileExt =
                                _pickedImage!.path
                                    .split('.')
                                    .last
                                    .toLowerCase();
                            final filePath = '$userId/avatar.$fileExt';
                            final fileBytes = await _pickedImage!.readAsBytes();
                            await _supabase.storage
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
                            avatarUrl = _supabase.storage
                                .from('avatars')
                                .getPublicUrl(filePath);
                          }
                          // Add cache-busting query param
                          avatarUrl =
                              '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';

                          final rawUsername =
                              _usernameController.text.trim().isNotEmpty
                                  ? _usernameController.text.trim()
                                  : _displayNameController.text.trim();
                          final usernameToSave = AppUtils.normalizeUsername(
                            rawUsername,
                          );

                          await _supabase
                              .from('profiles')
                              .update({
                                'username': usernameToSave,
                                'display_name':
                                    _displayNameController.text.trim(),
                                'avatar_url': avatarUrl,
                              })
                              .eq('id', userId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully'),
                              ),
                            );
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Something bad happened.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      }
                    },
            isLoading: _isLoading,
          ),
        ),
      ),
    );
  }
}
