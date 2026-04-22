import 'dart:math' as math;

import 'package:flutter/material.dart';

class GamifiedShowcasePage extends StatelessWidget {
  const GamifiedShowcasePage({super.key});

  static const _red = Color(0xFFE93A2F);
  static const _orange = Color(0xFFFF8A21);
  static const _deep = Color(0xFF1C2433);
  static const _paper = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    const screens = <_ShowcaseScreen>[
      _ShowcaseScreen('Dashboard', _DashboardMockup()),
      _ShowcaseScreen('Listening', _ListeningMockup()),
      _ShowcaseScreen('Complete', _LessonCompleteMockup()),
      _ShowcaseScreen('Quiz', _QuizMockup()),
      _ShowcaseScreen('Challenge', _ChallengeCompleteMockup()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EA),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _ShowcaseBackdrop()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: _ShowcaseHeader(),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final phoneWidth = constraints.maxWidth >= 1500
                          ? (constraints.maxWidth - 168) / 5
                          : constraints.maxWidth >= 900
                          ? 286.0
                          : math.min(312.0, constraints.maxWidth - 48);

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                        itemCount: screens.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 22),
                        itemBuilder: (context, index) {
                          final screen = screens[index];
                          return SizedBox(
                            width: phoneWidth.clamp(250.0, 330.0),
                            child: _PhoneShell(
                              label: screen.label,
                              child: screen.child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseScreen {
  const _ShowcaseScreen(this.label, this.child);

  final String label;
  final Widget child;
}

class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: GamifiedShowcasePage._red,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33E93A2F),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.translate_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MandarinMate Gamified Learning UI',
                style: TextStyle(
                  color: GamifiedShowcasePage._deep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Five mobile screens for dashboard, listening, lesson complete, quiz, and challenge success.',
                style: TextStyle(
                  color: Color(0xFF6A7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShowcaseBackdrop extends StatelessWidget {
  const _ShowcaseBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter());
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()..color = const Color(0xFFFFE2DA);
    final orangePaint = Paint()..color = const Color(0xFFFFD7A8);

    final redPath = Path()
      ..moveTo(0, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.03,
        size.width * 0.64,
        size.height * 0.13,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.21,
        size.width,
        size.height * 0.08,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final orangePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.88,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(redPath, redPaint);
    canvas.drawPath(orangePath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: GamifiedShowcasePage._deep,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E111827),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.all(9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ColoredBox(color: Colors.white, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardMockup extends StatelessWidget {
  const _DashboardMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GamifiedShowcasePage._paper,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TopStatusBar(title: '你好, Aina', streak: '12'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    GamifiedShowcasePage._red,
                    GamifiedShowcasePage._orange,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _WhiteLabel('Overall Progress')),
                      _LevelBadge(level: 'Lv 5'),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Unit 1: Basics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 14),
                  _WhiteProgress(value: 0.68),
                  SizedBox(height: 8),
                  Text(
                    '340 / 500 XP to next level',
                    style: TextStyle(
                      color: Color(0xFFFFF3E8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.28,
              children: const [
                _ActionTile(
                  icon: Icons.style_rounded,
                  label: 'Flashcards',
                  color: GamifiedShowcasePage._red,
                ),
                _ActionTile(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Daily Challenge',
                  color: GamifiedShowcasePage._orange,
                ),
                _ActionTile(
                  icon: Icons.insights_rounded,
                  label: 'Progress',
                  color: Color(0xFF16A34A),
                ),
                _ActionTile(
                  icon: Icons.emoji_events_rounded,
                  label: 'Leaderboard',
                  color: Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Lesson Units',
              style: TextStyle(
                color: GamifiedShowcasePage._deep,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const _LessonUnitTile(
              number: '01',
              title: 'Greetings',
              chinese: '打招呼',
              xp: '+15 XP',
              completed: true,
            ),
            const _LessonUnitTile(
              number: '02',
              title: 'Numbers',
              chinese: '数字',
              xp: '+20 XP',
              completed: true,
            ),
            const _LessonUnitTile(
              number: '03',
              title: 'Family',
              chinese: '家庭',
              xp: '+18 XP',
              completed: false,
            ),
            const _LessonUnitTile(
              number: '04',
              title: 'Daily Objects',
              chinese: '日常用品',
              xp: '+22 XP',
              completed: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningMockup extends StatelessWidget {
  const _ListeningMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          const _CompactProgressHeader(
            title: 'Listening',
            progress: 0.42,
            color: Color(0xFF2F80ED),
          ),
          const Spacer(),
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: const Color(0xFF2F80ED),
              borderRadius: BorderRadius.circular(44),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332F80ED),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 68,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'What did you hear?',
            style: TextStyle(
              color: GamifiedShowcasePage._deep,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the correct translation',
            style: TextStyle(
              color: Color(0xFF7A8291),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const _ChoicePill(label: 'Good morning', selected: false),
          const _ChoicePill(label: 'Thank you', selected: true),
          const _ChoicePill(label: 'See you soon', selected: false),
          const _ChoicePill(label: 'I am a student', selected: false),
        ],
      ),
    );
  }
}

class _LessonCompleteMockup extends StatelessWidget {
  const _LessonCompleteMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GamifiedShowcasePage._red,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ConfettiPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: GamifiedShowcasePage._red,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lesson Complete!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: _CompleteStat(value: '+120', label: 'XP'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _CompleteStat(value: '14', label: 'Days'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _CompleteStat(value: '92%', label: 'Score'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      _BreakdownBar(
                        label: 'Vocabulary',
                        value: 0.96,
                        color: Color(0xFF22C55E),
                      ),
                      _BreakdownBar(
                        label: 'Listening',
                        value: 0.88,
                        color: Color(0xFF2F80ED),
                      ),
                      _BreakdownBar(
                        label: 'Quiz',
                        value: 0.92,
                        color: GamifiedShowcasePage._orange,
                      ),
                      _BreakdownBar(
                        label: 'Pronunciation',
                        value: 0.74,
                        color: Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const _LightCta(label: 'Continue Learning'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizMockup extends StatelessWidget {
  const _QuizMockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          decoration: const BoxDecoration(
            color: GamifiedShowcasePage._orange,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniHeaderRow(title: 'Quiz Time', step: '3/10'),
              SizedBox(height: 16),
              _WhiteProgress(value: 0.3),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: GamifiedShowcasePage._paper,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F111827),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Translate this sentence',
                        style: TextStyle(
                          color: Color(0xFF7A8291),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '我喜欢学习中文',
                        style: TextStyle(
                          color: GamifiedShowcasePage._deep,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _QuizOption(label: 'I like learning Mandarin'),
                const _QuizOption(label: 'I am learning quickly'),
                const _QuizOption(label: 'I teach Chinese lessons'),
                const _QuizOption(label: 'I need more practice'),
                const Spacer(),
                const _PrimaryCta(label: 'Submit Answer'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChallengeCompleteMockup extends StatelessWidget {
  const _ChallengeCompleteMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GamifiedShowcasePage._orange,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22FFFFFF),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: GamifiedShowcasePage._orange,
              size: 64,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Perfect!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Challenge Complete',
            style: TextStyle(
              color: Color(0xFFFFF4EA),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              children: [
                _SuccessRow(label: '10 correct answers'),
                _SuccessRow(label: 'No hints used'),
                _SuccessRow(label: 'Finished in 2m 08s'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _LightCta(label: '+50 XP Bonus'),
        ],
      ),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({required this.title, required this.streak});

  final String title;
  final String streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: GamifiedShowcasePage._deep,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: GamifiedShowcasePage._orange,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                streak,
                style: const TextStyle(
                  color: GamifiedShowcasePage._deep,
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

class _WhiteLabel extends StatelessWidget {
  const _WhiteLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFF3E8),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WhiteProgress extends StatelessWidget {
  const _WhiteProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 9,
        value: value,
        backgroundColor: Colors.white.withValues(alpha: 0.32),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GamifiedShowcasePage._deep,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonUnitTile extends StatelessWidget {
  const _LessonUnitTile({
    required this.number,
    required this.title,
    required this.chinese,
    required this.xp,
    required this.completed,
  });

  final String number;
  final String title;
  final String chinese;
  final String xp;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE7D6)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: completed
                  ? GamifiedShowcasePage._red
                  : const Color(0xFFFFECE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : Text(
                      number,
                      style: const TextStyle(
                        color: GamifiedShowcasePage._red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: GamifiedShowcasePage._deep,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  chinese,
                  style: const TextStyle(
                    color: Color(0xFF7A8291),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            xp,
            style: const TextStyle(
              color: GamifiedShowcasePage._orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactProgressHeader extends StatelessWidget {
  const _CompactProgressHeader({
    required this.title,
    required this.progress,
    required this.color,
  });

  final String title;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: GamifiedShowcasePage._deep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.favorite_rounded,
              color: GamifiedShowcasePage._red,
            ),
            const SizedBox(width: 4),
            const Text(
              '3',
              style: TextStyle(
                color: GamifiedShowcasePage._deep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE7EDF7),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF2F80ED) : const Color(0xFFE7EDF7),
          width: selected ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected
              ? const Color(0xFF2F80ED)
              : GamifiedShowcasePage._deep,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CompleteStat extends StatelessWidget {
  const _CompleteStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: GamifiedShowcasePage._red,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8291),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: GamifiedShowcasePage._deep,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF7A8291),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: const Color(0xFFE7EDF7),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHeaderRow extends StatelessWidget {
  const _MiniHeaderRow({required this.title, required this.step});

  final String title;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDFC2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: GamifiedShowcasePage._deep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: GamifiedShowcasePage._orange,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _LightCta extends StatelessWidget {
  const _LightCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: GamifiedShowcasePage._red,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: GamifiedShowcasePage._deep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      Colors.white,
      const Color(0xFFFFD166),
      const Color(0xFFFFF4EA),
      const Color(0xFFFFB703),
    ];

    for (var i = 0; i < 42; i++) {
      final x = (math.sin(i * 1.7) * 0.5 + 0.5) * size.width;
      final y = ((i * 37) % size.height).toDouble();
      final paint = Paint()..color = colors[i % colors.length];
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: i.isEven ? 7 : 10,
        height: i.isEven ? 10 : 7,
      );

      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(i * 0.45);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
