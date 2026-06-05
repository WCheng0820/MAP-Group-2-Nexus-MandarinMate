import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
    as mandarinmate_edit_profile;
import 'package:mandarinmate/screens/profile/badges_achievements_page.dart';
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_levels_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/lesson_detail_page.dart';
import 'package:mandarinmate/screens/daily_challenge_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/vocab_lesson_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/active_lesson_screen.dart'
    as new_lessons;
import 'package:mandarinmate/lessons/data/mock_lessons.dart';
import 'package:mandarinmate/lessons/presentation/bloc/active_lesson_bloc.dart'
    as new_bloc;
import 'package:mandarinmate/lessons/domain/active_lesson_model.dart';
import 'dart:math' as math;
import 'package:mandarinmate/models/badge_config_model.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(onOpenLearn: () => setState(() => _currentIndex = 1)),
      const _LearnTab(),
      const _ChatTab(),
      const _ForumTab(),
      _ProfileTab(onOpenLearn: () => setState(() => _currentIndex = 1)),
    ];

    return Scaffold(
      backgroundColor: _StudentColors.paper,
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: _StudentColors.orange.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded, color: _StudentColors.red),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_rounded),
            selectedIcon: Icon(
              Icons.menu_book_rounded,
              color: _StudentColors.red,
            ),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            selectedIcon: Icon(
              Icons.chat_bubble_rounded,
              color: _StudentColors.red,
            ),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_rounded),
            selectedIcon: Icon(Icons.forum_rounded, color: _StudentColors.red),
            label: 'Forum',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _StudentColors.red),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback onOpenLearn;
  const _HomeTab({required this.onOpenLearn});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<CourseUnit>? _cachedDynamicUnits;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return _StudentPageFrame(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
        builder: (context, userSnapshot) {
          final data = userSnapshot.data?.data() ?? <String, dynamic>{};
          final name = _displayName(data);
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );
          final level = (xp ~/ 250) + 1;
          final starredItems = (data['starredItems'] as List?) ?? [];
          final streak = _toInt(
            data['streak'],
            fallback: _toInt(data['currentStreak'], fallback: 0),
          );
          final completedLessons = (data['completedLessons'] as List?) ?? [];
          final dailyActivity =
              (data['dailyActivity'] as Map<String, dynamic>?) ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('lessons')
                .orderBy('order')
                .snapshots(),
            builder: (context, lessonsSnapshot) {
              List<QueryDocumentSnapshot<Map<String, dynamic>>> vocabDocRefs =
                  [];
              if (lessonsSnapshot.hasData) {
                vocabDocRefs = lessonsSnapshot.data!.docs.where((doc) {
                  final type = doc.data()['type'] as String?;
                  final materialsList = doc.data()['materials'] as List?;
                  final isMaterial =
                      type == 'material' ||
                      (type != 'vocab_unit' &&
                          materialsList != null &&
                          materialsList.isNotEmpty);
                  return !isMaterial; // Only dynamic vocab units
                }).toList();
              }

              return FutureBuilder<List<CourseUnit>>(
                future: _fetchDynamicUnits(vocabDocRefs),
                builder: (context, futureSnapshot) {
                  final dynamicUnits =
                      futureSnapshot.data ?? _cachedDynamicUnits ?? [];
                  if (futureSnapshot.hasData) {
                    _cachedDynamicUnits = dynamicUnits;
                  }

                  final allUnits = [...mockCourseUnits, ...dynamicUnits];

                  final totalLessons = allUnits.fold<int>(
                    0,
                    (total, unit) => total + unit.lessons.length,
                  );
                  final completedCount = completedLessons
                      .where((id) => !id.toString().startsWith('daily_challenge_'))
                      .length;
                  final courseProgress = totalLessons > 0
                      ? completedCount / totalLessons
                      : 0.0;

                  // Find the next incomplete lesson
                  Lesson? nextLesson;
                  for (var unit in allUnits) {
                    for (var lesson in unit.lessons) {
                      if (!completedLessons.contains(lesson.id)) {
                        nextLesson = lesson;
                        break;
                      }
                    }
                    if (nextLesson != null) break;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StudentHeader(name: name, streak: streak),
                        const SizedBox(height: 14),
                        _ProgressHero(
                          title: 'Learning Dashboard',
                          headline: 'Level $level Mandarin',
                          subtitle:
                              '${(courseProgress * 100).round()}% Course Completed',
                          xp: xp,
                          progress: courseProgress,
                          actionLabel: nextLesson != null
                              ? 'Continue Lesson'
                              : 'Course Completed',
                          onAction: nextLesson != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (_) => new_bloc.LessonBloc()
                                          ..add(
                                            new_bloc.StartLesson(nextLesson!),
                                          ),
                                        child: new_lessons.LessonScreen(
                                          lesson: nextLesson!,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              : widget.onOpenLearn,
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.18,
                          children: [
                            _StudentActionTile(
                              icon: Icons.menu_book_rounded,
                              title: 'Mandarin Lessons',
                              subtitle: 'Vocab, quiz, listening',
                              color: _StudentColors.red,
                              onTap: widget.onOpenLearn,
                            ),
                            _StudentActionTile(
                              icon: Icons.style_rounded,
                              title: 'Flashcards',
                              subtitle: 'Revision tools',
                              color: _StudentColors.orange,
                              onTap: () => _LearnTab.openFlashcards(context),
                            ),
                            _StudentActionTile(
                              icon: Icons.local_fire_department_rounded,
                              title: 'Daily Challenge',
                              subtitle: 'Earn bonus XP',
                              color: const Color(0xFF16A34A),
                              onTap: () =>
                                  _LearnTab.openDailyChallenge(context),
                            ),
                            _StudentActionTile(
                              icon: Icons.graphic_eq_rounded,
                              title: 'Pronunciation',
                              subtitle: 'Audio practice',
                              color: const Color(0xFF2F80ED),
                              onTap: () => _LearnTab.openPronunciation(context),
                            ),
                          ],
                        ),
                        // ==========================================
                        // ADD STEP 2 HERE: THE WEEKLY CHART
                        // ==========================================
                        const SizedBox(height: 20),
                        _WeeklyProgressChart(dailyActivity: dailyActivity),
                        // ==========================================
                        if (starredItems.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Starred Vocab & Phrases',
                            onViewAll: () {},
                          ),
                          const SizedBox(height: 10),
                          _StarredItemsRow(starredItems: starredItems),
                        ],
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: 'Continue Lessons',
                          onViewAll: widget.onOpenLearn,
                        ),
                        const SizedBox(height: 10),
                        _HomeContinueLessonCard(
                          completedLessons: completedLessons,
                          allUnits: allUnits,
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: 'Recent Badges',
                          onViewAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BadgesAchievementsPage(
                                  xp: xp,
                                  streak: streak,
                                  completedLessons: completedLessons,
                                  level: level,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _RecentBadgesRow(
                          xp: xp,
                          streak: streak,
                          completedLessons: completedLessons,
                          level: level,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeContinueLessonCard extends StatelessWidget {
  const _HomeContinueLessonCard({
    required this.completedLessons,
    required this.allUnits,
  });

  final List<dynamic> completedLessons;
  final List<CourseUnit> allUnits;

  @override
  Widget build(BuildContext context) {
    Lesson? nextLesson;
    CourseUnit? targetUnit;

    for (var unit in allUnits) {
      for (var lesson in unit.lessons) {
        if (!completedLessons.contains(lesson.id)) {
          nextLesson = lesson;
          targetUnit = unit;
          break;
        }
      }
      if (nextLesson != null) break;
    }

    if (nextLesson == null) {
      return const _EmptyState(text: 'You have completed all lessons! 🎉');
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (_) =>
                  new_bloc.LessonBloc()..add(new_bloc.StartLesson(nextLesson!)),
              child: new_lessons.LessonScreen(lesson: nextLesson!),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE4CF)),
          boxShadow: [
            BoxShadow(
              color: _StudentColors.orange.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    targetUnit?.color.withValues(alpha: 0.1) ??
                    _StudentColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: targetUnit?.color ?? _StudentColors.red,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextLesson.title,
                    style: const TextStyle(
                      color: _StudentColors.deep,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    targetUnit?.title ?? '',
                    style: const TextStyle(
                      color: _StudentColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _StudentColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarredItemsRow extends StatelessWidget {
  final List<dynamic> starredItems;
  const _StarredItemsRow({required this.starredItems});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: starredItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final rawItem = starredItems[index];
          final item = rawItem is Map ? rawItem : <String, dynamic>{};
          final title = (item['title'] ?? '').toString();
          final type = (item['type'] ?? 'Vocab').toString();

          final colors = [
            _StudentColors.orange,
            _StudentColors.red,
            const Color(0xFF2F80ED),
            const Color(0xFF16A34A),
          ];
          final color = colors[index % colors.length];

          return Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  type,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecentBadgesRow extends StatelessWidget {
  final int xp;
  final int streak;
  final List<dynamic> completedLessons;
  final int level;

  const _RecentBadgesRow({
    required this.xp,
    required this.streak,
    required this.completedLessons,
    required this.level,
  });

  List<Map<String, dynamic>> _getBadges() {
    final list = <Map<String, dynamic>>[];
    if (streak >= 7) {
      list.add({'title': '7 Day Streak', 'icon': '🔥', 'unlocked': true});
    }
    if (completedLessons.isNotEmpty || xp >= 30) {
      list.add({'title': 'First Lesson', 'icon': '⭐', 'unlocked': true});
    }
    if (xp >= 100 || completedLessons.length >= 2) {
      list.add({'title': 'Perfect Score', 'icon': '🎯', 'unlocked': true});
    }
    if (xp >= 250 || completedLessons.length >= 3) {
      list.add({'title': 'Speed Learner', 'icon': '⚡', 'unlocked': true});
    }
    if (xp >= 500 || completedLessons.length >= 5) {
      list.add({'title': 'Speaker', 'icon': '🗣️', 'unlocked': true});
    }
    if (completedLessons.length >= 8) {
      list.add({'title': 'Bookworm', 'icon': '📚', 'unlocked': true});
    }
    if (xp >= 1000) {
      list.add({'title': 'Top Learner', 'icon': '🏆', 'unlocked': true});
    }
    if (completedLessons.length >= 12 || level >= 6) {
      list.add({'title': 'Graduate', 'icon': '🎓', 'unlocked': true});
    }

    if (list.isEmpty) {
      list.addAll([
        {'title': '7 Day Streak', 'icon': '🔥', 'unlocked': false},
        {'title': 'First Lesson', 'icon': '⭐', 'unlocked': false},
        {'title': 'Perfect Score', 'icon': '🎯', 'unlocked': false},
      ]);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final badges = _getBadges();

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final badge = badges[index];
          final bool unlocked = badge['unlocked'] as bool;

          return Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unlocked
                    ? const Color(0xFFFFD54F).withOpacity(0.4)
                    : const Color(0xFFECEFF1),
                width: unlocked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: unlocked
                      ? Colors.amber.withOpacity(0.04)
                      : Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: unlocked ? 1.0 : 0.25,
                  child: Text(
                    badge['icon'] as String,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badge['title'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked
                        ? const Color(0xFF263238)
                        : const Color(0xFFB0BEC5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LearnTab extends StatelessWidget {
  const _LearnTab();

  static Future<void> openFlashcards(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FlashcardLevelsPage()),
    );
  }

  static Future<void> openPronunciation(BuildContext context) async {
    final unitAndVocab = await _firstUnitAndVocab();

    if (unitAndVocab != null) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VocabLessonPage(
            unit: unitAndVocab.unit,
            vocabItems: unitAndVocab.vocab,
            focusAudio: true,
          ),
        ),
      );
    } else {
      // Fallback to mock data from Unit 1
      if (mockCourseUnits.isNotEmpty &&
          mockCourseUnits.first.lessons.isNotEmpty) {
        final firstLesson = mockCourseUnits.first.lessons.first;
        final vocabItems = firstLesson.items
            .where((i) => i.type == LessonType.vocabulary)
            .map(
              (i) => VocabItem(
                chinese: i.chinese,
                pinyin: i.pinyin,
                english: i.english,
                malay: i.english, // Fallback
              ),
            )
            .toList();

        if (!context.mounted) return;
        final mockUnit = LessonUnit(
          id: 'mock_u1',
          unitNumber: 1,
          title: mockCourseUnits.first.title,
          titleChinese: '',
          description: mockCourseUnits.first.subtitle,
          totalLessons: mockCourseUnits.first.lessons.length,
          xpReward: 30,
          order: 1,
          materials: const [],
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VocabLessonPage(
              unit: mockUnit,
              vocabItems: vocabItems,
              focusAudio: true,
            ),
          ),
        );
      }
    }
  }

  static Future<void> openDailyChallenge(BuildContext context) async {
    // 1. Get current user's completed lessons from Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    List<dynamic> completedLessons = [];
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      completedLessons = userDoc.data()?['completedLessons'] as List? ?? [];
    }

    // 2. Fetch vocab units from Firestore (just like in _fetchDynamicUnits)
    final lessonsSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .orderBy('order')
        .get();

    final vocabDocRefs = lessonsSnapshot.docs.where((doc) {
      final type = doc.data()['type'] as String?;
      final materialsList = doc.data()['materials'] as List?;
      final isMaterial =
          type == 'material' ||
          (type != 'vocab_unit' &&
              materialsList != null &&
              materialsList.isNotEmpty);
      return !isMaterial; // Only dynamic vocab units
    }).toList();

    // 3. Compile CourseUnits
    final dynamicUnits = await _fetchDynamicUnits(vocabDocRefs);
    final allUnits = [...mockCourseUnits, ...dynamicUnits];

    // 4. Open the DailyChallengePage!
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengePage(
          completedLessons: completedLessons,
          allUnits: allUnits,
        ),
      ),
    );
  }

  static Future<void> openUnitDetail(
    BuildContext context,
    LessonUnit unit,
    bool isCompleted,
  ) async {
    final vocabSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(unit.id)
        .collection('vocabulary')
        .get();

    final vocab = vocabSnapshot.docs
        .map((doc) => VocabItem.fromMap(doc.data()))
        .toList();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailPage(
          unit: unit,
          vocabItems: vocab,
          isCompleted: isCompleted,
        ),
      ),
    );
  }

  static Future<_UnitAndVocab?> _firstUnitAndVocab() async {
    final unitsSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .orderBy('order')
        .limit(1)
        .get();

    if (unitsSnapshot.docs.isEmpty) return null;

    final unitDoc = unitsSnapshot.docs.first;
    final unit = LessonUnit.fromFirestore(unitDoc.data(), unitDoc.id);
    final vocabSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(unitDoc.id)
        .collection('vocabulary')
        .get();

    final vocab = vocabSnapshot.docs
        .map((doc) => VocabItem.fromMap(doc.data()))
        .toList();

    return _UnitAndVocab(unit: unit, vocab: vocab);
  }

  Future<void> _openLeaderboard(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _LeaderboardSheet(currentUid: uid),
    );
  }

  Future<void> _openProgress(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ProgressSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return _StudentPageFrame(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
        builder: (context, userSnapshot) {
          final data = userSnapshot.data?.data() ?? <String, dynamic>{};
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );
          final level = (xp ~/ 250) + 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressHero(
                  title: 'Overall Progress',
                  headline: 'Level $level',
                  xp: xp,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.18,
                  children: [
                    _StudentActionTile(
                      icon: Icons.style_rounded,
                      title: 'Flashcards',
                      subtitle: 'Fast revision',
                      color: _StudentColors.red,
                      onTap: () => openFlashcards(context),
                    ),
                    _StudentActionTile(
                      icon: Icons.flag_rounded,
                      title: 'Daily Challenge',
                      subtitle: 'Quiz + XP',
                      color: _StudentColors.orange,
                      onTap: () => openDailyChallenge(context),
                    ),
                    _StudentActionTile(
                      icon: Icons.insights_rounded,
                      title: 'Progress',
                      subtitle: 'Level and XP',
                      color: const Color(0xFF16A34A),
                      onTap: () => _openProgress(context),
                    ),
                    _StudentActionTile(
                      icon: Icons.emoji_events_rounded,
                      title: 'Leaderboard',
                      subtitle: 'Top students',
                      color: const Color(0xFF2F80ED),
                      onTap: () => _openLeaderboard(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _CoursePathView(
                  completedLessons: data['completedLessons'] ?? [],
                ),
                _LessonsList(
                  onOpenUnit: openUnitDetail,
                  completedLessons: List<String>.from(
                    data['completedLessons'] ?? [],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LessonsList extends StatelessWidget {
  const _LessonsList({
    required this.onOpenUnit,
    required this.completedLessons,
  });

  final Future<void> Function(
    BuildContext context,
    LessonUnit unit,
    bool isCompleted,
  )
  onOpenUnit;
  final List<String> completedLessons;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyState(text: 'No lessons available yet.');
        }

        // Separate units into regular learning path and community materials
        final regularUnits = <LessonUnit>[];
        final communityUnits = <LessonUnit>[];

        for (final doc in docs) {
          final data = doc.data();
          final type = data['type'] as String?;
          final materialsList = data['materials'] as List?;

          final isMaterial =
              type == 'material' ||
              (type != 'vocab_unit' &&
                  materialsList != null &&
                  materialsList.isNotEmpty);

          if (isMaterial) {
            communityUnits.add(LessonUnit.fromFirestore(data, doc.id));
          } else {
            // Include both system and vocab_unit as regular path
            regularUnits.add(LessonUnit.fromFirestore(data, doc.id));
          }
        }

        final sections = <Widget>[];

        // Remove the heading completely for standard units
        if (communityUnits.isNotEmpty) {
          sections.add(
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 12),
              child: Text(
                'Community Lessons',
                style: TextStyle(
                  color: Color(0xFF1a1a1a),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          for (final unit in communityUnits) {
            final isCompleted = completedLessons.contains(unit.id);
            sections.add(
              _LessonCard(
                unit: unit,
                onTap: onOpenUnit,
                isCompleted: isCompleted,
              ),
            );
          }
        }

        return Column(children: sections);
      },
    );
  }
}

class _StudentPageFrame extends StatelessWidget {
  const _StudentPageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_StudentColors.paper, Color(0xFFFFEFE4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.name, required this.streak});

  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你好, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _StudentColors.deep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Ready for Mandarin practice?',
                style: TextStyle(
                  color: _StudentColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFDFC2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: _StudentColors.orange,
                size: 19,
              ),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  color: _StudentColors.deep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({
    required this.title,
    required this.headline,
    this.subtitle,
    required this.xp,
    this.progress,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String headline;
  final String? subtitle;
  final int xp;
  final double? progress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_StudentColors.red, _StudentColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30E93A2F),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFF4EA),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _HeroBadge(label: '$xp XP'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.28),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
          if (subtitle != null ||
              (actionLabel != null && onAction != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFFFFF4EA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (actionLabel != null && onAction != null)
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _StudentColors.red,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StudentActionTile extends StatelessWidget {
  const _StudentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE4CF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D111827),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _StudentColors.deep,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _StudentColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _StudentColors.deep,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.unit,
    required this.onTap,
    required this.isCompleted,
  });

  final LessonUnit unit;
  final Future<void> Function(
    BuildContext context,
    LessonUnit unit,
    bool isCompleted,
  )
  onTap;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(context, unit, isCompleted),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFE4CF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _StudentColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      unit.unitNumber.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: _StudentColors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit ${unit.unitNumber}: ${unit.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _StudentColors.deep,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        unit.titleChinese.isEmpty
                            ? unit.description
                            : unit.titleChinese,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _StudentColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2E7D32),
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _StudentColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${unit.xpReward} XP',
                      style: const TextStyle(
                        color: _StudentColors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardSheet extends StatelessWidget {
  const _LeaderboardSheet({this.currentUid});

  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyState(text: 'No leaderboard data yet.');
        }

        final entries = _leaderboardEntriesFromDocs(docs);
        final currentIndex = entries.indexWhere(
          (entry) => entry.uid == currentUid,
        );
        final currentEntry = currentIndex >= 0 ? entries[currentIndex] : null;
        final nextEntry = currentIndex > 0 ? entries[currentIndex - 1] : null;
        final topEntries = entries.take(10).toList();
        final displayEntries = <_LeaderboardEntry>[
          ...topEntries,
          if (currentEntry != null &&
              !topEntries.any((entry) => entry.uid == currentEntry.uid))
            currentEntry,
        ];

        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Leaderboard Ranking',
                      style: TextStyle(
                        color: _StudentColors.deep,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (currentEntry != null) ...[
                _MyRankHero(entry: currentEntry, nextEntry: nextEntry),
                const SizedBox(height: 16),
              ],
              const Text(
                'Top Students',
                style: TextStyle(
                  color: _StudentColors.deep,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...displayEntries.map(
                (entry) => _LeaderboardRankTile(
                  entry: entry,
                  isCurrentUser: entry.uid == currentUid,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.uid,
    required this.rank,
    required this.name,
    required this.xp,
    required this.level,
    required this.badges,
    required this.completedLessons,
  });

  final String uid;
  final int rank;
  final String name;
  final int xp;
  final int level;
  final int badges;
  final int completedLessons;
}

List<_LeaderboardEntry> _leaderboardEntriesFromDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final sortedDocs = [...docs]
    ..sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aXp = _toInt(
        aData['xp'],
        fallback: _toInt(aData['xpPoints'], fallback: 0),
      );
      final bXp = _toInt(
        bData['xp'],
        fallback: _toInt(bData['xpPoints'], fallback: 0),
      );
      return bXp.compareTo(aXp);
    });

  return sortedDocs.asMap().entries.map((entry) {
    final data = entry.value.data();
    final xp = _toInt(
      data['xp'],
      fallback: _toInt(data['xpPoints'], fallback: 0),
    );
    final level = (xp ~/ 250) + 1;
    final streak = _toInt(
      data['streak'],
      fallback: _toInt(data['currentStreak'], fallback: 0),
    );
    final completedLessonsRaw = (data['completedLessons'] as List?) ?? [];
    final curriculumLessons = completedLessonsRaw
        .where((id) => !id.toString().startsWith('daily_challenge_'))
        .toList();

    return _LeaderboardEntry(
      uid: entry.value.id,
      rank: entry.key + 1,
      name: _displayName(data),
      xp: xp,
      level: level,
      badges: _unlockedBadgesCount(xp, streak, curriculumLessons, level),
      completedLessons: curriculumLessons.length,
    );
  }).toList();
}

class _MyRankHero extends StatelessWidget {
  const _MyRankHero({required this.entry, this.nextEntry});

  final _LeaderboardEntry entry;
  final _LeaderboardEntry? nextEntry;

  @override
  Widget build(BuildContext context) {
    final xpToNext = nextEntry == null
        ? 0
        : (nextEntry!.xp - entry.xp + 1).clamp(0, 999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_StudentColors.red, _StudentColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30E93A2F),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Ranking',
            style: TextStyle(
              color: Color(0xFFFFF4EA),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${entry.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _HeroBadge(label: '${entry.xp} XP'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nextEntry == null
                ? 'You are leading the leaderboard.'
                : '$xpToNext XP to pass #${nextEntry!.rank} ${nextEntry!.name}',
            style: const TextStyle(
              color: Color(0xFFFFF4EA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RankHeroMetric(
                  value: 'Lv.${entry.level}',
                  label: 'Level',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RankHeroMetric(
                  value: '${entry.badges}',
                  label: 'Badges',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RankHeroMetric(
                  value: '${entry.completedLessons}',
                  label: 'Lessons',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankHeroMetric extends StatelessWidget {
  const _RankHeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF4EA),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRankTile extends StatelessWidget {
  const _LeaderboardRankTile({
    required this.entry,
    required this.isCurrentUser,
  });

  final _LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (entry.rank) {
      1 => const Color(0xFFFFB300),
      2 => const Color(0xFF90A4AE),
      3 => const Color(0xFFB87333),
      _ => _StudentColors.orange,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? _StudentColors.orange.withValues(alpha: 0.5)
              : const Color(0xFFFFE4CF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(color: rankColor, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${entry.name} (You)' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _StudentColors.deep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${entry.level} · ${entry.badges} badges · ${entry.completedLessons} lessons',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _StudentColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.xp} XP',
            style: const TextStyle(
              color: _StudentColors.deep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSummaryCard extends StatelessWidget {
  const _LeaderboardSummaryCard({
    required this.currentUid,
    required this.xp,
    required this.level,
    required this.badgesCount,
    required this.levelProgress,
    required this.onOpenLeaderboard,
  });

  final String? currentUid;
  final int xp;
  final int level;
  final int badgesCount;
  final double levelProgress;
  final VoidCallback onOpenLeaderboard;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        final entries = snapshot.hasData
            ? _leaderboardEntriesFromDocs(snapshot.data!.docs)
            : const <_LeaderboardEntry>[];
        final rankIndex = entries.indexWhere(
          (entry) => entry.uid == currentUid,
        );
        final rankText = rankIndex >= 0 ? '#${rankIndex + 1}' : '--';
        final totalStudents = entries.length;
        final nextEntry = rankIndex > 0 ? entries[rankIndex - 1] : null;
        final xpMessage = nextEntry == null
            ? 'You are leading your class.'
            : '${(nextEntry.xp - xp + 1).clamp(0, 999999)} XP to pass #${nextEntry.rank}.';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFE4CF)),
            boxShadow: [
              BoxShadow(
                color: _StudentColors.orange.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: _StudentColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leaderboard Ranking',
                          style: TextStyle(
                            color: Color(0xFF263238),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          totalStudents == 0
                              ? 'Rank will appear after students earn XP.'
                              : 'Ranked $rankText of $totalStudents students',
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenLeaderboard,
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: _StudentColors.orange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CompactMetric(
                      label: 'Rank',
                      value: rankText,
                      color: _StudentColors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetric(
                      label: 'XP',
                      value: '$xp',
                      color: _StudentColors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Badges',
                      value: '$badgesCount',
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level $level progress',
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(levelProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFECEFF1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _StudentColors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Loading class ranking...'
                    : xpMessage,
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSheet extends StatelessWidget {
  const _ProgressSheet({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final xp = _toInt(
          data['xp'],
          fallback: _toInt(data['xpPoints'], fallback: 0),
        );
        final level = (xp ~/ 250) + 1;
        final completedLessons = (data['completedLessons'] as List?) ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('lessons')
              .orderBy('order')
              .snapshots(),
          builder: (context, lessonsSnapshot) {
            List<QueryDocumentSnapshot<Map<String, dynamic>>> vocabDocRefs = [];
            if (lessonsSnapshot.hasData) {
              vocabDocRefs = lessonsSnapshot.data!.docs.where((doc) {
                final type = doc.data()['type'] as String?;
                final materialsList = doc.data()['materials'] as List?;
                final isMaterial =
                    type == 'material' ||
                    (type != 'vocab_unit' &&
                        materialsList != null &&
                        materialsList.isNotEmpty);
                return !isMaterial; // Only dynamic vocab units
              }).toList();
            }

            return FutureBuilder<List<CourseUnit>>(
              future: _fetchDynamicUnits(vocabDocRefs),
              builder: (context, futureSnapshot) {
                final dynamicUnits = futureSnapshot.data ?? [];
                final allUnits = [...mockCourseUnits, ...dynamicUnits];

                final totalLessons = allUnits.fold<int>(
                  0,
                  (total, unit) => total + unit.lessons.length,
                );
                final courseProgress = totalLessons > 0
                    ? completedLessons
                        .where((id) => !id.toString().startsWith('daily_challenge_'))
                        .length / totalLessons
                    : 0.0;

                // Find the next incomplete lesson
                Lesson? nextLesson;
                for (var unit in allUnits) {
                  for (var lesson in unit.lessons) {
                    if (!completedLessons.contains(lesson.id)) {
                      nextLesson = lesson;
                      break;
                    }
                  }
                  if (nextLesson != null) break;
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Learning Progress',
                        style: TextStyle(
                          color: _StudentColors.deep,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProgressHero(
                        title: 'Current Level',
                        headline: 'Level $level',
                        subtitle:
                            '${(courseProgress * 100).round()}% Course Completed',
                        xp: xp,
                        progress: courseProgress,
                        actionLabel: nextLesson != null
                            ? 'Continue Lesson'
                            : 'Course Completed',
                        onAction: nextLesson != null
                            ? () {
                                Navigator.pop(context); // Close sheet
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BlocProvider(
                                      create: (_) => new_bloc.LessonBloc()
                                        ..add(
                                          new_bloc.StartLesson(nextLesson!),
                                        ),
                                      child: new_lessons.LessonScreen(
                                        lesson: nextLesson!,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(22),
      child: Center(
        child: CircularProgressIndicator(color: _StudentColors.red),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE4CF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _StudentColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnitAndVocab {
  const _UnitAndVocab({required this.unit, required this.vocab});

  final LessonUnit unit;
  final List<VocabItem> vocab;
}

class _ChatTab extends StatelessWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context) {
    return const _CenteredTab(
      icon: Icons.chat_bubble_rounded,
      title: 'Chat',
      subtitle: 'Mandarin conversation practice coming soon.',
    );
  }
}

class _ForumTab extends StatelessWidget {
  const _ForumTab();

  @override
  Widget build(BuildContext context) {
    return const _CenteredTab(
      icon: Icons.forum_rounded,
      title: 'Forum',
      subtitle: 'Ask questions and share learning tips.',
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final VoidCallback onOpenLearn;
  const _ProfileTab({required this.onOpenLearn});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, BadgeConfig>? badgeConfigs;
  List<CourseUnit>? _allUnits;

  @override
  void initState() {
    super.initState();
    _loadBadgeConfigs();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      final lessonsSnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('order')
          .get();

      final vocabDocRefs = lessonsSnapshot.docs.where((doc) {
        final type = doc.data()['type'] as String?;
        final materialsList = doc.data()['materials'] as List?;
        final isMaterial =
            type == 'material' ||
            (type != 'vocab_unit' &&
                materialsList != null &&
                materialsList.isNotEmpty);
        return !isMaterial;
      }).toList();

      final dynamicUnits = await _fetchDynamicUnits(vocabDocRefs);
      if (mounted) {
        setState(() {
          _allUnits = [...mockCourseUnits, ...dynamicUnits];
        });
      }
    } catch (e) {
      print('Error loading units in profile: $e');
    }
  }

  Future<void> _loadBadgeConfigs() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('badges_config')
          .get();

      final configs = <String, BadgeConfig>{};
      for (var doc in querySnapshot.docs) {
        configs[doc.id] = BadgeConfig.fromMap({'id': doc.id, ...doc.data()});
      }

      if (mounted) {
        setState(() {
          badgeConfigs = configs;
        });
      }
    } catch (e) {
      print('Error loading badge configs: $e');
    }
  }

  String _getLevelName(int lvl) {
    if (lvl <= 2) return 'Beginner';
    if (lvl <= 4) return 'Elementary';
    if (lvl <= 6) return 'Learner';
    if (lvl <= 8) return 'Intermediate';
    return 'Advanced';
  }

  int _getUnlockedBadgesCount(
    int xp,
    int streak,
    List<dynamic> completedLessons,
    int level,
  ) {
    // If configs haven't loaded yet, use fallback hardcoded values
    if (badgeConfigs == null) {
      int count = 0;
      if (streak >= 7) count++;
      if (completedLessons.isNotEmpty || xp >= 30) count++;
      if (xp >= 100 || completedLessons.length >= 2) count++;
      if (xp >= 250 || completedLessons.length >= 3) count++;
      if (xp >= 500 || completedLessons.length >= 5) count++;
      if (completedLessons.length >= 8) count++;
      if (xp >= 1000) count++;
      if (completedLessons.length >= 12 || level >= 6) count++;
      return count;
    }

    // Use badge configs from Firestore
    int count = 0;

    // streak_7: requires 7-day streak
    if (badgeConfigs!['streak_7']?.streakThreshold != null &&
        streak >= badgeConfigs!['streak_7']!.streakThreshold!) {
      count++;
    }

    // first_lesson: requires XP or completed lesson
    if (completedLessons.isNotEmpty ||
        (badgeConfigs!['first_lesson']?.xpThreshold != null &&
            xp >= badgeConfigs!['first_lesson']!.xpThreshold!)) {
      count++;
    }

    // perfect_score: requires XP or lesson count
    if (badgeConfigs!['perfect_score'] != null) {
      final config = badgeConfigs!['perfect_score']!;
      if ((config.xpThreshold != null && xp >= config.xpThreshold!) ||
          (config.lessonThreshold != null &&
              completedLessons.length >= config.lessonThreshold!)) {
        count++;
      }
    }

    // speed_learner: requires XP or lesson count
    if (badgeConfigs!['speed_learner'] != null) {
      final config = badgeConfigs!['speed_learner']!;
      if ((config.xpThreshold != null && xp >= config.xpThreshold!) ||
          (config.lessonThreshold != null &&
              completedLessons.length >= config.lessonThreshold!)) {
        count++;
      }
    }

    // speaker: requires XP or lesson count
    if (badgeConfigs!['speaker'] != null) {
      final config = badgeConfigs!['speaker']!;
      if ((config.xpThreshold != null && xp >= config.xpThreshold!) ||
          (config.lessonThreshold != null &&
              completedLessons.length >= config.lessonThreshold!)) {
        count++;
      }
    }

    // bookworm: requires lesson count
    if (badgeConfigs!['bookworm']?.lessonThreshold != null &&
        completedLessons.length >=
            badgeConfigs!['bookworm']!.lessonThreshold!) {
      count++;
    }

    // top_learner: requires XP
    if (badgeConfigs!['top_learner']?.xpThreshold != null &&
        xp >= badgeConfigs!['top_learner']!.xpThreshold!) {
      count++;
    }

    // graduate: requires lesson count or level
    if (badgeConfigs!['graduate'] != null) {
      final config = badgeConfigs!['graduate']!;
      if ((config.lessonThreshold != null &&
              completedLessons.length >= config.lessonThreshold!) ||
          (config.levelThreshold != null && level >= config.levelThreshold!)) {
        count++;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = _displayName(data);
        final email =
            (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
                .toString();
        final xp = _toInt(
          data['xp'],
          fallback: _toInt(data['xpPoints'], fallback: 0),
        );
        final level = (xp ~/ 250) + 1;
        final streak = _toInt(
          data['streak'],
          fallback: _toInt(data['currentStreak'], fallback: 0),
        );
        final completedLessons = (data['completedLessons'] as List?) ?? [];
        final curriculumLessons = completedLessons
            .where((id) => !id.toString().startsWith('daily_challenge_'))
            .toList();

        // Count unlocked badges
        final badgesCount = _getUnlockedBadgesCount(
          xp,
          streak,
          curriculumLessons,
          level,
        );

        // 1. Calculate active daily challenges
        final int dailyChallengesCount = completedLessons
            .where((id) => id.toString().startsWith('daily_challenge_'))
            .length;

        // 2. Calculate dynamic unit quizzes completed
        final int unitQuizzesCount = completedLessons
            .where((id) =>
                id.toString().endsWith('_quiz') ||
                id.toString().endsWith('_quiz_item') ||
                id.toString().contains('rev_quiz'))
            .length;

        // 3. Count standard curriculum lessons completed (excluding daily challenges)
        final int lessonsCompleted = completedLessons
            .where((id) => !id.toString().startsWith('daily_challenge_'))
            .length;

        // 4. Calculate total vocabulary learned (each standard lesson averages 5 new vocabulary words)
        final int vocabularyLearned = lessonsCompleted * 5;

        // 5. Total quizzes taken is the sum of daily challenges and unit quizzes
        final int quizzesTaken = dailyChallengesCount + unitQuizzesCount;

        // 6. Study days corresponds directly to unique daily activity entries, falling back to streak
        final int activeDays = (data['dailyActivity'] as Map?)?.length ?? 0;
        final int studyDays = activeDays > 0 ? activeDays : (streak > 0 ? streak : 1);

        final int nextLevelXp = level * 250;
        final int currentLevelStart = (level - 1) * 250;
        final double levelProgressPercent = ((xp - currentLevelStart) / 250)
            .clamp(0.0, 1.0);
        final xpNeeded = nextLevelXp - xp;

        final double statusBarHeight = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Red Header Section
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    statusBarHeight + 16,
                    20,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_StudentColors.red, _StudentColors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Row: Title & Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const mandarinmate_edit_profile.EditProfilePage(
                                            roleColor: _StudentColors.orange,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () async {
                                  context.read<AuthBloc>().add(AuthLogoutRequested());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Logged out successfully'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // User Avatar & Edit Button
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: const Color(
                              0xFFFFD54F,
                            ), // Premium Yellow
                            child: Text(
                              name.isEmpty ? 'S' : name[0].toUpperCase(),
                              style: const TextStyle(
                                color: _StudentColors.orange, // Gradient Red
                                fontWeight: FontWeight.w900,
                                fontSize: 36,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const mandarinmate_edit_profile.EditProfilePage(
                                          roleColor: _StudentColors.orange,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: _StudentColors.orange,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Display Name
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Role Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Mandarin Club',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Horizontal stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStatCard(
                              icon: '🔥',
                              value: '$streak',
                              label: 'Streak',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderStatCard(
                              icon: '⚡',
                              value: '$xp',
                              label: 'XP',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderStatCard(
                              icon: '⭐',
                              value: 'Lv.$level',
                              label: 'Level',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BadgesAchievementsPage(
                                      xp: xp,
                                      streak: streak,
                                      completedLessons: curriculumLessons,
                                      level: level,
                                    ),
                                  ),
                                );
                              },
                              child: _buildHeaderStatCard(
                                icon: '🏆',
                                value: '$badgesCount',
                                label: 'Badges',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Body Scrollable Cards
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    children: [
                      _LeaderboardSummaryCard(
                        currentUid: uid,
                        xp: xp,
                        level: level,
                        badgesCount: badgesCount,
                        levelProgress: levelProgressPercent,
                        onOpenLeaderboard: () {
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (context) =>
                                _LeaderboardSheet(currentUid: uid),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Card 1: Current Level Progress
                      _buildProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Current Level',
                                        style: TextStyle(
                                          color: Color(0xFF90A4AE),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Level $level · ${_getLevelName(level)}',
                                        style: const TextStyle(
                                          color: Color(0xFF263238),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _showLevelMilestonesDialog(
                                    context,
                                    level,
                                    xp,
                                  ),
                                  child: const Text(
                                    'View all',
                                    style: TextStyle(
                                      color: _StudentColors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: levelProgressPercent,
                                backgroundColor: const Color(0xFFECEFF1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _StudentColors.orange,
                                ),
                                minHeight: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    xpNeeded > 0
                                        ? '$xpNeeded XP needed to reach Level ${level + 1} · ${_getLevelName(level + 1)}'
                                        : 'Max level progress reached! 🎉',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF78909C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$xp/$nextLevelXp XP',
                                  style: const TextStyle(
                                    color: Color(0xFF546E7A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Badges Preview Card
                      _buildProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Badges',
                                  style: TextStyle(
                                    color: Color(0xFF263238),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BadgesAchievementsPage(
                                          xp: xp,
                                          streak: streak,
                                          completedLessons: curriculumLessons,
                                          level: level,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'All badges',
                                    style: TextStyle(
                                      color: _StudentColors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Display first 4 badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildBadgePreviewIcon(
                                  '🔥',
                                  '7-Day Streak',
                                  streak >= 7,
                                ),
                                _buildBadgePreviewIcon(
                                  '⭐',
                                  'First Lesson',
                                  completedLessons.isNotEmpty || xp >= 30,
                                ),
                                _buildBadgePreviewIcon(
                                  '🎯',
                                  'Perfect Score',
                                  xp >= 100 || completedLessons.length >= 2,
                                ),
                                _buildBadgePreviewIcon(
                                  '⚡',
                                  'Speed Learner',
                                  xp >= 250 || completedLessons.length >= 3,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 3: Learning Stats Card
                      _buildProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Learning Stats',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.45,
                              children: [
                                _buildStatCardItem(
                                  icon: '📚',
                                  value: '$lessonsCompleted',
                                  label: 'Lessons Completed',
                                  bgColor: const Color(0xFFE3F2FD),
                                  iconColor: Colors.blue,
                                ),
                                _buildStatCardItem(
                                  icon: '📝',
                                  value: '$vocabularyLearned',
                                  label: 'Vocabulary Learned',
                                  bgColor: const Color(0xFFE8F5E9),
                                  iconColor: Colors.green,
                                ),
                                _buildStatCardItem(
                                  icon: '✏️',
                                  value: '$quizzesTaken',
                                  label: 'Quizzes Taken',
                                  bgColor: const Color(0xFFFFF3E0),
                                  iconColor: Colors.orange,
                                ),
                                _buildStatCardItem(
                                  icon: '📅',
                                  value: '$studyDays',
                                  label: 'Study Days',
                                  bgColor: const Color(0xFFF3E5F5),
                                  iconColor: Colors.purple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 4: Recent Activity
                      _buildProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Activity',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...() {
                              final List<Widget> recentTiles = [];
                              final recentIds = completedLessons.reversed.take(4).toList();

                              String getLessonTitle(String id) {
                                if (_allUnits != null) {
                                  for (var unit in _allUnits!) {
                                    for (var lesson in unit.lessons) {
                                      if (lesson.id == id) {
                                        return lesson.title;
                                      }
                                    }
                                  }
                                }
                                if (id.startsWith('u1_l')) {
                                  int idx = int.tryParse(id.substring(4)) ?? 1;
                                  if (idx == 1) return 'Hello - 你好';
                                  if (idx == 2) return 'Thank You - 谢谢';
                                  if (idx == 3) return 'Greetings - 早上好';
                                }
                                return 'Lesson Progress';
                              }

                              if (recentIds.isEmpty) {
                                recentTiles.add(
                                  GestureDetector(
                                    onTap: widget.onOpenLearn,
                                    child: _buildRecentActivityItem(
                                      icon: '👋',
                                      title: 'Welcome to MandarinMate! Tap to start your first lesson.',
                                      time: 'Just now',
                                      xp: 'Start',
                                      bgColor: const Color(0xFFE8F5E9),
                                    ),
                                  ),
                                );
                              } else {
                                for (var id in recentIds) {
                                  final idStr = id.toString();
                                  if (idStr.startsWith('daily_challenge_')) {
                                    final dateStr = idStr.replaceFirst('daily_challenge_', '');
                                    recentTiles.add(
                                      _buildRecentActivityItem(
                                        icon: '🎯',
                                        title: 'Completed Daily Challenge',
                                        time: dateStr,
                                        xp: '+50 XP',
                                        bgColor: const Color(0xFFFFEBEE),
                                      ),
                                    );
                                  } else if (idStr.endsWith('_quiz') ||
                                      idStr.endsWith('_quiz_item') ||
                                      idStr.contains('rev_quiz')) {
                                    recentTiles.add(
                                      _buildRecentActivityItem(
                                        icon: '📝',
                                        title: 'Passed Unit Quiz',
                                        time: 'Completed',
                                        xp: '+100 XP',
                                        bgColor: const Color(0xFFFFF3E0),
                                      ),
                                    );
                                  } else {
                                    recentTiles.add(
                                      _buildRecentActivityItem(
                                        icon: '📚',
                                        title: 'Completed: ${getLessonTitle(idStr)}',
                                        time: 'Completed',
                                        xp: '+30 XP',
                                        bgColor: const Color(0xFFE3F2FD),
                                      ),
                                    );
                                  }
                                }
                              }
                              return recentTiles;
                            }(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 5: Bottom Navigation Links
                      _buildProfileCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildNavigationRow(
                              icon: Icons.menu_book_rounded,
                              iconBg: const Color(0xFFFFF3E0),
                              iconColor: _StudentColors.orange,
                              title: 'My Learning Path',
                              onTap: widget.onOpenLearn,
                            ),
                            const Divider(height: 1, color: Color(0xFFECEFF1)),
                            _buildNavigationRow(
                              icon: Icons.emoji_events_rounded,
                              iconBg: const Color(0xFFFFF9C4),
                              iconColor: Colors.amber.shade800,
                              title: 'Leaderboard',
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) =>
                                      _LeaderboardSheet(currentUid: uid),
                                );
                              },
                            ),
                            const Divider(height: 1, color: Color(0xFFECEFF1)),
                            _buildNavigationRow(
                              icon: Icons.settings_rounded,
                              iconBg: const Color(0xFFECEFF1),
                              iconColor: const Color(0xFF546E7A),
                              title: 'Settings & Profile Edit',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const mandarinmate_edit_profile.EditProfilePage(
                                          roleColor: _StudentColors.orange,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, color: Color(0xFFECEFF1)),
                            _buildNavigationRow(
                              icon: Icons.logout_rounded,
                              iconBg: const Color(0xFFFFF0F0),
                              iconColor: const Color(0xFFD32F2F),
                              title: 'Logout',
                              onTap: () => _logout(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderStatCard({
    required String icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECEFF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBadgePreviewIcon(String icon, String title, bool unlocked) {
    return Container(
      width: 70,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFFFD54F).withOpacity(0.4)
              : const Color(0xFFECEFF1),
          width: unlocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1.0 : 0.2,
            child: Text(icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked
                    ? const Color(0xFF263238)
                    : const Color(0xFFB0BEC5),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardItem({
    required String icon,
    required String value,
    required String label,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEFF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityItem({
    required String icon,
    required String title,
    required String time,
    required String xp,
    required Color bgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            xp,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF37474F),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF90A4AE),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelMilestonesDialog(BuildContext context, int level, int xp) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Level Milestones',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMilestoneRow('Lv.1-2', 'Beginner', 0),
              _buildMilestoneRow('Lv.3-4', 'Elementary', 500),
              _buildMilestoneRow('Lv.5-6', 'Learner', 1000),
              _buildMilestoneRow('Lv.7-8', 'Intermediate', 1750),
              _buildMilestoneRow('Lv.9+', 'Advanced', 2500),
              const SizedBox(height: 12),
              Text(
                'You currently have $xp XP.',
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: _StudentColors.orange,
              ),
              child: const Text('Awesome'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMilestoneRow(String levelRange, String title, int xpRequired) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                levelRange,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F),
                ),
              ),
              Text(
                '$xpRequired XP',
                style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }
}

class _CenteredTab extends StatelessWidget {
  const _CenteredTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _StudentPageFrame(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _StudentColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: _StudentColors.red, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: _StudentColors.deep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _StudentColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentColors {
  static const red = Color(0xFFE93A2F);
  static const orange = Color(0xFFFF8A21);
  static const deep = Color(0xFF1C2433);
  static const muted = Color(0xFF737C8B);
  static const paper = Color(0xFFFFFBF7);
}

int _toInt(dynamic value, {required int fallback}) {
  if (value is num) return value.toInt();
  return fallback;
}

int _unlockedBadgesCount(
  int xp,
  int streak,
  List<dynamic> completedLessons,
  int level,
) {
  int count = 0;
  if (streak >= 7) count++;
  if (completedLessons.isNotEmpty || xp >= 30) count++;
  if (xp >= 100 || completedLessons.length >= 2) count++;
  if (xp >= 250 || completedLessons.length >= 3) count++;
  if (xp >= 500 || completedLessons.length >= 5) count++;
  if (completedLessons.length >= 8) count++;
  if (xp >= 1000) count++;
  if (completedLessons.length >= 12 || level >= 6) count++;
  return count;
}

String _displayName(Map<String, dynamic> data) {
  final name = (data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;

  final firstName = (data['firstName'] ?? '').toString().trim();
  final lastName = (data['lastName'] ?? '').toString().trim();
  final fullName = '$firstName $lastName'.trim();
  if (fullName.isNotEmpty) return fullName;

  return 'Student';
}

Future<List<CourseUnit>> _fetchDynamicUnits(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) async {
  final list = <CourseUnit>[];
  for (int dIndex = 0; dIndex < docs.length; dIndex++) {
    final doc = docs[dIndex];
    final data = doc.data();
    final vocabSnapshot = await doc.reference.collection('vocabulary').get();
    final vocabDocs = vocabSnapshot.docs;

    final lessons = <Lesson>[];
    for (int i = 0; i < vocabDocs.length; i++) {
      final vData = vocabDocs[i].data();
      final word = vData['word'] ?? '';
      final english = vData['meaning'] ?? '';

      lessons.add(
        Lesson(
          id: '${doc.id}_$i',
          title: '$word - $english',
          subtitle: vData['pronunciation'] ?? '',
          isCompleted: false,
          isLocked: true,
          xpReward: 30, // Default 30 XP as in image
          items: generateItemsForVocab(
            word,
            vData['pronunciation'] ?? '',
            english,
            vData['exampleSentence'] ?? '',
            vData['exampleMeaning'] ?? '',
          ),
        ),
      );
    }

    // If there's a summary quiz, add it as a final lesson
    if (data['summaryQuiz'] != null) {
      lessons.add(
        Lesson(
          id: '${doc.id}_quiz',
          title: 'Unit ${data['unitNumber']} Summary Quiz',
          subtitle: 'Review & Test',
          isCompleted: false,
          isLocked: true,
          xpReward: 100, // Summary gives more XP
          items: [
            LessonItem(
              id: '${doc.id}_quiz_item',
              type: LessonType.quiz,
              chinese: data['summaryQuiz']['question'] ?? 'Quiz',
              pinyin: '',
              english: 'Review',
              options: List<String>.from(data['summaryQuiz']['options'] ?? []),
            ),
          ],
        ),
      );
    }

    final uNum = data['unitNumber'] ?? (dIndex + 4);
    final colors = [
      const Color(0xFF6C3BFF), // Premium Royal Purple
      const Color(0xFF0F6E56), // Premium Teal
      const Color(0xFFD81B60), // Premium Dark Pink
      const Color(0xFFE65100), // Premium Dark Orange
      const Color(0xFF006064), // Premium Cyan
      const Color(0xFF1E88E5), // Premium Blue
    ];
    final color = colors[(uNum is int ? uNum : 4) % colors.length];

    list.add(
      CourseUnit(
        id: doc.id,
        title: 'Unit $uNum: ${data['title'] ?? 'Unit'}',
        subtitle:
            (data['titleChinese'] != null &&
                data['titleChinese'].toString().trim().isNotEmpty)
            ? data['titleChinese'].toString().trim()
            : (data['description'] ?? 'Vocabulary'),
        color: color,
        lessons: lessons,
      ),
    );
  }
  return list;
}

class _CoursePathView extends StatefulWidget {
  final List<dynamic> completedLessons;
  const _CoursePathView({required this.completedLessons});

  @override
  State<_CoursePathView> createState() => _CoursePathViewState();
}

class _CoursePathViewState extends State<_CoursePathView> {
  List<CourseUnit>? _dynamicUnits;
  int _currentPage = 0;
  static const int _pageSize = 3;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && _dynamicUnits == null) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> vocabDocRefs = [];
        if (snapshot.hasData) {
          vocabDocRefs = snapshot.data!.docs.where((doc) {
            final type = doc.data()['type'] as String?;
            final materialsList = doc.data()['materials'] as List?;
            final isMaterial =
                type == 'material' ||
                (type != 'vocab_unit' &&
                    materialsList != null &&
                    materialsList.isNotEmpty);
            return !isMaterial; // Only dynamic vocab units
          }).toList();
        }

        return FutureBuilder<List<CourseUnit>>(
          future: _fetchDynamicUnits(vocabDocRefs),
          builder: (context, futureSnapshot) {
            final dynamicUnits = futureSnapshot.data ?? _dynamicUnits ?? [];
            if (futureSnapshot.hasData) {
              _dynamicUnits = dynamicUnits;
            }

            final allUnits = [...mockCourseUnits, ...dynamicUnits];

            final totalPages = allUnits.isEmpty
                ? 1
                : (allUnits.length / _pageSize).ceil();
            if (_currentPage >= totalPages) {
              _currentPage = totalPages - 1;
            }
            if (_currentPage < 0) {
              _currentPage = 0;
            }

            final startIndex = _currentPage * _pageSize;
            final endIndex = (startIndex + _pageSize).clamp(0, allUnits.length);
            final paginatedUnits = allUnits.sublist(startIndex, endIndex);

            return Column(
              children: [
                ...paginatedUnits.asMap().entries.map((entry) {
                  final unit = entry.value;
                  final unitIndex = startIndex + entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Unit Header Banner
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: unit.color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      unit.title,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      unit.subtitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Lesson Items with Path Line
                        ...unit.lessons.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Lesson lesson = entry.value;
                          final bool isLast = index == unit.lessons.length - 1;

                          // Calculate unlock state
                          bool isUnlocked = false;
                          bool isCompleted = widget.completedLessons.contains(
                            lesson.id,
                          );
                          if (unitIndex == 0 && index == 0) {
                            isUnlocked = true;
                          } else if (index > 0) {
                            isUnlocked = widget.completedLessons.contains(
                              unit.lessons[index - 1].id,
                            );
                          } else if (unitIndex > 0) {
                            isUnlocked = widget.completedLessons.contains(
                              allUnits[unitIndex - 1].lessons.last.id,
                            );
                          }
                          if (isCompleted) isUnlocked = true;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Path connection visual
                                SizedBox(
                                  width: 50,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? unit.color
                                              : (isUnlocked
                                                    ? unit.color.withValues(
                                                        alpha: 0.5,
                                                      )
                                                    : Colors.grey.shade300),
                                          shape: BoxShape.circle,
                                          border: isCompleted
                                              ? null
                                              : Border.all(
                                                  color: isUnlocked
                                                      ? unit.color
                                                      : Colors.grey.shade400,
                                                  width: 3,
                                                ),
                                        ),
                                        child: isCompleted
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                            : (isUnlocked
                                                  ? const Icon(
                                                      Icons.play_arrow,
                                                      color: Colors.white,
                                                      size: 18,
                                                    )
                                                  : const Icon(
                                                      Icons.lock,
                                                      color: Colors.grey,
                                                      size: 16,
                                                    )),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 4,
                                            color:
                                                widget.completedLessons
                                                    .contains(
                                                      unit.lessons[index].id,
                                                    )
                                                ? unit.color
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Lesson Card
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: InkWell(
                                      onTap: isUnlocked
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => BlocProvider(
                                                    create: (_) =>
                                                        new_bloc.LessonBloc()
                                                          ..add(
                                                            new_bloc.StartLesson(
                                                              lesson,
                                                            ),
                                                          ),
                                                    child:
                                                        new_lessons.LessonScreen(
                                                          lesson: lesson,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      child: Opacity(
                                        opacity: isUnlocked ? 1.0 : 0.5,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      lesson.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '+${lesson.xpReward}',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .orange
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.bolt,
                                                        color: Colors
                                                            .orange
                                                            .shade700,
                                                        size: 16,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                lesson.subtitle,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
                }).toList(),
                if (totalPages > 1) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _StudentColors.orange,
                            disabledForegroundColor: Colors.grey.shade400,
                            elevation: 0,
                            minimumSize: const Size(100, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _currentPage > 0
                                    ? const Color(0xFFFFDFC2)
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left_rounded),
                              SizedBox(width: 4),
                              Text(
                                'Previous',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Page ${_currentPage + 1} of $totalPages',
                          style: const TextStyle(
                            color: _StudentColors.deep,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _StudentColors.orange,
                            disabledForegroundColor: Colors.grey.shade400,
                            elevation: 0,
                            minimumSize: const Size(100, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _currentPage < totalPages - 1
                                    ? const Color(0xFFFFDFC2)
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
// -----------------------------------------------------
// WEEKLY PROGRESS CHART COMPONENT
// -----------------------------------------------------

class _WeeklyProgressChart extends StatelessWidget {
  final Map<String, dynamic> dailyActivity;

  const _WeeklyProgressChart({required this.dailyActivity});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weeklyData = <Map<String, dynamic>>[];

    // 1. Find the Monday of the CURRENT week
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    // 100% REAL DATA FROM FIRESTORE
    final Map<String, dynamic> dataToUse = dailyActivity;

    // 2. Build the fixed Monday to Sunday chart
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateString =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final xp = (dataToUse[dateString] as num?)?.toInt() ?? 0;

      // Check if this specific column is "Today"
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      weeklyData.add({'day': weekdays[i], 'xp': xp, 'isToday': isToday});
    }

    final maxXP = weeklyData
        .map((d) => (d['xp'] as int).toDouble())
        .reduce(math.max)
        .clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE4CF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Activity (XP)',
            style: TextStyle(
              color: _StudentColors.deep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((data) {
                final double percentage = data['xp'] / maxXP;
                final bool isToday = data['isToday'] as bool;

                return SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${data['xp']}',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 10,
                          // Darker orange if it's today, otherwise standard orange
                          color: isToday
                              ? _StudentColors.red
                              : _StudentColors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 18,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isToday
                              ? _StudentColors.red.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutQuart,
                          width: 18,
                          height: (90 * percentage).toDouble(),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _StudentColors.red
                                : _StudentColors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // The fixed M T W T F S S letters
                      Text(
                        data['day'],
                        maxLines: 1,
                        style: TextStyle(
                          // Highlight today's letter in red and bold
                          color: isToday
                              ? _StudentColors.red
                              : _StudentColors.muted,
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
