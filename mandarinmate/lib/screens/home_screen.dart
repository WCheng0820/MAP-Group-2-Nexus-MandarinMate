import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          context.go('/auth');
          ErrorSnackBar.showSuccess(context, 'Logged out successfully');
        }
        if (state is AuthError && mounted) {
          setState(() => _isLoading = false);
          ErrorSnackBar.show(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          backgroundColor: AppColors.primaryColor,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppDimensions.xxl),

                  // Welcome message
                  Text(
                    'Welcome to MandarinMate UTM!',
                    style: AppTextStyles.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // User email
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLarge,
                      ),
                      border: Border.all(color: AppColors.primaryColor),
                    ),
                    child: Text(
                      'Email: ${currentUser?.email}',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xxl * 2),

                  // Sprint 1 completion info
                  Card(
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusLarge,
                        ),
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentication Sprint 1 Complete! ✅',
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          ...const [
                            '✓ User Registration',
                            '✓ User Login',
                            '✓ UTM Email Validation',
                            '✓ Role Selection (Student, Tutor, Admin)',
                            '✓ Profile Setup',
                            '✓ Firebase Integration',
                            '✓ New UI Design with Red Theme',
                          ].map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.md,
                              ),
                              child: Text(
                                feature,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xxl * 2),

                  // Logout button
                  CustomButton(
                    label: 'Logout',
                    onPressed: _logout,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
            if (_isLoading)
              LoadingOverlay(isLoading: _isLoading, message: 'Logging out...'),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AuthLogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout successful'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
