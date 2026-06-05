import 'package:flutter/material.dart';
import 'package:mandarinmate/lessons/data/mock_lessons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../bloc/active_lesson_bloc.dart';
import '../../domain/active_lesson_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  void _initTts() async {
    await flutterTts.setLanguage("zh-CN");
    await flutterTts.setSpeechRate(0.5);
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  // -----------------------------------------------------------------
  // NEW HELPER: Handles all XP, Progress, and Streak logic in one place
  // -----------------------------------------------------------------
  Future<void> _saveLessonProgress(User user, int xpEarned, String lessonId) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final now = DateTime.now();

    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Calculate exactly what "yesterday" was
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayString = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    try {
      // 1. Get the current user data to check their streak status
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};

      final lastActiveDate = data['lastActiveDate'] as String?;
      int currentStreak = data['currentStreak'] as int? ?? 0;

      // 2. Streak Logic
      if (lastActiveDate == todayString) {
        // They already completed a lesson today. Streak is safe, no changes needed.
      } else if (lastActiveDate == yesterdayString) {
        // They completed a lesson yesterday. Streak continues!
        currentStreak += 1;
      } else {
        // They missed a day, or this is their very first lesson. Reset to 1.
        currentStreak = 1;
      }

      // 3. Update everything in Firestore at once
      await docRef.update({
        'xpPoints': FieldValue.increment(xpEarned),
        'xp': FieldValue.increment(xpEarned),
        'completedLessons': FieldValue.arrayUnion([lessonId]),
        'dailyActivity.$todayString': FieldValue.increment(xpEarned),
        'currentStreak': currentStreak,
        'lastActiveDate': todayString, // Update last active to today
      });
    } catch (e) {
      debugPrint('Firebase write error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LessonBloc()..add(StartLesson(widget.lesson)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.lesson.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(context),
          ),
        ),
        body: BlocBuilder<LessonBloc, LessonState>(
          builder: (context, state) {
            if (state is LessonInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is LessonActive) {
              return _buildActiveLesson(context, state);
            } else if (state is LessonCompleted) {
              return _buildCompletionScreen(context, state);
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildActiveLesson(BuildContext context, LessonActive state) {
    final item = state.currentItem;

    return Column(
      children: [
        LinearProgressIndicator(value: state.progress),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildLessonContent(context, item, state),
                  ),
                ),
                if (state.showFeedback) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: state.lastAnswerCorrect!
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.lastAnswerCorrect! ? 'Correct!' : 'Incorrect',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: state.lastAnswerCorrect!
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                        if (!state.lastAnswerCorrect!)
                          Text('The correct answer means: ${item.english}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.showFeedback
                      ? () => context.read<LessonBloc>().add(NextItem())
                      : (item.type == LessonType.vocabulary
                      ? () => context.read<LessonBloc>().add(NextItem())
                      : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    state.showFeedback ? 'Continue' : 'Check',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonContent(
      BuildContext context,
      LessonItem item,
      LessonActive state,
      ) {
    switch (item.type) {
      case LessonType.vocabulary:
        return _buildVocabularyView(item);
      case LessonType.listening:
        return _buildListeningView(context, item, state);
      case LessonType.speaking:
        return _buildSpeakingView(context, item, state);
      case LessonType.matching:
        return _buildMatchingView(context, item, state);
      case LessonType.quiz:
        return _buildQuizView(context, item, state);
    }
  }

  Widget _buildVocabularyView(LessonItem item) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'New Word',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            _VocabStarButton(item: item),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                item.chinese,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.pinyin,
                style: const TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                item.english,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => flutterTts.speak(item.chinese),
                icon: const Icon(Icons.volume_up, color: Colors.white),
                label: const Text(
                  'Listen',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        if (item.exampleSentence != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXAMPLE SENTENCE',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  item.exampleSentence!,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  item.exampleEnglish!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListeningView(
      BuildContext context,
      LessonItem item,
      LessonActive state,
      ) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'What did you hear?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        InkWell(
          onTap: () => flutterTts.speak(item.chinese),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volume_up, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: (item.options ?? []).map((option) {
            return InkWell(
              onTap: state.showFeedback
                  ? null
                  : () {
                bool isCorrect = option == item.english;
                context.read<LessonBloc>().add(SubmitAnswer(isCorrect));
              },
              child: Container(
                width: MediaQuery.of(context).size.width / 2 - 24,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    option,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpeakingView(
      BuildContext context,
      LessonItem item,
      LessonActive state,
      ) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'Say this phrase aloud:',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                item.chinese,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.pinyin,
                style: const TextStyle(fontSize: 20, color: Colors.purple),
              ),
              const SizedBox(height: 16),
              Text(item.english, style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (_speechToText.isListening)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Icon(Icons.graphic_eq, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Listening: $_lastWords',
                style: const TextStyle(
                  color: Colors.purple,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            if (_speechToText.isNotListening) {
              setState(() => _lastWords = '');
              await _speechToText.listen(
                onResult: (result) {
                  setState(() => _lastWords = result.recognizedWords);
                  if (result.finalResult) {
                    bool isCorrect = result.recognizedWords.contains(
                      item.chinese,
                    );
                    context.read<LessonBloc>().add(SubmitAnswer(isCorrect));
                  }
                },
                localeId: "zh_CN",
              );
            } else {
              await _speechToText.stop();
              setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _speechToText.isListening ? Colors.red : Colors.purple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _speechToText.isListening ? Icons.mic_off : Icons.mic,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Fallback for emulators without mic
        TextButton(
          onPressed: () {
            context.read<LessonBloc>().add(SubmitAnswer(true));
          },
          child: const Text(
            "Emulator Bypass (Skip Mic)",
            style: TextStyle(
              color: Colors.grey,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchingView(
      BuildContext context,
      LessonItem item,
      LessonActive state,
      ) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'Match the pairs',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        MatchingGame(
          item: item,
          onComplete: (isCorrect) {
            context.read<LessonBloc>().add(SubmitAnswer(isCorrect));
          },
        ),
      ],
    );
  }

  Widget _buildQuizView(
      BuildContext context,
      LessonItem item,
      LessonActive state,
      ) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'What does ${item.chinese} (${item.pinyin}) mean?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        ...(item.options ?? []).map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: state.showFeedback
                  ? null
                  : () {
                bool isCorrect = option == item.english;
                context.read<LessonBloc>().add(SubmitAnswer(isCorrect));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompletionScreen(BuildContext context, LessonCompleted state) {
    final accuracy = (state.correctAnswers / state.lesson.items.length) * 100;

    return Container(
      color: Colors.red.shade900,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'LESSON COMPLETE!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Excellent Work!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildStatCard(
                    'XP Earned',
                    '+${state.xpEarned}',
                    Icons.bolt,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Accuracy',
                    '${accuracy.toInt()}%',
                    Icons.check_circle_outline,
                    Colors.greenAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              'NEW BADGES EARNED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.track_changes,
                          color: Colors.pinkAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sharp Shooter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '100% accuracy',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Speed Learner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Completed fast',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ==========================================
            // NEXT LESSON BUTTON
            // ==========================================
            ElevatedButton.icon(
              onPressed: () async {
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated) {
                  final user = authState.user;

                  // 1. Save all progress using our new helper
                  await _saveLessonProgress(user, state.xpEarned, state.lesson.id);

                  if (!context.mounted) return;

                  // 2. Fetch the updated profile to find the actual NEXT lesson
                  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                  final userSnapshot = await docRef.get();
                  final completedLessons = List<String>.from(userSnapshot.data()?['completedLessons'] ?? []);

                  Lesson? nextLesson;
                  for (var unit in mockCourseUnits) {
                    for (var l in unit.lessons) {
                      if (!completedLessons.contains(l.id)) {
                        nextLesson = l;
                        break;
                      }
                    }
                    if (nextLesson != null) break;
                  }

                  if (!context.mounted) return;

                  if (nextLesson != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (_) => LessonBloc()..add(StartLesson(nextLesson!)),
                          child: LessonScreen(lesson: nextLesson!),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Course Complete! Amazing job! 🎉')),
                    );
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } else {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              icon: const Icon(Icons.emoji_events, color: Colors.red),
              label: const Text(
                'Next Lesson',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider(
                            create: (_) =>
                            LessonBloc()..add(StartLesson(state.lesson)),
                            child: LessonScreen(lesson: state.lesson),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // ==========================================
                // HOME BUTTON
                // ==========================================
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated) {
                        final user = authState.user;

                        // 1. Save all progress using our new helper
                        await _saveLessonProgress(user, state.xpEarned, state.lesson.id);
                      }

                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home, color: Colors.white),
                    label: const Text(
                      'Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color iconColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Lesson?'),
        content: const Text(
          'You will lose all progress for this lesson if you exit now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MatchingGame extends StatefulWidget {
  final LessonItem item;
  final Function(bool) onComplete;

  const MatchingGame({super.key, required this.item, required this.onComplete});

  @override
  State<MatchingGame> createState() => _MatchingGameState();
}

class _MatchingGameState extends State<MatchingGame> {
  String? firstSelected;
  Set<String> matched = {};

  final Map<String, String> pairs = {};
  List<String> displayItems = [];

  @override
  void initState() {
    super.initState();
    // Assuming options is like ['你好', 'Hello', '谢谢', 'Thank You']
    final opts = widget.item.options ?? [];
    for (int i = 0; i < opts.length - 1; i += 2) {
      pairs[opts[i]] = opts[i + 1];
      pairs[opts[i + 1]] = opts[i]; // Bidirectional
    }
    displayItems = List.from(opts)..shuffle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: displayItems.map((option) {
            final isMatched = matched.contains(option);
            final isSelected = firstSelected == option;

            return InkWell(
              onTap: isMatched
                  ? null
                  : () {
                if (firstSelected == null) {
                  setState(() {
                    firstSelected = option;
                  });
                } else if (firstSelected == option) {
                  setState(() {
                    firstSelected = null;
                  });
                } else {
                  // check match
                  if (pairs[firstSelected!] == option) {
                    setState(() {
                      matched.add(firstSelected!);
                      matched.add(option);
                      firstSelected = null;
                    });
                    if (matched.length == displayItems.length) {
                      widget.onComplete(true);
                    }
                  } else {
                    setState(() {
                      firstSelected = null;
                    }); // reset, maybe show error effect
                    // Optionally notify for wrong match or reduce lives
                  }
                }
              },
              child: Opacity(
                opacity: isMatched ? 0.3 : 1.0,
                child: Container(
                  width: MediaQuery.of(context).size.width / 2 - 24,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.red.shade100 : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _VocabStarButton extends StatelessWidget {
  final LessonItem item;

  const _VocabStarButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> starredList = data['starredItems'] ?? [];

        bool isStarred = starredList.any((e) => e['title'] == item.chinese);

        return IconButton(
          icon: Icon(
            isStarred ? Icons.star : Icons.star_border,
            color: isStarred ? Colors.amber : Colors.grey,
            size: 32,
          ),
          onPressed: () {
            final docRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid);
            final itemMap = {
              'title': item.chinese,
              'type': item.type == LessonType.vocabulary ? 'Vocab' : 'Phrase',
              'english': item.english,
            };
            if (isStarred) {
              final toRemove = starredList.firstWhere(
                    (e) => e['title'] == item.chinese,
              );
              docRef.update({
                'starredItems': FieldValue.arrayRemove([toRemove]),
              });
            } else {
              docRef.update({
                'starredItems': FieldValue.arrayUnion([itemMap]),
              });
            }
          },
        );
      },
    );
  }
}
