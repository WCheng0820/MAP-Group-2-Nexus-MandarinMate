import 'package:flutter/material.dart';
import '../../../flashcards/presentation/pages/flashcard_game_page.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/features/lessons/presentation/pages/vocab_lesson_page.dart';
import 'package:mandarinmate/features/lessons/presentation/pages/quiz_page.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Widget _materialCard(BuildContext context, LearningMaterial material) {
    final color = _materialColor(material.type);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_materialIcon(material.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _materialLabel(material.type),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (material.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              material.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
          if (material.fileName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              material.fileName,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openMaterial(context, material),
              icon: Icon(_materialActionIcon(material.type)),
              label: Text(_materialActionLabel(material.type)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _materialIcon(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return Icons.picture_as_pdf_outlined;
      case LearningMaterialType.video:
        return Icons.video_library_outlined;
      case LearningMaterialType.article:
      default:
        return Icons.article_outlined;
    }
  }

  IconData _materialActionIcon(String type) {
    switch (type) {
      case LearningMaterialType.video:
        return Icons.play_circle_outline;
      case LearningMaterialType.pdf:
        return Icons.open_in_new;
      case LearningMaterialType.article:
      default:
        return Icons.menu_book_outlined;
    }
  }

  String _materialLabel(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return 'PDF Reference';
      case LearningMaterialType.video:
        return 'Video Lesson';
      case LearningMaterialType.article:
      default:
        return 'Article';
    }
  }

  String _materialActionLabel(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return 'Open PDF';
      case LearningMaterialType.video:
        return 'Watch Video';
      case LearningMaterialType.article:
      default:
        return 'Read Article';
    }
  }

  Color _materialColor(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return const Color(0xFFC62828);
      case LearningMaterialType.video:
        return const Color(0xFF6A1B9A);
      case LearningMaterialType.article:
      default:
        return const Color(0xFF1565C0);
    }
  }

  Future<void> _openMaterial(
    BuildContext context,
    LearningMaterial material,
  ) async {
    final uri = Uri.tryParse(material.url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material link is invalid.')),
      );
      return;
    }

    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material could not be opened.')),
      );
    }
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
                      if (unit.materials.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _badge('${unit.materials.length} materials'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (unit.materials.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Learning Materials',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: unit.materials
                    .map((material) => _materialCard(context, material))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Choose an Activity',
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
                  title: 'Vocabulary',
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
                  title: 'Quiz',
                  subtitle: 'Test knowledge',
                  color: const Color(0xFFC62828),
                  onTap: () {
                    if (quizQuestions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No vocabulary is available for this quiz.',
                          ),
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
                  title: 'Pronunciation',
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
