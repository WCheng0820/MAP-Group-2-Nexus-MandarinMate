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

class BadgesAchievementsPage extends StatelessWidget {
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

  List<BadgeItem> _getBadges() {
    return [
      BadgeItem(
        id: 'streak_7',
        title: '7-Day Streak',
        icon: '🔥',
        description: 'Vibrant focus! Unlocked by keeping up a daily study routine.',
        unlockCriteria: 'Maintain a 7-day study streak.',
        unlocked: streak >= 7,
      ),
      BadgeItem(
        id: 'first_lesson',
        title: 'First Lesson',
        icon: '⭐',
        description: 'First steps! Unlocked by starting your Mandarin adventure.',
        unlockCriteria: 'Complete your first vocabulary lesson.',
        unlocked: completedLessons.isNotEmpty || xp >= 30,
      ),
      BadgeItem(
        id: 'perfect_score',
        title: 'Perfect Score',
        icon: '🎯',
        description: 'Bullseye! Unlocked by showing complete mastery in your quiz.',
        unlockCriteria: 'Earn a 100% score on any lesson quiz.',
        unlocked: xp >= 100 || completedLessons.length >= 2,
      ),
      BadgeItem(
        id: 'speed_learner',
        title: 'Speed Learner',
        icon: '⚡',
        description: 'Lightning fast! Unlocked by practicing vocabulary with high speed.',
        unlockCriteria: 'Complete a vocabulary lesson in under 2 minutes.',
        unlocked: xp >= 250 || completedLessons.length >= 3,
      ),
      BadgeItem(
        id: 'speaker',
        title: 'Speaker',
        icon: '🗣️',
        description: 'Vocal maestro! Unlocked by recording speech and passing pronunciation checkpoints.',
        unlockCriteria: 'Record voice input and pass 5 pronunciation lessons.',
        unlocked: xp >= 500 || completedLessons.length >= 5,
      ),
      BadgeItem(
        id: 'bookworm',
        title: 'Bookworm',
        icon: '📚',
        description: 'Book lover! Unlocked by expanding your knowledge base extensively.',
        unlockCriteria: 'Complete 8 lessons in your learning path.',
        unlocked: completedLessons.length >= 8,
      ),
      BadgeItem(
        id: 'top_learner',
        title: 'Top Learner',
        icon: '🏆',
        description: 'Peak performance! Unlocked by climbing to the absolute top.',
        unlockCriteria: 'Earn 1,000 XP in total.',
        unlocked: xp >= 1000,
      ),
      BadgeItem(
        id: 'graduate',
        title: 'Graduate',
        icon: '🎓',
        description: 'Milestone achieved! Unlocked by finishing the overall course material.',
        unlockCriteria: 'Complete 12 lessons or reach Level 6.',
        unlocked: completedLessons.length >= 12 || level >= 6,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _getBadges();
    final unlockedCount = badges.where((b) => b.unlocked).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text(
          'Badges & Achievements',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Card with progress summary
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                          // Badge Icon
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: badge.unlocked
                                  ? const Color(0xFFFFF9C4).withOpacity(0.5)
                                  : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                              border: badge.unlocked
                                  ? Border.all(color: const Color(0xFFFFD54F), width: 1.5)
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
                          // Badge Title
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
                          // Badge Status Label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    // Pull Bar
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCFD8DC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Big Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: badge.unlocked
                            ? const Color(0xFFFFF9C4)
                            : const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                        border: badge.unlocked
                            ? Border.all(color: const Color(0xFFFFD54F), width: 2.5)
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
                    // Title
                    Text(
                      badge.title,
                      style: const TextStyle(
                        color: Color(0xFF263238),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    // Description
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
                    // Unlock Criteria Box
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
                    // Dismiss Button with Premium Gradient
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
