import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/features/lessons/data/mock_lessons.dart';
import 'package:mandarinmate/models/user_model.dart';
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

  // Helper function to extract the last 7 days of XP data
  List<Map<String, dynamic>> _getWeeklyData(Map<String, int> dailyActivity) {
    final List<Map<String, dynamic>> weeklyData = [];
    final now = DateTime.now();
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Format as YYYY-MM-DD
      final dateString =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final xp = dailyActivity[dateString] ?? 0;
      final dayLabel = weekdays[date.weekday - 1];

      weeklyData.add({'day': dayLabel, 'xp': xp});
    }
    return weeklyData;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final profile = state.profile;
          final totalLessons = mockCourseUnits.fold<int>(
            0,
                (sum, unit) => sum + unit.lessons.length,
          );
          final completedCount = profile.completedLessons.length;
          final progressPercent = totalLessons > 0
              ? completedCount / totalLessons
              : 0.0;

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimensions.lg),

                      // Welcome message
                      Text(
                        'Hello, ${profile.firstName}!',
                        style: AppTextStyles.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'Keep up the great work!',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.xl),

                      // Progress Overview Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Level',
                              '${profile.level}',
                              Icons.stars,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: _buildStatCard(
                              'XP Points',
                              '${profile.xpPoints}',
                              Icons.bolt,
                              Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // Weekly Progress Chart
                      _buildWeeklyProgressChart(profile),
                      const SizedBox(height: AppDimensions.lg),

                      // Learning Progress Summary
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLarge,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Overall Progress',
                                    style: AppTextStyles.headlineSmall,
                                  ),
                                  Text(
                                    '${(progressPercent * 100).toInt()}%',
                                    style: AppTextStyles.headlineSmall.copyWith(
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.md),
                              LinearProgressIndicator(
                                value: progressPercent,
                                backgroundColor: AppColors.primaryLight,
                                color: AppColors.primaryColor,
                                minHeight: 12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              const SizedBox(height: AppDimensions.md),
                              Text(
                                '$completedCount of $totalLessons lessons completed',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // Last Learning Progress / Continue
                      _buildContinueCard(profile),

                      const SizedBox(height: AppDimensions.xl),

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
                  LoadingOverlay(
                    isLoading: _isLoading,
                    message: 'Logging out...',
                  ),
              ],
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.headlineSmall),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressChart(UserProfile profile) {
    final List<Map<String, dynamic>> weeklyData = _getWeeklyData(profile.dailyActivity);

    // Find the highest XP day to scale the bars dynamically
    final double maxXP = weeklyData
        .map((d) => (d['xp'] as int).toDouble())
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Activity (XP)',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              height: 120, // Height of the chart area
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeklyData.map((data) {
                  final percentage = data['xp'] / maxXP;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Tooltip equivalent - show value above bar
                      Text(
                        '${data['xp']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD40511), // DHL Red
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Animated Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: 24,
                        // 80 is the max physical pixel height of the bar
                        height: 80 * percentage,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00), // DHL Yellow
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFD40511), // Red outline
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Day Label
                      Text(
                        data['day'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueCard(dynamic profile) {
    var nextLessonTitle = 'Start your first lesson!';
    var nextLessonSubtitle = 'Unit 1: Basics';

    bool found = false;
    for (var unit in mockCourseUnits) {
      for (var lesson in unit.lessons) {
        if (!profile.completedLessons.contains(lesson.id)) {
          nextLessonTitle = lesson.title;
          nextLessonSubtitle = unit.title;
          found = true;
          break;
        }
      }
      if (found) break;
    }

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          gradient: AppColors.primaryGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Learning Progress 📚',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              found ? 'Continue where you left off:' : 'All caught up!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              nextLessonTitle,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              nextLessonSubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigating to lesson...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Continue Learning'),
            ),
          ],
        ),
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