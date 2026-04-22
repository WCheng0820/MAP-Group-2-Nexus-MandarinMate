import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/widgets/custom_widgets.dart';

class RoleSelectionScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const RoleSelectionScreen({super.key, this.userData});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData ?? {};
    final uid = userData['uid'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role'),
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
                  title: 'Choose Your Role',
                  subtitle: 'Select how you want to use MandarinMate UTM',
                ),
                const SizedBox(height: AppDimensions.xxl * 2),

                RoleCard(
                  title: 'Student',
                  description:
                      'Learn Mandarin through interactive lessons and daily challenges',
                  icon: Icons.school_outlined,
                  isSelected: _selectedRole == UserRole.student,
                  color: AppColors.studentColor,
                  onTap: () {
                    setState(() => _selectedRole = UserRole.student);
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                RoleCard(
                  title: 'Tutor',
                  description:
                      'Teach Mandarin and guide students in their learning journey',
                  icon: Icons.person_outline,
                  isSelected: _selectedRole == UserRole.tutor,
                  color: AppColors.tutorColor,
                  onTap: () {
                    setState(() => _selectedRole = UserRole.tutor);
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                RoleCard(
                  title: 'Admin',
                  description:
                      'Manage the platform and oversee community activities',
                  icon: Icons.admin_panel_settings_outlined,
                  isSelected: _selectedRole == UserRole.admin,
                  color: AppColors.adminColor,
                  onTap: () {
                    setState(() => _selectedRole = UserRole.admin);
                  },
                ),
                const SizedBox(height: AppDimensions.xxl * 2),
                CustomButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _selectedRole != null
                      ? () => _continueToProfileSetup(uid, userData)
                      : () {},
                ),
                const SizedBox(height: AppDimensions.lg),
                CustomButton(
                  label: 'Go Back',
                  isOutlined: true,
                  onPressed: () => context.go('/auth'),
                ),
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          ),
          if (_isLoading)
            LoadingOverlay(
              isLoading: _isLoading,
              message: 'Setting up your profile...',
            ),
        ],
      ),
    );
  }

  Future<void> _continueToProfileSetup(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    if (_selectedRole == null) return;

    setState(() => _isLoading = true);

    try {
      // Navigate to profile setup screen
      if (mounted) {
        context.push(
          '/profile-setup',
          extra: {
            'uid': uid,
            'role': _selectedRole!.toString().split('.').last,
            'email': userData['email'],
            'username': userData['username'],
            'firstName': userData['firstName'],
            'lastName': userData['lastName'],
          },
        );
      }
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
