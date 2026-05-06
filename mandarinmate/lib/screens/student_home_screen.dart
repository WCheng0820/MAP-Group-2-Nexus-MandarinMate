import 'package:flutter/material.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
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
                  'Welcome to MandarinMate!',
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
                    'Student: ${currentUser?.email}',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppDimensions.xxl * 2),

                // Student specific info
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
                          'Your Learning Progress 📚',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        ...const [
                          '► Continue Lesson: HSK 1 Vocabulary',
                          '► Daily Challenge: Practice Tone Pronunciation',
                          '► Upcoming: Weekend Conversation Club',
                          '★ 150 Points Earned This Week!',
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
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);

    try {
      await _authService.logout();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
        ErrorSnackBar.showSuccess(context, 'Logged out successfully');
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, 'Error logging out: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
