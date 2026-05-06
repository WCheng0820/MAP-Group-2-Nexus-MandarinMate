import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
    as mandarinmate_edit_profile;
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_game_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/lesson_detail_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/quiz_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/vocab_lesson_page.dart';

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

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenLearn});

  final VoidCallback onOpenLearn;

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
          final level = _toInt(data['level'], fallback: 1);
          final xp = _toInt(
            data['xp'],
            fallback: _toInt(data['xpPoints'], fallback: 0),
          );
          final streak = _toInt(
            data['streak'],
            fallback: _toInt(data['currentStreak'], fallback: 0),
          );
          final progress = _progressForXp(xp);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentHeader(name: name, streak: streak),
                const SizedBox(height: 14),
                _ProgressHero(
                  title: 'PB-003 Learning Dashboard',
                  headline: 'Level $level Mandarin',
                  subtitle: '${(progress * 100).round()}% to next level',
                  xp: xp,
                  progress: progress,
                  actionLabel: 'Start Learning',
                  onAction: onOpenLearn,
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
                      onTap: onOpenLearn,
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
                  title: 'Continue Lessons',
                  onViewAll: onOpenLearn,
                ),
                const SizedBox(height: 10),
                _HomeLessonPreview(onOpenUnit: _LearnTab.openUnitDetail),
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
    final unitAndVocab = await _firstUnitAndVocab();
    if (unitAndVocab == null) {
      if (!context.mounted) return;
      _showMessage(context, 'No lessons/vocabulary available yet.');
      return;
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardGamePage(
          unit: unitAndVocab.unit,
          vocabItems: unitAndVocab.vocab,
        ),
      ),
    );
  }

  static Future<void> openPronunciation(BuildContext context) async {
    final unitAndVocab = await _firstUnitAndVocab();
    if (unitAndVocab == null) {
      if (!context.mounted) return;
      _showMessage(context, 'No pronunciation data available yet.');
      return;
    }

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
  }

  static Future<void> openDailyChallenge(BuildContext context) async {
    final unitAndVocab = await _firstUnitAndVocab();
    if (unitAndVocab == null || unitAndVocab.vocab.isEmpty) {
      if (!context.mounted) return;
      _showMessage(context, 'No quiz data available yet.');
      return;
    }

    final questions = unitAndVocab.vocab.map((item) {
      return QuizQuestion(
        question: 'What does "${item.chinese}" mean?',
        options: [item.malay, item.english, 'Not sure', 'Other phrase'],
        correctIndex: 0,
        type: 'vocab',
      );
    }).toList();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(unit: unitAndVocab.unit, questions: questions),
      ),
    );
  }

  static Future<void> openUnitDetail(
    BuildContext context,
    LessonUnit unit,
  ) async {
    final vocabSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(unit.id)
        .collection('vocab')
        .get();

    final vocab = vocabSnapshot.docs
        .map((doc) => VocabItem.fromMap(doc.data()))
        .toList();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailPage(unit: unit, vocabItems: vocab),
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
        .collection('vocab')
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
          final progress = _progressForXp(xp);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressHero(
                  title: 'Overall Progress',
                  headline: 'Level $level',
                  subtitle: '${(progress * 100).round()}% to next level',
                  xp: xp,
                  progress: progress,
                  actionLabel: 'Practice Now',
                  onAction: () => openDailyChallenge(context),
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
                const Text(
                  'Mandarin Lessons',
                  style: TextStyle(
                    color: _StudentColors.deep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _LessonsList(onOpenUnit: openUnitDetail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeLessonPreview extends StatelessWidget {
  const _HomeLessonPreview({required this.onOpenUnit});

  final Future<void> Function(BuildContext context, LessonUnit unit) onOpenUnit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('order')
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyState(text: 'No lessons available yet.');
        }

        final units = docs
            .map((doc) => LessonUnit.fromFirestore(doc.data(), doc.id))
            .toList();

        return Column(
          children: units
              .map((unit) => _LessonCard(unit: unit, onTap: onOpenUnit))
              .toList(),
        );
      },
    );
  }
}

class _LessonsList extends StatelessWidget {
  const _LessonsList({required this.onOpenUnit});

  final Future<void> Function(BuildContext context, LessonUnit unit) onOpenUnit;

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

        final units = docs
            .map((doc) => LessonUnit.fromFirestore(doc.data(), doc.id))
            .toList();

        return Column(
          children: units
              .map((unit) => _LessonCard(unit: unit, onTap: onOpenUnit))
              .toList(),
        );
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
    required this.subtitle,
    required this.xp,
    required this.progress,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String headline;
  final String subtitle;
  final int xp;
  final double progress;
  final String actionLabel;
  final VoidCallback onAction;

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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFFFF4EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _StudentColors.red,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
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
  const _LessonCard({required this.unit, required this.onTap});

  final LessonUnit unit;
  final Future<void> Function(BuildContext context, LessonUnit unit) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(context, unit),
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
        final progress = _progressForXp(xp);

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
                subtitle: '${(progress * 100).round()}% to next level',
                xp: xp,
                progress: progress,
                actionLabel: 'Continue',
                onAction: () => Navigator.pop(context),
              ),
            ],
          ),
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
