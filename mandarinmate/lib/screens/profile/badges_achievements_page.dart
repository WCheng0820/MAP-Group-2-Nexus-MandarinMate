import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BadgeItem {
  final String id;
  final String title;
  final String icon;
  final String description;
  final String unlockCriteria;
  final bool unlocked;

  const BadgeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.unlockCriteria,
    required this.unlocked,
  });
}

class BadgesAchievementsPage extends StatefulWidget {
  final int xp;
  final int streak;
  final List<dynamic> completedLessons;
  final int level;

  const BadgesAchievementsPage({
    super.key,
    required this.xp,
    required this.streak,
    required this.completedLessons,
    required this.level,
  });

  @override
  State<BadgesAchievementsPage> createState() => _BadgesAchievementsPageState();
}

class _BadgesAchievementsPageState extends State<BadgesAchievementsPage> {
  bool isAdmin = false;
  bool isLoading = true;
  final Map<String, TextEditingController> controllers = {};
  bool isSaving = false;
  String? saveMessage;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final role = userDoc.data()?['role'] ?? '';

        if (role == 'admin') {
          await _loadBadgeConfigsForEditing();
          if (mounted) {
            setState(() => isAdmin = true);
          }
        }
      }
      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error checking admin: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadBadgeConfigsForEditing() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('badges_config')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final badgeId = doc.id;
        final fields = _getFieldsForBadge(badgeId);

        for (var field in fields) {
          final key = '${badgeId}_$field';
          controllers[key] = TextEditingController(
            text: data[field]?.toString() ?? '',
          );
        }
      }
    } catch (e) {
      print('Error loading configs: $e');
    }
  }

  List<String> _getFieldsForBadge(String badgeId) {
    switch (badgeId) {
      case 'streak_7':
        return ['streakThreshold'];
      case 'first_lesson':
        return ['xpThreshold'];
      case 'perfect_score':
      case 'speed_learner':
      case 'speaker':
        return ['xpThreshold', 'lessonThreshold'];
      case 'bookworm':
        return ['lessonThreshold'];
      case 'top_learner':
        return ['xpThreshold'];
      case 'graduate':
        return ['lessonThreshold', 'levelThreshold'];
      default:
        return [];
    }
  }

  Future<void> _saveBadgeConfigs() async {
    try {
      setState(() => isSaving = true);

      final badgeIds = [
        'streak_7',
        'first_lesson',
        'perfect_score',
        'speed_learner',
        'speaker',
        'bookworm',
        'top_learner',
        'graduate',
      ];

      for (var badgeId in badgeIds) {
        final data = <String, dynamic>{};
        final fields = _getFieldsForBadge(badgeId);

        for (var field in fields) {
          final key = '${badgeId}_$field';
          final value = int.tryParse(controllers[key]?.text ?? '0') ?? 0;
          data[field] = value;
        }

        await FirebaseFirestore.instance
            .collection('badges_config')
            .doc(badgeId)
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
          saveMessage = '✗ Error: $e';
        });
      }
    }
  }

  List<BadgeItem> _getBadges() {
    return [
      BadgeItem(
        id: 'streak_7',
        title: '7-Day Streak',
        icon: '🔥',
        description:
            'Vibrant focus! Unlocked by keeping up a daily study routine.',
        unlockCriteria: 'Maintain a 7-day study streak.',
        unlocked: widget.streak >= 7,
      ),
      BadgeItem(
        id: 'first_lesson',
        title: 'First Lesson',
        icon: '⭐',
        description:
            'First steps! Unlocked by starting your Mandarin adventure.',
        unlockCriteria: 'Complete your first vocabulary lesson.',
        unlocked: widget.completedLessons.isNotEmpty || widget.xp >= 30,
      ),
      BadgeItem(
        id: 'perfect_score',
        title: 'Perfect Score',
        icon: '🎯',
        description:
            'Bullseye! Unlocked by showing complete mastery in your quiz.',
        unlockCriteria: 'Earn a 100% score on any lesson quiz.',
        unlocked: widget.xp >= 100 || widget.completedLessons.length >= 2,
      ),
      BadgeItem(
        id: 'speed_learner',
        title: 'Speed Learner',
        icon: '⚡',
        description:
            'Lightning fast! Unlocked by practicing vocabulary with high speed.',
        unlockCriteria: 'Complete a vocabulary lesson in under 2 minutes.',
        unlocked: widget.xp >= 250 || widget.completedLessons.length >= 3,
      ),
      BadgeItem(
        id: 'speaker',
        title: 'Speaker',
        icon: '🗣️',
        description:
            'Vocal maestro! Unlocked by recording speech and passing pronunciation checkpoints.',
        unlockCriteria: 'Record voice input and pass 5 pronunciation lessons.',
        unlocked: widget.xp >= 500 || widget.completedLessons.length >= 5,
      ),
      BadgeItem(
        id: 'bookworm',
        title: 'Bookworm',
        icon: '📚',
        description:
            'Book lover! Unlocked by expanding your knowledge base extensively.',
        unlockCriteria: 'Complete 8 lessons in your learning path.',
        unlocked: widget.completedLessons.length >= 8,
      ),
      BadgeItem(
        id: 'top_learner',
        title: 'Top Learner',
        icon: '🏆',
        description:
            'Peak performance! Unlocked by climbing to the absolute top.',
        unlockCriteria: 'Earn 1,000 XP in total.',
        unlocked: widget.xp >= 1000,
      ),
      BadgeItem(
        id: 'graduate',
        title: 'Graduate',
        icon: '🎓',
        description:
            'Milestone achieved! Unlocked by finishing the overall course material.',
        unlockCriteria: 'Complete 12 lessons or reach Level 6.',
        unlocked: widget.completedLessons.length >= 12 || widget.level >= 6,
      ),
    ];
  }

  String _getFieldLabel(String field) {
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

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        appBar: AppBar(
          title: const Text('Badges & Achievements'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE93A2F), Color(0xFFFF8A21)],
              ),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final badges = _getBadges();
    final unlockedCount = badges.where((b) => b.unlocked).length;

    if (isAdmin) {
      return _buildAdminView(badges, unlockedCount);
    } else {
      return _buildStudentView(badges, unlockedCount);
    }
  }

  Widget _buildStudentView(List<BadgeItem> badges, int unlockedCount) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text(
          'Badges & Achievements',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE93A2F), Color(0xFFFF8A21)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE93A2F), Color(0xFFFF8A21)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Milestones',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$unlockedCount/${badges.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: unlockedCount / badges.length,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  unlockedCount == badges.length
                      ? 'Incredible! You have unlocked all milestones! 🏆'
                      : 'Unlock ${badges.length - unlockedCount} more badges to complete the set!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                return GestureDetector(
                  onTap: () => _showBadgeDetails(context, badge),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: badge.unlocked
                            ? const Color(0xFFFFD54F).withOpacity(0.5)
                            : const Color(0xFFECEFF1),
                        width: badge.unlocked ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: badge.unlocked
                              ? Colors.amber.withOpacity(0.06)
                              : Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: badge.unlocked
                                  ? const Color(0xFFFFF9C4).withOpacity(0.5)
                                  : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                              border: badge.unlocked
                                  ? Border.all(
                                      color: const Color(0xFFFFD54F),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Opacity(
                                opacity: badge.unlocked ? 1.0 : 0.25,
                                child: Text(
                                  badge.icon,
                                  style: const TextStyle(fontSize: 36),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            badge.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: badge.unlocked
                                  ? const Color(0xFF263238)
                                  : const Color(0xFF90A4AE),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badge.unlocked
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFECEFF1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge.unlocked ? 'Unlocked' : 'Locked',
                              style: TextStyle(
                                color: badge.unlocked
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF78909C),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminView(List<BadgeItem> badges, int unlockedCount) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        elevation: 0,
        title: const Text('Badges & Achievements'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge Unlock Thresholds',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Edit the values below to adjust when badges unlock for students.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
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
            ..._buildEditFields(badges),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveBadgeConfigs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
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
                          color: Colors.white,
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

  List<Widget> _buildEditFields(List<BadgeItem> badges) {
    return badges.map((badge) {
      final fields = _getFieldsForBadge(badge.id);
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(badge.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        badge.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF718096),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...fields.map((field) {
              final key = '${badge.id}_$field';
              final label = _getFieldLabel(field);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
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
            }).toList(),
          ],
        ),
      );
    }).toList();
  }

  void _showBadgeDetails(BuildContext context, BadgeItem badge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCFD8DC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: badge.unlocked
                            ? const Color(0xFFFFF9C4)
                            : const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                        border: badge.unlocked
                            ? Border.all(
                                color: const Color(0xFFFFD54F),
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: badge.unlocked ? 1.0 : 0.3,
                          child: Text(
                            badge.icon,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      badge.title,
                      style: const TextStyle(
                        color: Color(0xFF263238),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badge.unlocked
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge.unlocked ? 'Unlocked!' : 'Locked',
                        style: TextStyle(
                          color: badge.unlocked
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE93A2F),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      badge.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFECEFF1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HOW TO UNLOCK',
                            style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge.unlockCriteria,
                            style: const TextStyle(
                              color: Color(0xFF37474F),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE93A2F), Color(0xFFFF8A21)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          height: 52,
                          child: const Text(
                            'Great!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
