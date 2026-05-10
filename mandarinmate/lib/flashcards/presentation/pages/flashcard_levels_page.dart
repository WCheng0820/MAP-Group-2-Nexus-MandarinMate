import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_game_page.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';

class FlashcardLevelsPage extends StatelessWidget {
  const FlashcardLevelsPage({super.key});

  static const int cardsPerLevel = 3;

  Future<void> _openLevel(
    BuildContext context, {
    required int levelNumber,
    required String title,
  }) async {
    final vocabSnapshot = await FirebaseFirestore.instance
        .collection('flashcard_levels')
        .doc(levelNumber.toString())
        .collection('cards')
        .orderBy('order')
        .limit(cardsPerLevel)
        .get();

    final vocab = vocabSnapshot.docs
        .map((doc) => VocabItem.fromMap(doc.data()))
        .where((item) => item.chinese.trim().isNotEmpty)
        .toList();

    if (!context.mounted) return;

    if (vocab.length < cardsPerLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Level $levelNumber needs at least $cardsPerLevel flashcards.',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardGamePage(
          levelNumber: levelNumber,
          levelTitle: title,
          vocabItems: vocab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Flashcard Levels'),
        backgroundColor: const Color(0xFF6C3BFF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('flashcard_levels')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C3BFF)),
            );
          }

          final docs =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty) {
            return const Center(child: Text('No flashcard levels found.'));
          }

          final units = docs
              .map((doc) {
                final data = doc.data();
                final levelNumber =
                    int.tryParse(doc.id) ??
                    (data['levelNumber'] as num?)?.toInt() ??
                    0;
                final title = (data['title'] ?? 'Flashcards').toString();
                final description = (data['description'] ?? '').toString();
                return _FlashcardLevel(
                  levelNumber: levelNumber,
                  title: title,
                  description: description,
                );
              })
              .where((level) => level.levelNumber > 0)
              .toList();

          if (units.isEmpty) {
            return const Center(child: Text('No flashcard levels found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openLevel(
                    context,
                    levelNumber: unit.levelNumber,
                    title: unit.title,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C3BFF,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.style_rounded,
                            color: Color(0xFF6C3BFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level ${unit.levelNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                unit.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (unit.description.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  unit.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '$cardsPerLevel flashcards',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FlashcardLevel {
  const _FlashcardLevel({
    required this.levelNumber,
    required this.title,
    required this.description,
  });

  final int levelNumber;
  final String title;
  final String description;
}
