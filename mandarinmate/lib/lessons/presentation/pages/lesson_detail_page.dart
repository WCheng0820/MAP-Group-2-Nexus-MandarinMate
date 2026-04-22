import 'package:flutter/material.dart';
import '../../../flashcards/presentation/pages/flashcard_game_page.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/features/lessons/presentation/pages/vocab_lesson_page.dart';
import 'package:mandarinmate/features/lessons/presentation/pages/quiz_page.dart';

class LessonDetailPage extends StatelessWidget {
  final LessonUnit unit;
  final List<VocabItem> vocabItems;

  const LessonDetailPage({
    super.key,
    required this.unit,
    required this.vocabItems,
  });

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.amber,
        ),
      ),
    );
  }

  Widget _activityCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizQuestions = vocabItems.map((item) {
      final options = <String>[
        item.malay,
        item.english,
        'Tidak pasti',
        'Lain-lain',
      ];
      return QuizQuestion(
        question: 'Apa maksud "${item.chinese}"?',
        options: options,
        correctIndex: 0,
        type: 'vocab',
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Unit ${unit.unitNumber}: ${unit.title}'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.titleChinese,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unit.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _badge('+${unit.xpReward} XP'),
                      const SizedBox(width: 8),
                      _badge('${unit.totalLessons} lessons'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih Aktiviti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                _activityCard(
                  emoji: '📖',
                  title: 'Kosa Kata',
                  subtitle: 'Learn vocabulary',

                  color: const Color(0xFF1565C0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VocabLessonPage(unit: unit, vocabItems: vocabItems),
                      ),
                    );
                  },
                ),
                _activityCard(
                  emoji: '🃏',
                  title: 'Flashcards',
                  subtitle: 'Review vocab',
                  color: const Color(0xFF6A1B9A),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlashcardGamePage(
                          unit: unit,
                          vocabItems: vocabItems,
                        ),
                      ),
                    );
                  },
                ),
                _activityCard(
                  emoji: '❓',
                  title: 'Kuiz',
                  subtitle: 'Test knowledge',
                  color: const Color(0xFFC62828),
                  onTap: () {
                    if (quizQuestions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tiada kosa kata untuk kuiz.'),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            QuizPage(unit: unit, questions: quizQuestions),
                      ),
                    );
                  },
                ),
                _activityCard(
                  emoji: '🎤',
                  title: 'Sebutan',
                  subtitle: 'Practice speaking',
                  color: const Color(0xFF00695C),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VocabLessonPage(
                          unit: unit,
                          vocabItems: vocabItems,
                          focusAudio: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
