import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth.dart';
import '../widgets/ui/brand_text_form_field.dart';
import '../widgets/ui/brand_filled_button.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isResending = false;
  String? _userEmail;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _initializeEmail();
  }

  void _initializeEmail() {
    // If email is provided in widget, use it
    if (widget.email.isNotEmpty) {
      _userEmail = widget.email;
    } else {
      // Otherwise, get email from current user
      final currentUser = _authService.currentUser;
      _userEmail = currentUser?.email;
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _clearOtpError() {
    if (_otpError != null) {
      setState(() {
        _otpError = null;
      });
    }
  }

  Future<void> _verifyOTP() async {
    // Clear previous errors
    _clearOtpError();

    // Validate OTP
    if (_otpController.text.isEmpty) {
      setState(() {
        _otpError = 'Please enter the verification code';
      });
      return;
    }

    if (_otpController.text.length != 6) {
      setState(() {
        _otpError = 'Code must be 6 digits';
      });
      return;
    }

    if (_userEmail == null || _userEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email not available. Please login again.'),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.verifyOTP(
          email: _userEmail!,
          token: _otpController.text,
        );
        if (mounted) {
          // Navigate to chat list after successful verification
          Navigator.pushReplacementNamed(context, '/chat_list');
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

  Future<void> _resendOTP() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email not available. Please login again.'),
        ),
      );
      return;
    }

    setState(() => _isResending = true);
    try {
      await _authService.sendOTP(_userEmail!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Verification code has been resent to your email',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // If no email is available, show error message
    if (_userEmail == null || _userEmail!.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: SvgPicture.asset(
                      'assets/icons/SPLITSMART.svg',
                      height: 32,
                    ),
                  ),
                  const SizedBox(height: 54),
                  Icon(Icons.error_outline, size: 80, color: colorScheme.error),
                  const SizedBox(height: 24),
                  Text(
                    'Email Not Available',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to verify your email. Please login again.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  BrandFilledButton(
                    text: 'Go to Login',
                    onPressed:
                        () => Navigator.pushReplacementNamed(context, '/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  32,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Center(
                      child: SvgPicture.asset(
                        'assets/icons/SPLITSMART.svg',
                        height: 32,
                      ),
                    ),
                    const SizedBox(height: 54),
                    Icon(
                      Icons.verified_user,
                      size: 80,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enter Verification Code',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit code to $_userEmail',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    BrandTextFormField(
                      controller: _otpController,
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icons.security,
                      keyboardType: TextInputType.number,
                      errorText: _otpError,
                      onChanged: (value) => _clearOtpError(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the verification code';
                        }
                        if (value.length != 6) {
                          return 'Code must be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    BrandFilledButton(
                      text: 'Verify',
                      onPressed: _isLoading ? null : _verifyOTP,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isResending ? null : _resendOTP,
                      child:
                          _isResending
                              ? Text(
                                'Resending...',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                              : Text(
                                'Didn\'t receive the code? Resend',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed:
                          () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                      child: Text(
                        'Back to Login',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
