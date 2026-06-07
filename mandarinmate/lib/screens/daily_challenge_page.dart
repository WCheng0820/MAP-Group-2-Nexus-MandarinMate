import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mandarinmate/lessons/domain/active_lesson_model.dart';

// Helper class for curated vocab pool
class ChallengeVocab {
  final String chinese;
  final String pinyin;
  final String english;
  final String lessonId;

  ChallengeVocab({
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.lessonId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeVocab &&
          runtimeType == other.runtimeType &&
          chinese == other.chinese &&
          english == other.english;

  @override
  int get hashCode => chinese.hashCode ^ english.hashCode;
}

enum ChallengeType {
  meaning,   // Translate Chinese characters to English/Malay multiple-choice
  pinyin,    // Choose correct Pinyin spelling multiple-choice
  listening, // Listen to Chinese TTS audio, select correct translation multiple-choice
  speaking,  // Speak the Chinese characters aloud, validated by speech-to-text
}

class DailyChallengeQuestion {
  final ChallengeVocab vocab;
  final ChallengeType type;
  final List<String> options;
  final int correctIndex;

  DailyChallengeQuestion({
    required this.vocab,
    required this.type,
    required this.options,
    required this.correctIndex,
  });
}

class DailyChallengePage extends StatefulWidget {
  final List<dynamic> completedLessons;
  final List<CourseUnit> allUnits;

  const DailyChallengePage({
    super.key,
    required this.completedLessons,
    required this.allUnits,
  });

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage>
    with SingleTickerProviderStateMixin {
  // Audio & Speech items
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  String _recognizedWords = '';

  // Challenge questions list
  List<DailyChallengeQuestion> _questions = [];
  bool _isLoading = true;

  // Active state
  int _currentQ = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _speakingCorrect = false;
  int _score = 0;
  final List<bool> _results = [];
  bool _alreadyCompletedToday = false;

  // Quote item
  late String _quoteCh;
  late String _quotePy;
  late String _quoteEn;
  late String _quoteMs;

  // Animations
  late AnimationController _animController;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Check if daily challenge has already been completed today
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _alreadyCompletedToday = widget.completedLessons.contains('daily_challenge_$todayString');

    _initTts();
    _initSpeech();
    _generateDailyChallenge();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _animController.dispose();
    super.dispose();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("zh-CN");
    await _flutterTts.setSpeechRate(0.45);
  }

  void _initSpeech() async {
    try {
      _speechInitialized = await _speechToText.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  // Generate Date-Seeded Challenge
  void _generateDailyChallenge() {
    // 1. Establish date seed
    final now = DateTime.now();
    final dateSeed = now.year * 10000 + now.month * 100 + now.day;
    final random = math.Random(dateSeed);

    // 2. Extract vocabulary from course units
    final List<ChallengeVocab> allVocab = [];
    for (var unit in widget.allUnits) {
      for (var lesson in unit.lessons) {
        for (var item in lesson.items) {
          if (item.type == LessonType.vocabulary) {
            allVocab.add(
              ChallengeVocab(
                chinese: item.chinese,
                pinyin: item.pinyin,
                english: item.english,
                lessonId: lesson.id,
              ),
            );
          }
        }
      }
    }

    // De-duplicate vocabulary
    final uniqueVocabSet = <String, ChallengeVocab>{};
    for (var v in allVocab) {
      uniqueVocabSet[v.chinese] = v;
    }
    final uniqueVocab = uniqueVocabSet.values.toList();

    // If vocab pool is absolutely empty, provide fallback introductory vocabulary
    if (uniqueVocab.isEmpty) {
      uniqueVocab.addAll([
        ChallengeVocab(chinese: '你好', pinyin: 'Nǐ hǎo', english: 'Hello', lessonId: 'fallback'),
        ChallengeVocab(chinese: '谢谢', pinyin: 'Xiè xiè', english: 'Thank You', lessonId: 'fallback'),
        ChallengeVocab(chinese: '早上好', pinyin: 'Zǎo shang hǎo', english: 'Good morning', lessonId: 'fallback'),
        ChallengeVocab(chinese: '再见', pinyin: 'Zài jiàn', english: 'Goodbye', lessonId: 'fallback'),
        ChallengeVocab(chinese: '对不起', pinyin: 'Duì bù qǐ', english: 'Sorry', lessonId: 'fallback'),
      ]);
    }

    // Sort to guarantee absolute stability across date-seed shuffling
    uniqueVocab.sort((a, b) => a.chinese.compareTo(b.chinese));

    // 3. Separate completed vocabulary for repetition
    final List<ChallengeVocab> completedVocab = uniqueVocab
        .where((v) => widget.completedLessons.contains(v.lessonId))
        .toList();
    final List<ChallengeVocab> otherVocab = uniqueVocab
        .where((v) => !widget.completedLessons.contains(v.lessonId))
        .toList();

    // Deterministic shuffle with seed
    void seededShuffle(List list) {
      for (var i = list.length - 1; i > 0; i--) {
        var n = random.nextInt(i + 1);
        var temp = list[i];
        list[i] = list[n];
        list[n] = temp;
      }
    }

    seededShuffle(completedVocab);
    seededShuffle(otherVocab);
    seededShuffle(uniqueVocab);

    // 4. Select exactly 5 vocabulary words
    final List<ChallengeVocab> selectedVocab = [];
    if (completedVocab.isNotEmpty) {
      // Prioritize completed vocabulary for spaced curation
      final takeCount = math.min(4, completedVocab.length);
      selectedVocab.addAll(completedVocab.take(takeCount));
      // Backfill with other vocabulary to sum to 5
      final needed = 5 - selectedVocab.length;
      if (needed > 0) {
        selectedVocab.addAll(otherVocab.take(needed));
      }
    } else {
      // No completed lessons yet: take first 5 from general pool
      selectedVocab.addAll(uniqueVocab.take(5));
    }

    // Final safety backfill
    if (selectedVocab.length < 5) {
      for (var v in uniqueVocab) {
        if (!selectedVocab.contains(v)) {
          selectedVocab.add(v);
          if (selectedVocab.length == 5) break;
        }
      }
    }

    // 5. Generate multiple-choice options and randomize Challenge Type
    final List<DailyChallengeQuestion> generatedQuestions = [];
    for (var vocab in selectedVocab) {
      // Assign randomized ChallengeType
      final typeIndex = random.nextInt(ChallengeType.values.length);
      final challengeType = ChallengeType.values[typeIndex];

      List<String> options = [];
      int correctIndex = -1;

      if (challengeType != ChallengeType.speaking) {
        // Generate distractor options
        final correctText = (challengeType == ChallengeType.pinyin)
            ? vocab.pinyin
            : vocab.english;

        final allDistractorPool = uniqueVocab
            .map((v) => (challengeType == ChallengeType.pinyin) ? v.pinyin : v.english)
            .where((val) => val != correctText && val.isNotEmpty)
            .toSet()
            .toList();

        // seeded shuffle pool
        seededShuffle(allDistractorPool);

        final distractors = allDistractorPool.take(3).toList();
        while (distractors.length < 3) {
          distractors.add(distractors.isEmpty ? 'Not Sure' : '${distractors.first} Extra');
        }

        options = [correctText, ...distractors];
        // Shuffle options deterministically
        seededShuffle(options);
        correctIndex = options.indexOf(correctText);
      }

      generatedQuestions.add(
        DailyChallengeQuestion(
          vocab: vocab,
          type: challengeType,
          options: options,
          correctIndex: correctIndex,
        ),
      );
    }

    // 6. Set gorgeous motivational quote of the day deterministically
    final quotes = [
      {
        'ch': '一步一个脚印',
        'py': 'Yī bù yīgè jiǎoyìn',
        'en': 'Every step leaves a footprint. Progress comes from steady, persistent effort.',
        'ms': 'Setiap langkah meninggalkan jejak. Kemajuan datang daripada usaha yang gigih dan berterusan.',
      },
      {
        'ch': '千里之行，始于足下',
        'py': 'Qiānlǐ zhī xíng, shǐyú zúxià',
        'en': 'A journey of a thousand miles begins with a single step.',
        'ms': 'Perjalanan seribu batu bermula dengan satu langkah.',
      },
      {
        'ch': '活到老，学到老',
        'py': 'Huó dào lǎo, xué dào lǎo',
        'en': 'Never too old to learn. Learning is a lifelong adventure.',
        'ms': 'Tidak pernah terlalu tua untuk belajar. Pembelajaran adalah pengembaraan sepanjang hayat.',
      },
      {
        'ch': '熟能生巧',
        'py': 'Shúnéngshēngqiǎo',
        'en': 'Practice makes perfect. Skills grow through repetition.',
        'ms': 'Alah bisa tegal biasa. Kemahiran bertumbuh melalui latihan.',
      },
    ];
    final selectedQuote = quotes[random.nextInt(quotes.length)];

    setState(() {
      _questions = generatedQuestions;
      _quoteCh = selectedQuote['ch']!;
      _quotePy = selectedQuote['py']!;
      _quoteEn = selectedQuote['en']!;
      _quoteMs = selectedQuote['ms']!;
      _isLoading = false;
    });

    // Auto-trigger audio if the first question is a listening question
    if (generatedQuestions.isNotEmpty &&
        generatedQuestions.first.type == ChallengeType.listening) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _playTts(generatedQuestions.first.vocab.chinese);
      });
    }
  }

  // Play Speech TTS
  Future<void> _playTts(String text) async {
    if (_isPlayingAudio) return;
    setState(() => _isPlayingAudio = true);
    _animController.repeat();
    await _flutterTts.speak(text);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isPlayingAudio = false);
      _animController.stop();
    }
  }

  // Select Multiple-Choice Option
  void _selectOption(int index) {
    if (_answered) return;
    final currentQuestion = _questions[_currentQ];
    final isCorrect = index == currentQuestion.correctIndex;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _results.add(isCorrect);
      if (isCorrect) _score++;
    });

    // Play pronunciation audio
    _playTts(currentQuestion.vocab.chinese);
  }

  // Trigger Oral Speaking Check
  void _startSpeaking() async {
    if (!_speechInitialized) {
      _initSpeech();
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedWords = '';
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedWords = result.recognizedWords;
          });

          // Check speech match with Chinese characters
          final target = _questions[_currentQ].vocab.chinese;
          final cleanTarget = target.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
          final cleanRecognized = result.recognizedWords.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');

          if (cleanRecognized.contains(cleanTarget) ||
              cleanTarget.contains(cleanRecognized) && cleanRecognized.isNotEmpty) {
            _speechToText.stop();
            setState(() {
              _isListening = false;
              _speakingCorrect = true;
              _answered = true;
              _results.add(true);
              _score++;
            });
            _playTts(target);
          }
        },
        localeId: "zh_CN",
      );
    } catch (e) {
      debugPrint('Speech listen failed: $e');
      setState(() => _isListening = false);
    }
  }

  // Self Verification Fallback for Speaking (so the user is never stuck)
  void _selfVerifySpeaking(bool isCorrect) {
    if (_answered) return;
    setState(() {
      _isListening = false;
      _speakingCorrect = isCorrect;
      _answered = true;
      _results.add(isCorrect);
      if (isCorrect) _score++;
    });
    _playTts(_questions[_currentQ].vocab.chinese);
  }

  // Transition to Next Challenge Question
  void _nextQuestion() {
    if (_currentQ < _questions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
        _speakingCorrect = false;
        _recognizedWords = '';
      });
      // Auto-trigger audio if next question is listening
      if (_questions[_currentQ].type == ChallengeType.listening) {
        Future.delayed(const Duration(milliseconds: 400), () {
          _playTts(_questions[_currentQ].vocab.chinese);
        });
      }
    } else {
      _saveProgressAndFinish();
    }
  }

  // Save Progress in Firestore & Streamline Streaks
  Future<void> _saveProgressAndFinish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSuccessScreen();
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayString = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    // Daily Challenge gives +50 XP bonus!
    const dailyXpReward = 50;

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};

      // Pull fresh data to check if already completed
      final userCompletedLessons = List<String>.from(data['completedLessons'] ?? []);
      final alreadyDoneToday = userCompletedLessons.contains('daily_challenge_$todayString');
      final lastActiveDate = data['lastActiveDate'] as String?;
      int currentStreak = data['currentStreak'] as int? ?? 0;

      final xpEarned = alreadyDoneToday ? 0 : dailyXpReward;

      // Streak update logic
      if (lastActiveDate == todayString) {
        // Streak is safe
      } else if (lastActiveDate == yesterdayString) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }

      // Prepare updates containing only pre-allowed user profile fields
      final updates = <String, dynamic>{
        'lastActiveDate': todayString,
        'currentStreak': currentStreak,
        'completedLessons': FieldValue.arrayUnion(['daily_challenge_$todayString']),
      };

      if (xpEarned > 0) {
        updates['xp'] = FieldValue.increment(xpEarned);
        updates['xpPoints'] = FieldValue.increment(xpEarned);
        updates['dailyActivity.$todayString'] = FieldValue.increment(xpEarned);
      }

      await docRef.update(updates);

      setState(() {
        _alreadyCompletedToday = alreadyDoneToday;
      });
    } catch (e) {
      debugPrint('Firestore save failed: $e');
    }

    _showSuccessScreen();
  }

  // Celebration Summary modal
  void _showSuccessScreen() {
    final double percentage = (_score / _questions.length) * 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Celebration Icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 52,
                      color: Color(0xFFFFB703),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Congratulations Banner
                  Text(
                    percentage >= 80 ? 'Amazing! 🎉' : 'Great! 🌟',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Daily Challenge Completed',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Score Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                          'Score',
                          '$_score / ${_questions.length}',
                          Icons.insights_rounded,
                          Colors.blue,
                        ),
                        Container(width: 1, height: 35, color: Colors.grey.shade300),
                        _buildSummaryStat(
                          'Reward',
                          _alreadyCompletedToday ? '+0 XP (Retake)' : '+50 XP',
                          Icons.bolt_rounded,
                          Colors.amber.shade700,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Premium Daily Quote Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFFF8F2), Colors.orange.shade50.withValues(alpha: 0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Icon(Icons.format_quote_rounded, color: Color(0xFFFFB703), size: 20),
                            Text(
                              'DAILY MOTIVATIONAL QUOTE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _quoteCh,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD32F2F),
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quotePy,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Divider(color: Colors.orange.shade200.withValues(alpha: 0.5), height: 1),
                        const SizedBox(height: 10),
                        Text(
                          _quoteMs,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _quoteEn,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Close Page
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Return to dashboard
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF57C00),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      'Back to Main Menu',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  // Quick Action Badges
  Widget _buildChallengeBadge(ChallengeType type) {
    String text = '';
    Color color = Colors.grey;
    IconData icon = Icons.help_outline;

    switch (type) {
      case ChallengeType.meaning:
        text = 'Word Meaning';
        color = const Color(0xFFD32F2F);
        icon = Icons.translate_rounded;
        break;
      case ChallengeType.pinyin:
        text = 'Pinyin Spelling';
        color = const Color(0xFF1976D2);
        icon = Icons.text_fields_rounded;
        break;
      case ChallengeType.listening:
        text = 'Listening Test';
        color = const Color(0xFF388E3C);
        icon = Icons.volume_up_rounded;
        break;
      case ChallengeType.speaking:
        text = 'Speaking Test';
        color = const Color(0xFF7B1FA2);
        icon = Icons.mic_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Interactive Custom Dots Progress Panel
  Widget _buildStepIndicators() {
    return Row(
      children: List.generate(_questions.length, (index) {
        final isCurrent = index == _currentQ;
        final isPassed = index < _currentQ;
        Color color = Colors.grey.shade300;
        Widget child = const SizedBox.shrink();

        if (isCurrent) {
          color = const Color(0xFFF57C00);
          child = Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );
        } else if (isPassed) {
          final isCorrect = _results[index];
          color = isCorrect ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
          child = Icon(
            isCorrect ? Icons.check : Icons.close,
            size: 10,
            color: Colors.white,
          );
        }

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF57C00).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Center(child: child),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFF57C00)),
              SizedBox(height: 16),
              Text(
                'Assembling your Daily Challenge...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentQ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        title: const Text(
          'Daily Challenge',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFFBF8),
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseAuth.instance.currentUser == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
              builder: (context, snapshot) {
                final streak = (snapshot.data?.data()?['currentStreak'] ?? 0) as int;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '🔥',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak Days',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Replay alert warning banner
            if (_alreadyCompletedToday)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Daily challenge completed today. You can retake it to review, but no additional XP will be awarded.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Elegant progress bar & custom step dots
            _buildStepIndicators(),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Main Challenge Card
                    Card(
                      elevation: 4,
                      shadowColor: Colors.orange.shade50.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildChallengeBadge(question.type),
                            const SizedBox(height: 24),

                            // Challenge Instruction
                            Text(
                              question.type == ChallengeType.listening
                                  ? 'Listen to the pronunciation and select the correct meaning:'
                                  : question.type == ChallengeType.speaking
                                      ? 'Say this phrase aloud:'
                                      : question.type == ChallengeType.pinyin
                                          ? 'Choose the correct Pinyin spelling for:'
                                          : 'What is the correct translation for:',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Large Target characters & speaker icon for pronunciation
                            if (question.type != ChallengeType.listening) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    question.vocab.chinese,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F),
                                      letterSpacing: 2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    onPressed: () => _playTts(question.vocab.chinese),
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      color: Color(0xFFD32F2F),
                                      size: 24,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFEBEE),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    tooltip: 'Dengar sebutan',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Pinyin (only shown under speaking, or as hints on vocab meaning)
                            if (question.type == ChallengeType.speaking) ...[
                              Text(
                                question.vocab.pinyin,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(${question.vocab.english})',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else if (question.type == ChallengeType.listening) ...[
                              // Pulsing volume icon
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _playTts(question.vocab.chinese),
                                child: AnimatedBuilder(
                                  animation: _animController,
                                  builder: (context, child) {
                                    return Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        shape: BoxShape.circle,
                                        boxShadow: _isPlayingAudio
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3 * (1 - _animController.value)),
                                                  blurRadius: 10 + 20 * _animController.value,
                                                  spreadRadius: 5 + 15 * _animController.value,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 64,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _playTts(question.vocab.chinese),
                                icon: const Icon(Icons.replay_rounded, size: 16),
                                label: const Text('Play Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE8F5E9),
                                  foregroundColor: const Color(0xFF2E7D32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Display Multiple-Choice Options
                    if (question.type != ChallengeType.speaking) ...[
                      Column(
                        children: question.options.asMap().entries.map((e) {
                          final optionIdx = e.key;
                          final optionText = e.value;
                          final isSelected = _selectedAnswer == optionIdx;
                          final isCorrect = optionIdx == question.correctIndex;

                          Color cardBg = Colors.white;
                          Color borderCol = Colors.grey.shade200;
                          Color textCol = Colors.black87;
                          Widget? trailing;

                          if (_answered) {
                            if (isCorrect) {
                              cardBg = const Color(0xFFE8F5E9);
                              borderCol = const Color(0xFF81C784);
                              textCol = const Color(0xFF1B5E20);
                              trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF388E3C));
                            } else if (isSelected) {
                              cardBg = const Color(0xFFFFEBEE);
                              borderCol = const Color(0xFFE57373);
                              textCol = const Color(0xFFB71C1C);
                              trailing = const Icon(Icons.cancel_rounded, color: Color(0xFFD32F2F));
                            } else {
                              cardBg = Colors.grey.shade50;
                              borderCol = Colors.grey.shade100;
                              textCol = Colors.grey.shade400;
                            }
                          } else if (isSelected) {
                            cardBg = const Color(0xFFFFF3E0);
                            borderCol = const Color(0xFFFFB74D);
                          }

                          final letter = String.fromCharCode(65 + optionIdx); // A, B, C, D

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: _answered ? null : () => _selectOption(optionIdx),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderCol, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Option Indicator Badge
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _answered
                                            ? (isCorrect
                                                ? const Color(0xFF2E7D32).withValues(alpha: 0.2)
                                                : isSelected
                                                    ? const Color(0xFFC62828).withValues(alpha: 0.2)
                                                    : Colors.grey.shade200)
                                            : Colors.orange.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _answered
                                                ? (isCorrect
                                                    ? const Color(0xFF2E7D32)
                                                    : isSelected
                                                        ? const Color(0xFFC62828)
                                                        : Colors.grey.shade600)
                                                : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textCol,
                                        ),
                                      ),
                                    ),
                                    if (trailing != null) trailing,
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    ] else ...[
                      // Speaking Challenge Panel
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white,
                        borderOnForeground: true,
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              if (_isListening) ...[
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.graphic_eq_rounded, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text(
                                      'Listening to pronunciation...',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_recognizedWords.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Heard: "$_recognizedWords"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],

                              // Glowing Mic Button
                              GestureDetector(
                                onTap: _answered ? null : _startSpeaking,
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? Colors.red.shade100
                                        : _answered
                                            ? Colors.grey.shade100
                                            : Colors.purple.shade50,
                                    shape: BoxShape.circle,
                                    boxShadow: _isListening
                                        ? [
                                            BoxShadow(
                                              color: Colors.red.withValues(alpha: 0.3),
                                              blurRadius: 15,
                                              spreadRadius: 4,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                    size: 48,
                                    color: _isListening
                                        ? Colors.red.shade700
                                        : _answered
                                            ? Colors.grey
                                            : Colors.purple.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _answered
                                    ? 'Congratulations! Pronunciation verified.'
                                    : _isListening
                                        ? 'Tap the red button to stop recording'
                                        : 'Press the microphone & speak',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 10),

                              // Self Verification Row (Fallback for simulator / no mic permission)
                              if (!_answered) ...[
                                Text(
                                  'Microphone not working? Please self-verify your pronunciation:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _selfVerifySpeaking(false),
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        label: const Text('Fail'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(color: Colors.red.shade200),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _selfVerifySpeaking(true),
                                        icon: const Icon(Icons.check_rounded, size: 16),
                                        label: const Text('Correct Pronunciation'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7B1FA2),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _speakingCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _speakingCorrect ? Icons.check_circle : Icons.cancel,
                                        color: _speakingCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _speakingCorrect ? 'Correct Pronunciation!' : 'Try again next time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _speakingCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ],
                          ),
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ),

            // Navigation Button Row
            const SizedBox(height: 16),
            if (_answered)
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  foregroundColor: Colors.white,
                  shadowColor: const Color(0xFFF57C00).withValues(alpha: 0.3),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentQ == _questions.length - 1 ? 'View Results' : 'Next Question',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Please Answer the Question',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
