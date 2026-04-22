import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoginTab = true;
  bool _isLoading = false;
  bool _canRedirectAfterLoginAction = false;

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
    _canRedirectAfterLoginAction = true;
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        // Menambahkan .trim() untuk keamanan login
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      ),
    );
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ErrorSnackBar.show(context, 'Please agree to the Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Validasi Domain UTM (Gunakan .trim() agar tidak terjebak spasi)
      final isUTMEmail = await _authService.isUTMEmail(
        _regEmailController.text.trim(),
      );

      if (!isUTMEmail) {
        if (!mounted) return;
        ErrorSnackBar.show(
          context,
          'Please use your UTM email (@graduate.utm.my or @utm.my)',
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Validasi Username
      final usernameExists = await _authService.usernameExists(
        _regUsernameController.text.trim(),
      );
      if (usernameExists) {
        if (!mounted) return;
        ErrorSnackBar.show(
          context,
          'Username already taken. Please choose another.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. Proses Register Ke Firebase
      final userCredential = await _authService.register(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
      );
      await _authService.createUserProfile(
        uid: userCredential.user!.uid,
        email: _regEmailController.text.trim(),
        username: _regUsernameController.text.trim(),
        firstName: _regFirstNameController.text.trim(),
        lastName: _regLastNameController.text.trim(),
        role: UserRole.student,
      );
      await _authService.logout();

      if (!mounted) return;

      context.go('/login');

      if (mounted) {
        ErrorSnackBar.showSuccess(
          context,
          'Registration successful! Please login.',
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

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    _canRedirectAfterLoginAction = true;
    context.read<AuthBloc>().add(AuthGoogleSignInRequested());
  }

  String? _validateUsername(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'Username is required';
    }
    final cleanValue = value!.trim();
    if (cleanValue.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (cleanValue.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanValue)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ErrorSnackBar.show(context, state.message);
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        if (state is AuthAuthenticated) {
          if (_isLoginTab && _canRedirectAfterLoginAction) {
            if (state.profile.role == UserRole.student) {
              context.go('/main');
            } else if (state.profile.role == UserRole.tutor) {
              context.go('/tutor-dashboard');
            } else {
              context.go('/admin-dashboard');
            }
            _canRedirectAfterLoginAction = false;
          }
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        if (state is AuthUnauthenticated && mounted) {
          setState(() => _isLoading = false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // Logo & Header Section
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
                        Image.asset(
                          'assets/images/MandarinMate_logo.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        Text(
                          'MandarinMate UTM',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
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

                  // Tab Selection (Log In / Sign Up)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.lg,
                      vertical: AppDimensions.md,
                    ),
                    child: Row(
                      children: [
                        _buildTabItem(
                          'Log In',
                          _isLoginTab,
                          () => setState(() => _isLoginTab = true),
                        ),
                        _buildTabItem(
                          'Sign Up',
                          !_isLoginTab,
                          () => setState(() => _isLoginTab = false),
                        ),
                      ],
                    ),
                  ),

                  // Form Section
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    child: _isLoginTab
                        ? _buildLoginForm()
                        : _buildRegisterForm(),
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
      ),
    );
  }

  Widget _buildTabItem(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(
                color: isActive
                    ? AppColors.primaryColor
                    : AppColors.textTertiary,
              ),
            ),
            if (isActive)
              Container(
                height: 3,
                margin: const EdgeInsets.only(top: AppDimensions.sm),
                color: AppColors.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: 'UTM Email',
            hint: 'student@utm.my',
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) return 'Email is required';
              if (!value!.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),
          CustomTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _loginPasswordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outlined),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Password is required' : null,
          ),
          const SizedBox(height: AppDimensions.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: AppColors.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xxl),
          CustomButton(
            label: 'Log In',
            isLoading: _isLoading,
            onPressed: _login,
          ),
          const SizedBox(height: AppDimensions.lg),
          _buildDivider(),
          const SizedBox(height: AppDimensions.lg),
          _buildGoogleButton(),
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
          CustomTextField(
            label: 'Full Name',
            hint: 'e.g. Ahmad Zulkifli',
            controller: _regFirstNameController,
            prefixIcon: const Icon(Icons.person_outlined),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: AppDimensions.xl),

          CustomTextField(
            label: 'Student/Staff ID',
            hint: 'e.g. A12345',
            controller: _regUsernameController,
            prefixIcon: const Icon(Icons.badge_outlined),
            validator: _validateUsername,
          ),
          const SizedBox(height: AppDimensions.xl),
          CustomTextField(
            label: 'UTM Email',
            hint: 'name@graduate.utm.my',
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Email is required';
              }
              if (!EmailValidator.validate(value!.trim())) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),
          CustomTextField(
            label: 'Password',
            hint: 'At least 8 characters',
            controller: _regPasswordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outlined),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Min. 8 characters';
              }
              if (!value.contains(RegExp(r'[0-9]'))) {
                return 'Must contain a number';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.xl),
          CustomTextField(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            controller: _regConfirmPasswordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outlined),
            validator: (value) => value != _regPasswordController.text
                ? 'Passwords do not match'
                : null,
          ),
          const SizedBox(height: AppDimensions.xl),
          _buildTermsCheckbox(),
          const SizedBox(height: AppDimensions.xxl),
          CustomButton(
            label: 'Create Account',
            isLoading: _isLoading,
            onPressed: _register,
          ),
          const SizedBox(height: AppDimensions.lg),
          _buildDivider(),
          const SizedBox(height: AppDimensions.lg),
          _buildGoogleButton(),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          activeColor: AppColors.primaryColor,
        ),
        const Expanded(child: Text('I agree to the Terms & Conditions')),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.dividerColor)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.md),
          child: Text('or continue with'),
        ),
        Expanded(child: Divider(color: AppColors.dividerColor)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
      onPressed: _loginWithGoogle,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: AppDimensions.md),
          Text('UTM Google Account'),
        ],
      ),
    );
  }
}
