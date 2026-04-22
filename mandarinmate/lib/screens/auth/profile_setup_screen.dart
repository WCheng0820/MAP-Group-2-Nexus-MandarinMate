import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? setupData;

  const ProfileSetupScreen({super.key, this.setupData});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthService _authService = AuthService();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _selectedAvatar;

  final List<String> _avatarEmojis = [
    '😊',
    '😃',
    '😄',
    '😁',
    '🤓',
    '😎',
    '🧑‍🎓',
    '👨‍🏫',
    '🧑‍💼',
    '👨‍💻',
    '🎯',
    '⭐',
  ];

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupData = widget.setupData ?? {};
    final uid = setupData['uid'] ?? '';
    final role = setupData['role'] ?? 'student';
    final email = setupData['email'] ?? '';
    final username = setupData['username'] ?? '';
    final firstName = setupData['firstName'] ?? '';
    final lastName = setupData['lastName'] ?? '';

    _selectedAvatar ??= _avatarEmojis.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.xl),

                // Header
                const AuthHeader(
                  title: 'Complete Your Profile',
                  subtitle: 'Personalize your MandarinMate experience',
                ),
                const SizedBox(height: AppDimensions.xxl * 2),

                // Avatar Selection
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedAvatar!,
                            style: const TextStyle(fontSize: 60),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      Text(
                        'Choose Your Avatar',
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Avatar Grid
                Center(
                  child: Wrap(
                    spacing: AppDimensions.md,
                    runSpacing: AppDimensions.md,
                    children: _avatarEmojis
                        .map(
                          (emoji) => GestureDetector(
                            onTap: () {
                              setState(() => _selectedAvatar = emoji);
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedAvatar == emoji
                                    ? AppColors.primaryLight
                                    : AppColors.dividerColor.withValues(
                                        alpha: 0.3,
                                      ),
                                border: Border.all(
                                  color: _selectedAvatar == emoji
                                      ? AppColors.primaryColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppDimensions.xxl),

                // Profile Info Display
                Container(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusLarge,
                    ),
                    border: Border.all(color: AppColors.primaryColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Information',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _buildInfoRow('Name', '$firstName $lastName'),
                      _buildInfoRow('Email', email),
                      _buildInfoRow('Username', username),
                      _buildInfoRow('Role', role.toUpperCase()),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.xxl),

                // Bio (Optional)
                CustomTextField(
                  label: 'Bio (Optional)',
                  hint: 'Tell others about yourself',
                  controller: _bioController,
                  maxLines: 3,
                  minLines: 3,
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(height: AppDimensions.xxl),

                // Complete button
                CustomButton(
                  label: 'Complete Setup',
                  isLoading: _isLoading,
                  onPressed: () => _completeSetup(
                    uid,
                    role,
                    email,
                    username,
                    firstName,
                    lastName,
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Skip button
                CustomButton(
                  label: 'Skip for Now',
                  isOutlined: true,
                  onPressed: () => _completeSetup(
                    uid,
                    role,
                    email,
                    username,
                    firstName,
                    lastName,
                    skipBio: true,
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          ),
          if (_isLoading)
            LoadingOverlay(
              isLoading: _isLoading,
              message: 'Completing your setup...',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: AppDimensions.xs),
        Text(value, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimensions.lg),
      ],
    );
  }

  Future<void> _completeSetup(
    String uid,
    String role,
    String email,
    String username,
    String firstName,
    String lastName, {
    bool skipBio = false,
  }) async {
    setState(() => _isLoading = true);

    try {
      // Parse role
      UserRole userRole = UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == role.toLowerCase(),
        orElse: () => UserRole.student,
      );

      // Create user profile
      await _authService.createUserProfile(
        uid: uid,
        email: email,
        username: username.toLowerCase(),
        firstName: firstName,
        lastName: lastName,
        role: userRole,
      );

      // Update with bio and avatar if provided
      if (!skipBio && _bioController.text.isNotEmpty) {
        await _authService.updateUserProfile(
          uid: uid,
          updates: {'bio': _bioController.text, 'avatar': _selectedAvatar},
        );
      } else if (_selectedAvatar != null) {
        await _authService.updateUserProfile(
          uid: uid,
          updates: {'avatar': _selectedAvatar},
        );
      }

      if (!mounted) return;

      // Navigate to home screen
      context.go('/home');

      ErrorSnackBar.showSuccess(
        context,
        'Profile setup complete! Welcome to MandarinMate UTM',
      );
    } catch (e) {
      if (mounted) {
        ErrorSnackBar.show(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
