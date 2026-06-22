import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class AdminBadgeConfigPage extends StatefulWidget {
  const AdminBadgeConfigPage({super.key});

  @override
  State<AdminBadgeConfigPage> createState() => _AdminBadgeConfigPageState();
}

class _AdminBadgeConfigPageState extends State<AdminBadgeConfigPage> {
  final Map<String, TextEditingController> controllers = {};
  bool isLoading = true;
  String? saveMessage;
  bool isSaving = false;

  final List<BadgeInfo> badges = [
    BadgeInfo(
      id: 'streak_7',
      name: '7-Day Streak',
      description: 'Maintain a 7-day learning streak',
      emoji: '🔥',
      fields: ['streakThreshold'],
    ),
    BadgeInfo(
      id: 'first_lesson',
      name: 'First Lesson',
      description: 'Complete your first lesson',
      emoji: '📚',
      fields: ['xpThreshold'],
    ),
    BadgeInfo(
      id: 'perfect_score',
      name: 'Perfect Score',
      description: 'Get perfect scores on quizzes',
      emoji: '⭐',
      fields: ['xpThreshold', 'lessonThreshold'],
    ),
    BadgeInfo(
      id: 'speed_learner',
      name: 'Speed Learner',
      description: 'Progress quickly through lessons',
      emoji: '🚀',
      fields: ['xpThreshold', 'lessonThreshold'],
    ),
    BadgeInfo(
      id: 'speaker',
      name: 'Speaker',
      description: 'Master pronunciation and speaking',
      emoji: '🎤',
      fields: ['xpThreshold', 'lessonThreshold'],
    ),
    BadgeInfo(
      id: 'bookworm',
      name: 'Bookworm',
      description: 'Complete many lessons',
      emoji: '📖',
      fields: ['lessonThreshold'],
    ),
    BadgeInfo(
      id: 'top_learner',
      name: 'Top Learner',
      description: 'Reach the highest XP',
      emoji: '👑',
      fields: ['xpThreshold'],
    ),
    BadgeInfo(
      id: 'graduate',
      name: 'Graduate',
      description: 'Complete all levels',
      emoji: '🏆',
      fields: ['lessonThreshold', 'levelThreshold'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadgeConfigs();
  }

  Future<void> _loadBadgeConfigs() async {
    try {
      setState(() => isLoading = true);

      for (var badge in badges) {
        final doc = await FirebaseFirestore.instance
            .collection('badges_config')
            .doc(badge.id)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          for (var field in badge.fields) {
            final key = '${badge.id}_$field';
            controllers[key] = TextEditingController(
              text: data[field]?.toString() ?? '',
            );
          }
        } else {
          // Initialize with empty if not found
          for (var field in badge.fields) {
            final key = '${badge.id}_$field';
            controllers[key] = TextEditingController();
          }
        }
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          saveMessage = 'Error loading configs: $e';
        });
      }
      print('Error loading badge configs: $e');
    }
  }

  Future<void> _saveBadgeConfigs() async {
    try {
      setState(() => isSaving = true);

      for (var badge in badges) {
        final data = <String, dynamic>{};
        for (var field in badge.fields) {
          final key = '${badge.id}_$field';
          final value = int.tryParse(controllers[key]?.text ?? '0') ?? 0;
          data[field] = value;
        }

        await FirebaseFirestore.instance
            .collection('badges_config')
            .doc(badge.id)
            .set(data, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          isSaving = false;
          saveMessage = '✓ Saved successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Badge configurations saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Clear message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => saveMessage = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaving = false;
          saveMessage = '✗ Error saving: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error saving badge configs: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF7B1FA2);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.isDarkMode ? context.cardBg : themeColor,
        elevation: 0,
        title: const Text('Badge Configuration'),
        centerTitle: true,
        foregroundColor: context.isDarkMode ? context.textDeep : Colors.white,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: themeColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderTheme),
                      boxShadow: [
                        BoxShadow(
                          color: context.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Badge Unlock Thresholds',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textDeep,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Edit the values below to adjust when badges unlock for students. Changes apply immediately.',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textMuted,
                          ),
                        ),
                        if (saveMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            saveMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: saveMessage!.startsWith('✓')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Badge Config Cards
                  ...badges.map((badge) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BadgeConfigCard(
                        badge: badge,
                        controllers: controllers,
                        themeColor: themeColor,
                      ),
                    );
                  }),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveBadgeConfigs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.isDarkMode ? Colors.purple.shade300 : themeColor,
                        foregroundColor: context.isDarkMode ? Colors.black : Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save All Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final List<String> fields;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.fields,
  });

  String getFieldLabel(String field) {
    switch (field) {
      case 'xpThreshold':
        return 'XP Required';
      case 'lessonThreshold':
        return 'Lessons Required';
      case 'streakThreshold':
        return 'Streak Days Required';
      case 'levelThreshold':
        return 'Level Required';
      default:
        return field;
    }
  }
}

class _BadgeConfigCard extends StatelessWidget {
  final BadgeInfo badge;
  final Map<String, TextEditingController> controllers;
  final Color themeColor;

  const _BadgeConfigCard({
    required this.badge,
    required this.controllers,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderTheme),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Header
          Row(
            children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input Fields
          ...badge.fields.map((field) {
            final key = '${badge.id}_$field';
            final controller = controllers[key];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.getFieldLabel(field),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.textDeep),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: context.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderTheme),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderTheme),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: context.isDarkMode ? Colors.purple.shade300 : themeColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
