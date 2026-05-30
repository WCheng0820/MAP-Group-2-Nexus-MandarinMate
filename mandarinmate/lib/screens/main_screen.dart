import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
    as mandarinmate_edit_profile;
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_levels_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/lesson_detail_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/quiz_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/vocab_lesson_page.dart';
import 'package:mandarinmate/features/lessons/ui/lesson_screen.dart'
    as new_lessons;
import 'package:mandarinmate/features/lessons/data/mock_lessons.dart';
import 'package:mandarinmate/features/lessons/bloc/lesson_bloc.dart'
    as new_bloc;
import 'package:mandarinmate/features/lessons/models/lesson_model.dart';

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
      const _ProfileTab(),
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
          final level = _toInt(data['level'], fallback: 1);
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );
          final streak = _toInt(
            data['streak'],
            fallback: _toInt(data['currentStreak'], fallback: 0),
          );
          final completedLessons = (data['completedLessons'] as List?) ?? [];
          final levelProgress = _progressForXp(xp);

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
                  final isMaterial = type == 'material' || (type != 'vocab_unit' && materialsList != null && materialsList.isNotEmpty);
                  return !isMaterial; // Only dynamic vocab units
                }).toList();
              }

              return FutureBuilder<List<CourseUnit>>(
                future: _fetchDynamicUnits(vocabDocRefs),
                builder: (context, futureSnapshot) {
                  final dynamicUnits = futureSnapshot.data ?? _cachedDynamicUnits ?? [];
                  if (futureSnapshot.hasData) {
                    _cachedDynamicUnits = dynamicUnits;
                  }

                  final allUnits = [...mockCourseUnits, ...dynamicUnits];

                  final totalLessons = allUnits.fold<int>(
                    0,
                    (total, unit) => total + unit.lessons.length,
                  );
                  final completedCount = completedLessons.length;
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
                          progress: levelProgress,
                          actionLabel: nextLesson != null
                              ? 'Continue Lesson'
                              : 'Course Completed',
                          onAction: nextLesson != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (_) =>
                                            new_bloc.LessonBloc()
                                              ..add(new_bloc.StartLesson(nextLesson!)),
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
                              onTap: () => _LearnTab.openDailyChallenge(context),
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
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: 'Starred Vocab & Phrases',
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 10),
                        const _StarredItemsRow(),
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
  const _StarredItemsRow();

  @override
  Widget build(BuildContext context) {
    // For MVP gamification context, we mock the starred items.
    // In future this reads a 'starred' array from User document.
    final starredItems = [
      {'title': '你好', 'type': 'Vocab', 'color': Colors.red},
      {'title': '早上好', 'type': 'Vocab', 'color': Colors.blue},
      {'title': '谢谢', 'type': 'Phrase', 'color': Colors.orange},
      {'title': '吃饭', 'type': 'Phrase', 'color': Colors.purple},
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: starredItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = starredItems[index];
          final color = item['color'] as Color;
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
                Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(height: 4),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  item['type'] as String,
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
    final unitAndVocab = await _firstUnitAndVocab();

    List<QuizQuestion> questions = [];
    LessonUnit? unit;

    if (unitAndVocab != null && unitAndVocab.vocab.isNotEmpty) {
      unit = unitAndVocab.unit;
      questions = unitAndVocab.vocab.map((item) {
        return QuizQuestion(
          question: 'What does "${item.chinese}" mean?',
          options: [item.malay, item.english, 'Not sure', 'Other phrase']
            ..shuffle(),
          correctIndex: 0,
          type: 'vocab',
        );
      }).toList();
    } else if (mockCourseUnits.isNotEmpty) {
      // Fallback to mock data
      final firstLesson = mockCourseUnits.first.lessons.first;
      unit = LessonUnit(
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
      questions = firstLesson.items
          .where((i) => i.type == LessonType.vocabulary)
          .map(
            (i) => QuizQuestion(
              question: 'What does "${i.chinese}" mean?',
              options: [i.english, 'Apple', 'Water', 'Book']..shuffle(),
              correctIndex: 0,
              type: 'vocab',
            ),
          )
          .toList();
    }

    if (questions.isEmpty) {
      if (!context.mounted) return;
      _showMessage(context, 'No challenge data available yet.');
      return;
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(unit: unit!, questions: questions),
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _LeaderboardSheet(),
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
          final level = _toInt(data['level'], fallback: 1);
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );

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
                  completedLessons: List<String>.from(data['completedLessons'] ?? []),
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
  const _LessonsList({required this.onOpenUnit, required this.completedLessons});

  final Future<void> Function(BuildContext context, LessonUnit unit, bool isCompleted) onOpenUnit;
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
          
          final isMaterial = type == 'material' || (type != 'vocab_unit' && materialsList != null && materialsList.isNotEmpty);

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
                      sections.add(_LessonCard(
                        unit: unit,
                        onTap: onOpenUnit,
                        isCompleted: isCompleted,
                      ));
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
  final Future<void> Function(BuildContext context, LessonUnit unit, bool isCompleted) onTap;
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
  const _LeaderboardSheet();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('xp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (docs.isEmpty) {
          return const _EmptyState(text: 'No leaderboard data yet.');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          shrinkWrap: true,
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Leaderboard',
                  style: TextStyle(
                    color: _StudentColors.deep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }

            final data = docs[index - 1].data();
            final name = _displayName(data);
            final xp = _toInt(
              data['xp'],
              fallback: _toInt(data['xpPoints'], fallback: 0),
            );

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _StudentColors.orange.withValues(alpha: 0.14),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _StudentColors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(name),
              trailing: Text(
                '$xp XP',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            );
          },
        );
      },
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
        final level = _toInt(data['level'], fallback: 1);
        final xp = _toInt(
          data['xp'],
          fallback: _toInt(data['xpPoints'], fallback: 0),
        );
        final levelProgress = _progressForXp(xp);
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
                final isMaterial = type == 'material' || (type != 'vocab_unit' && materialsList != null && materialsList.isNotEmpty);
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
                    ? completedLessons.length / totalLessons
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
                        subtitle: '${(courseProgress * 100).round()}% Course Completed',
                        xp: xp,
                        progress: levelProgress,
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
                                      create: (_) =>
                                          new_bloc.LessonBloc()
                                            ..add(new_bloc.StartLesson(nextLesson!)),
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

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

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
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = _displayName(data);
          final email =
              (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
                  .toString();
          final membershipStatus = _membershipStatusFromData(data);
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );

          return Center(
            child: Container(
              width: 330,
              margin: const EdgeInsets.all(18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFE4CF)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: _StudentColors.red.withValues(alpha: 0.12),
                    child: Text(
                      name.isEmpty ? 'S' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: _StudentColors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _StudentColors.deep,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _StudentColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MembershipStatusCard(status: membershipStatus),
                  const SizedBox(height: 16),
                  _HeroBadgeDark(label: '$xp XP earned'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const mandarinmate_edit_profile.EditProfilePage(
                                    roleColor: _StudentColors.red,
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFDFC2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: _StudentColors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: _StudentColors.deep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _logout(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFD6D6)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFD32F2F),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }
}

class _HeroBadgeDark extends StatelessWidget {
  const _HeroBadgeDark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _StudentColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _StudentColors.orange,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String subtitle;
    late final Color color;
    switch (status) {
      case MembershipStatus.approved:
        title = 'Membership Approved';
        subtitle =
            'Your account has been approved and is active in the system.';
        color = const Color(0xFF15803D);
        break;
      case MembershipStatus.rejected:
        title = 'Membership Rejected';
        subtitle =
            'Your registration needs admin review before it can be considered valid.';
        color = const Color(0xFFB91C1C);
        break;
      case MembershipStatus.pending:
        title = 'Membership Pending';
        subtitle =
            'Your registration has been submitted and is waiting for admin approval.';
        color = _StudentColors.orange;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _StudentColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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

double _progressForXp(int xp) {
  return ((xp % 500) / 500).clamp(0.0, 1.0).toDouble();
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

MembershipStatus _membershipStatusFromData(Map<String, dynamic> data) {
  final status = (data['membershipStatus'] ?? 'approved')
      .toString()
      .toLowerCase()
      .split('.')
      .last;
  switch (status) {
    case 'pending':
      return MembershipStatus.pending;
    case 'rejected':
      return MembershipStatus.rejected;
    case 'approved':
    default:
      return MembershipStatus.approved;
  }
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<List<CourseUnit>> _fetchDynamicUnits(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
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
       
      lessons.add(Lesson(
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
        )
      ));
    }
    
    // If there's a summary quiz, add it as a final lesson
    if (data['summaryQuiz'] != null) {
      lessons.add(Lesson(
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
           )
        ]
      ));
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

    list.add(CourseUnit(
      id: doc.id,
      title: 'Unit $uNum: ${data['title'] ?? 'Unit'}',
      subtitle: (data['titleChinese'] != null && data['titleChinese'].toString().trim().isNotEmpty)
          ? data['titleChinese'].toString().trim()
          : (data['description'] ?? 'Vocabulary'),
      color: color,
      lessons: lessons,
    ));
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
      stream: FirebaseFirestore.instance.collection('lessons').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && _dynamicUnits == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
        List<QueryDocumentSnapshot<Map<String, dynamic>>> vocabDocRefs = [];
        if (snapshot.hasData) {
          vocabDocRefs = snapshot.data!.docs.where((doc) {
            final type = doc.data()['type'] as String?;
            final materialsList = doc.data()['materials'] as List?;
            final isMaterial = type == 'material' || (type != 'vocab_unit' && materialsList != null && materialsList.isNotEmpty);
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

            final totalPages = allUnits.isEmpty ? 1 : (allUnits.length / _pageSize).ceil();
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
                bool isCompleted = widget.completedLessons.contains(lesson.id);
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
                                          ? unit.color.withValues(alpha: 0.5)
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
                                      widget.completedLessons.contains(
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
                                          create: (_) => new_bloc.LessonBloc()
                                            ..add(new_bloc.StartLesson(lesson)),
                                          child: new_lessons.LessonScreen(
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
                                  borderRadius: BorderRadius.circular(16),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lesson.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            Text(
                                              '+${lesson.xpReward}',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Icon(
                                              Icons.bolt,
                                              color: Colors.orange.shade700,
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
