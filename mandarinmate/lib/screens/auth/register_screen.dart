import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ErrorSnackBar.show(context, 'Please agree to the Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify UTM email
      final isUTMEmail = await _authService.isUTMEmail(_emailController.text);
      if (!isUTMEmail) {
        if (!mounted) return;
        ErrorSnackBar.show(
          context,
          'Please use your UTM email (@student.utm.my or @utm.my)',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if username already exists
      final usernameExists =
          await _authService.usernameExists(_usernameController.text);
      if (usernameExists) {
        if (!mounted) return;
        ErrorSnackBar.show(context, 'Username already taken. Please choose another.');
        setState(() => _isLoading = false);
        return;
      }

      // Register user
      final userCredential = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Navigate to role selection
      Navigator.pushReplacementNamed(
        context,
        '/role-selection',
        arguments: {
          'uid': userCredential.user!.uid,
          'email': _emailController.text,
          'username': _usernameController.text,
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
        },
      );

      if (mounted) {
        ErrorSnackBar.showSuccess(
          context,
          'Registration successful! Please select your role.',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Username is required';
    }
    if (value!.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button and header
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: AppColors.primaryColor),
                          const SizedBox(width: AppDimensions.sm),
                          Text(
                            'Back',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Header
                    const AuthHeader(
                      title: 'Create Account',
                      subtitle: 'Join MandarinMate UTM and start learning',
                    ),
                    const SizedBox(height: AppDimensions.xxl),

                    // First Name
                    CustomTextField(
                      label: 'First Name',
                      hint: 'Enter your first name',
                      controller: _firstNameController,
                      prefixIcon: const Icon(Icons.person_outlined),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Last Name
                    CustomTextField(
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      controller: _lastNameController,
                      prefixIcon: const Icon(Icons.person_outlined),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Email
                    CustomTextField(
                      label: 'Email',
                      hint: 'your_email@student.utm.my',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Email is required';
                        }
                        if (!EmailValidator.validate(value!)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Username
                    CustomTextField(
                      label: 'Username',
                      hint: 'Choose a unique username',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.at),
                      validator: _validateUsername,
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Password
                    CustomTextField(
                      label: 'Password',
                      hint: 'At least 8 characters',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Password is required';
                        }
                        if (value!.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'Password must contain at least one number';
                        }
                        if (!value.contains(RegExp(r'[a-z]'))) {
                          return 'Password must contain at least one lowercase letter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Confirm Password
                    CustomTextField(
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      controller: _confirmPasswordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Terms & Conditions checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() => _agreedToTerms = value ?? false);
                          },
                          activeColor: AppColors.primaryColor,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: AppTextStyles.bodySmall,
                                ),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.xxl),

                    // Register button
                    CustomButton(
                      label: 'Create Account',
                      isLoading: _isLoading,
                      onPressed: _register,
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Login link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Already have an account? ',
                              style: AppTextStyles.bodyMedium,
                            ),
                            TextSpan(
                              text: 'Login',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer:
                                  TapGestureRecognizer()..onTap = () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xl),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            LoadingOverlay(
              isLoading: _isLoading,
              message: 'Creating your account...',
            ),
        ],
      ),
    );
  }
}

class TapGestureRecognizer extends GestureRecognizer {
  final GestureTapCallback? onTap;

  TapGestureRecognizer({this.onTap});

  @override
  void addPointer(PointerDownEvent event) {
    if (onTap != null) onTap!();
  }
}
