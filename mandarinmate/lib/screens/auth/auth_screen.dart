import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoginTab = true;
  bool _isLoading = false;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

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

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isUTMEmail = await _authService.isUTMEmail(_loginEmailController.text);
      if (!isUTMEmail) {
        if (!mounted) return;
        ErrorSnackBar.show(
          context,
          'Please use your UTM email (@student.utm.my or @utm.my)',
        );
        setState(() => _isLoading = false);
        return;
      }

      final userCredential = await _authService.login(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );

      if (!mounted) return;

      final userProfile =
          await _authService.getUserProfile(userCredential.user!.uid);

      if (userProfile != null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/role-selection',
            arguments: userCredential.user!.uid,
          );
        }
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

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ErrorSnackBar.show(context, 'Please agree to the Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isUTMEmail = await _authService.isUTMEmail(_regEmailController.text);
      if (!isUTMEmail) {
        if (!mounted) return;
        ErrorSnackBar.show(
          context,
          'Please use your UTM email (@student.utm.my or @utm.my)',
        );
        setState(() => _isLoading = false);
        return;
      }

      final usernameExists =
          await _authService.usernameExists(_regUsernameController.text);
      if (usernameExists) {
        if (!mounted) return;
        ErrorSnackBar.show(context, 'Username already taken. Please choose another.');
        setState(() => _isLoading = false);
        return;
      }

      final userCredential = await _authService.register(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/role-selection',
        arguments: {
          'uid': userCredential.user!.uid,
          'email': _regEmailController.text,
          'username': _regUsernameController.text,
          'firstName': _regFirstNameController.text,
          'lastName': _regLastNameController.text,
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
          SingleChildScrollView(
            child: Column(
              children: [
                // Red Header - Full Width
                Container(
                  color: AppColors.primaryColor,
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: AppDimensions.xxl,
                    bottom: AppDimensions.lg,
                    left: AppDimensions.xl,
                    right: AppDimensions.xl,
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/MandarinMate_logo.png',
                        width: 60,
                        height: 60,
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
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'Welcome back! 欢迎回来',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          onTap: () => setState(() => _isLoginTab = true),
                          child: Column(
                            children: [
                              Text(
                                'Log In',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: _isLoginTab
                                      ? AppColors.primaryColor
                                      : AppColors.textTertiary,
                                ),
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
                          onTap: () => setState(() => _isLoginTab = false),
                          child: Column(
                            children: [
                              Text(
                                'Sign Up',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: !_isLoginTab
                                      ? AppColors.primaryColor
                                      : AppColors.textTertiary,
                                ),
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
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: _isLoginTab ? _buildLoginForm() : _buildRegisterForm(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            LoadingOverlay(
              isLoading: _isLoading,
              message: _isLoginTab ? 'Logging in...' : 'Creating account...',
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
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

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Forgot Password?',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xxl),

          // Login button
          CustomButton(
            label: 'Log In',
            isLoading: _isLoading,
            onPressed: _login,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                child: Text(
                  'or continue with',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Expanded(child: Divider(color: AppColors.dividerColor)),
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
                      style: AppTextStyles.bodyMedium,
                    ),
                    TextSpan(
                      text: 'Sign Up',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryColor,
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

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          CustomTextField(
            label: 'Full Name',
            hint: 'e.g. Ahmad Zulkifli',
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

          // Role
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerColor),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: DropdownButton<String>(
                  value: 'Student',
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Tutor', child: Text('Tutor')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {},
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

          // Create Account button
          CustomButton(
            label: 'Create Account',
            isLoading: _isLoading,
            onPressed: _register,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                child: Text(
                  'or continue with',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Expanded(child: Divider(color: AppColors.dividerColor)),
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
                      style: AppTextStyles.bodyMedium,
                    ),
                    TextSpan(
                      text: 'Log In',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryColor,
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
        side: const BorderSide(color: AppColors.dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
      onPressed: () {
        // TODO: Implement Google Sign-in
        ErrorSnackBar.show(context, 'Google Sign-in coming soon!');
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
            'UTM Google Account',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
