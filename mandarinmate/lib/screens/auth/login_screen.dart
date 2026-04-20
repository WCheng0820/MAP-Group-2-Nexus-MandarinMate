import 'package:flutter/material.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

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

      // Login
      final userCredential = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Get user profile
      final userProfile =
          await _authService.getUserProfile(userCredential.user!.uid);

      if (userProfile != null) {
        // Navigate to home based on role
        _navigateToNextScreen(userProfile);
      } else {
        // User exists but no profile, navigate to role selection
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/role-selection',
            arguments: userCredential.user!.uid,
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, _authService.toString());
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

  void _navigateToNextScreen(UserProfile userProfile) {
    // Navigate to home screen (this will be implemented in main app)
    Navigator.pushReplacementNamed(context, '/home');
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
                    const SizedBox(height: AppDimensions.xl),
                    // Header
                    const AuthHeader(
                      title: 'Welcome Back',
                      subtitle: 'Login to continue your Mandarin journey',
                    ),
                    const SizedBox(height: AppDimensions.xxl * 2),

                    // Email field
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
                      controller: _passwordController,
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
                        onPressed: () {
                          // TODO: Navigate to forgot password screen
                        },
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
                      label: 'Login',
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Sign up link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "Don't have an account? ",
                              style: AppTextStyles.bodyMedium,
                            ),
                            TextSpan(
                              text: 'Register',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer:
                                  TapGestureRecognizer()..onTap = () {
                                Navigator.pushNamed(context, '/register');
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
              message: 'Logging in...',
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
