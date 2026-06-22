import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ADDED for BLoC
import 'package:go_router/go_router.dart'; // ADDED for Navigation
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart'; // ADDED for BLoC Events
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginTab = true;
  bool _rememberMe = true;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Registration State
  String _selectedRole = 'Student';

  // Register controllers
  final _regFirstNameController = TextEditingController();
  final _regLastNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regFirstNameController.dispose();
    _regLastNameController.dispose();
    _regEmailController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Email Verification Required'),
        content: const Text(
          'Please verify your email to continue. Check your inbox for the verification link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    String title,
    String message,
    String type,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'registration') {
                setState(() => _isLoginTab = true);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (!_loginFormKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
    } catch (e) {
      debugPrint('Error saving remember_me: $e');
    }

    if (mounted) {
      // Send the Login Event to the BLoC
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        ),
      );
    }
  }

  void _register() {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ErrorSnackBar.show(context, 'Please agree to the Terms & Conditions');
      return;
    }

    final fullName = _regFirstNameController.text.trim();
    final nameParts = fullName.split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Send the Register Event to the BLoC
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        firstName: firstName,
        lastName: lastName,
        username: _regUsernameController.text.trim(),
        role: _selectedRole,
      ),
    );
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
    // BlocConsumer listens to the AuthBloc to update the UI based on state
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          if (state.message == 'EMAIL_UNVERIFIED') {
            _showVerificationDialog(context);
          } else if (state.message == 'REGISTRATION_SUCCESS') {
            _showSuccessDialog(
              context,
              'Account Created!',
              'Your account has been created successfully.\nPlease check your email to verify the account.',
              'registration',
            );
          } else {
            ErrorSnackBar.show(context, state.message);
          }
        } else if (state is AuthProfileIncomplete) {
          // If a user somehow has no profile, log them out and show error.
          context.read<AuthBloc>().add(AuthLogoutRequested());
          ErrorSnackBar.show(
            context,
            'Account profile is incomplete. Please contact support or register again.',
          );
        } else if (state is AuthAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      },
      builder: (context, state) {
        // Automatically show loading spinner if the BLoC is working
        final bool isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Red Header - Full Width
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: AppDimensions.xxl * 2,
                        bottom: AppDimensions.xl * 3,
                        left: AppDimensions.xl,
                        right: AppDimensions.xl,
                      ),
                      child: Column(
                        children: [
                          // Logo
                          Image.asset(
                            'assets/images/MandarinMate_logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'MandarinMate UTM',
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'Welcome back! 欢迎回来',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Container for Tabs and Form
                    Transform.translate(
                      offset: const Offset(
                        0,
                        -32,
                      ), // overlap the header slightly
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.lg,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXL,
                          ),
                          border: Border.all(color: context.borderTheme),
                          boxShadow: [
                            BoxShadow(
                              color: context.isDarkMode
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : AppColors.shadowColor,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Tab Navigation
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.lg,
                                vertical: AppDimensions.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _isLoginTab = true),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Log In',
                                            style: AppTextStyles.headlineSmall
                                                .copyWith(
                                                  color: _isLoginTab
                                                      ? AppColors.primaryColor
                                                      : context.textMuted,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (_isLoginTab)
                                            Container(
                                              height: 3,
                                              margin: const EdgeInsets.only(
                                                top: AppDimensions.sm,
                                              ),
                                              color: AppColors.primaryColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _isLoginTab = false),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Sign Up',
                                            style: AppTextStyles.headlineSmall
                                                .copyWith(
                                                  color: !_isLoginTab
                                                      ? AppColors.primaryColor
                                                      : context.textMuted,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (!_isLoginTab)
                                            Container(
                                              height: 3,
                                              margin: const EdgeInsets.only(
                                                top: AppDimensions.sm,
                                              ),
                                              color: AppColors.primaryColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Form Area
                            Padding(
                              padding: const EdgeInsets.all(AppDimensions.xl),
                              child: _isLoginTab
                                  ? _buildLoginForm(isLoading)
                                  : _buildRegisterForm(isLoading),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                LoadingOverlay(
                  isLoading: isLoading,
                  message: _isLoginTab
                      ? 'Logging in...'
                      : 'Creating account...',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginForm(bool isLoading) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email field
          CustomTextField(
            label: 'UTM Email',
            hint: 'student@utm.my',
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Email is required';
              }
              if (!value!.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),

          // Password field
          CustomTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _loginPasswordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outlined),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Password is required';
              }
              if (value!.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),

          // Remember Me & Forgot Password Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value ?? false);
                    },
                    activeColor: const Color(0xFF6C3BFF),
                  ),
                  Text(
                    'Remember Me',
                    style: AppTextStyles.bodySmall.copyWith(color: context.textMuted),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  context.push('/forgot-password');
                },
                child: Text(
                  'Forgot Password?',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: context.isDarkMode ? Colors.purple.shade200 : const Color(0xFF6C3BFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // Login button
          CustomButton(
            label: 'Log In',
            isLoading: isLoading,
            onPressed: _login,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: context.borderTheme)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                child: Text(
                  'or continue with',
                  style: AppTextStyles.bodySmall.copyWith(color: context.textMuted),
                ),
              ),
              Expanded(child: Divider(color: context.borderTheme)),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // Google button
          _buildGoogleButton(),
          const SizedBox(height: AppDimensions.xl),

          // Sign up link
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = false),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'New to MandarinMate? ',
                      style: AppTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    ),
                    TextSpan(
                      text: 'Sign Up',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.isDarkMode ? Colors.purple.shade200 : const Color(0xFF6C3BFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(bool isLoading) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          CustomTextField(
            label: 'Full Name',
            hint: 'e.g. Ahmad Zulkifli (Space for Last Name)',
            controller: _regFirstNameController,
            prefixIcon: const Icon(Icons.person_outlined),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),

          // Role (Visual only, actual assignment happens in RoleSelectionScreen)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role',
                style: AppTextStyles.labelLarge.copyWith(color: context.textDeep),
              ),
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  border: Border.all(color: context.borderTheme),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedRole,
                  dropdownColor: context.cardBg,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: context.textDeep, fontSize: 14),
                  items: [
                    DropdownMenuItem(
                      value: 'Student',
                      child: Text('Student', style: TextStyle(color: context.textDeep)),
                    ),
                    DropdownMenuItem(
                      value: 'Tutor',
                      child: Text('Tutor', style: TextStyle(color: context.textDeep)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xl),

          // Student ID
          CustomTextField(
            label: 'Student/Staff ID',
            hint: 'e.g. A12345',
            controller: _regUsernameController,
            prefixIcon: const Icon(Icons.badge_outlined),
            validator: _validateUsername,
          ),
          const SizedBox(height: AppDimensions.xl),

          // Email
          CustomTextField(
            label: 'UTM Email',
            hint: 'student@utm.my',
            controller: _regEmailController,
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

          // Password
          CustomTextField(
            label: 'Password',
            hint: 'At least 8 characters',
            controller: _regPasswordController,
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
            controller: _regConfirmPasswordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outlined),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please confirm your password';
              }
              if (value != _regPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),

          // Terms checkbox
          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: (value) {
                  setState(() => _agreedToTerms = value ?? false);
                },
                activeColor: const Color(0xFF6C3BFF),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'I agree to the ',
                        style: AppTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.isDarkMode ? Colors.purple.shade200 : const Color(0xFF6C3BFF),
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

          // Create Account button
          CustomButton(
            label: 'Create Account',
            isLoading: isLoading,
            onPressed: _register,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: context.borderTheme)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                child: Text(
                  'or continue with',
                  style: AppTextStyles.bodySmall.copyWith(color: context.textMuted),
                ),
              ),
              Expanded(child: Divider(color: context.borderTheme)),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // Google button
          _buildGoogleButton(),
          const SizedBox(height: AppDimensions.lg),

          // Login link
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = true),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Already have an account? ',
                      style: AppTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    ),
                    TextSpan(
                      text: 'Log In',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.isDarkMode ? Colors.purple.shade200 : const Color(0xFF6C3BFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xl),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
        side: BorderSide(color: context.borderTheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
      onPressed: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', _rememberMe);
        } catch (e) {
          debugPrint('Error saving remember_me: $e');
        }
        if (mounted) {
          context.read<AuthBloc>().add(AuthGoogleSignInRequested());
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G',
            style: AppTextStyles.labelLarge.copyWith(
              color: const Color(0xFF4285F4),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Text(
            'Google Account',
            style: AppTextStyles.bodyMedium.copyWith(color: context.textDeep),
          ),
        ],
      ),
    );
  }
}
