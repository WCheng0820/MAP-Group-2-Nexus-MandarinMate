import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_create_lesson_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_create_flashcards_page.dart';

class TutorLessonsPage extends StatelessWidget {
  const TutorLessonsPage({super.key});

  static const Color _green = Color(0xFF0F6E56);
  static const Color _purple = Color(0xFF6C3BFF);

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Manage Lessons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: user == null ? null : () => _openCreateMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: user == null ? null : () => _openCreateMenu(context),
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to manage lessons.'))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _sectionHeader('Your Lesson Units'),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('lessons')
                      .where('createdBy', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Failed to load your lessons.'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text('No lesson units created yet.'),
                      );
                    }

                    final sortedDocs = [...docs]
                      ..sort((a, b) {
                        final aOrder = _asInt(a.data()['order']);
                        final bOrder = _asInt(b.data()['order']);
                        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
                        final aUnit = _asInt(a.data()['unitNumber']);
                        final bUnit = _asInt(b.data()['unitNumber']);
                        return aUnit.compareTo(bUnit);
                      });

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lessonDoc = sortedDocs[index];
                        final data = lessonDoc.data();
                        final unitNumber = (data['unitNumber'] ?? '')
                            .toString();
                        final title = (data['title'] ?? '').toString();
                        final titleChinese = (data['titleChinese'] ?? '')
                            .toString();
                        final description = (data['description'] ?? '')
                            .toString();
                        final materials =
                            ((data['materials'] as List?) ?? const [])
                                .map(
                                  (item) => item is Map
                                      ? LearningMaterial.fromMap(
                                          Map<String, dynamic>.from(item),
                                        )
                                      : null,
                                )
                                .whereType<LearningMaterial>()
                                .toList();

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _green.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Unit $unitNumber',
                                        style: const TextStyle(
                                          color: _green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      color: _green,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TutorCreateLessonPage(
                                                  docId: lessonDoc.id,
                                                  existingData: data,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red.shade400,
                                      onPressed: () => _confirmDelete(
                                        context,
                                        lessonDoc.id,
                                        title,
                                        materials,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (titleChinese.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    titleChinese,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                if (materials.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        avatar: const Icon(
                                          Icons.attach_file,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${materials.length} material${materials.length == 1 ? '' : 's'}',
                                        ),
                                        backgroundColor: _green.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                _sectionHeader('Your Flashcards'),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('flashcard_levels')
                      .where('createdBy', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: CircularProgressIndicator(color: _purple),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Failed to load your flashcards.'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Text('No flashcard levels created yet.'),
                      );
                    }

                    final levels =
                        docs
                            .map((doc) {
                              final data = doc.data();
                              final levelNumber =
                                  int.tryParse(doc.id) ??
                                  _asInt(data['levelNumber']);
                              final title = (data['title'] ?? 'Flashcards')
                                  .toString();
                              final description = (data['description'] ?? '')
                                  .toString();
                              final order = _asInt(
                                data['order'],
                                fallback: levelNumber,
                              );
                              return _TutorFlashcardLevel(
                                docId: doc.id,
                                levelNumber: levelNumber,
                                order: order,
                                title: title,
                                description: description,
                              );
                            })
                            .where((level) => level.levelNumber > 0)
                            .toList()
                          ..sort((a, b) {
                            if (a.order != b.order)
                              return a.order.compareTo(b.order);
                            return a.levelNumber.compareTo(b.levelNumber);
                          });

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: levels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final level = levels[index];
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              collapsedIconColor: Colors.grey.shade700,
                              iconColor: Colors.grey.shade700,
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.style_rounded,
                                  color: _purple,
                                ),
                              ),
                              title: Text(
                                'Level ${level.levelNumber}: ${level.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: level.description.trim().isEmpty
                                  ? const Text('Tap to view cards')
                                  : Text(
                                      level.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              children: [
                                StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: FirebaseFirestore.instance
                                      .collection('flashcard_levels')
                                      .doc(level.docId)
                                      .collection('cards')
                                      .orderBy('order')
                                      .snapshots(),
                                  builder: (context, cardsSnapshot) {
                                    if (cardsSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: _purple,
                                          ),
                                        ),
                                      );
                                    }

                                    if (cardsSnapshot.hasError) {
                                      return const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: Text('Failed to load cards.'),
                                      );
                                    }

                                    final cardDocs =
                                        cardsSnapshot.data?.docs ?? [];
                                    if (cardDocs.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: Text(
                                          'No cards yet in this level.',
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: [
                                        for (final doc in cardDocs)
                                          ListTile(
                                            dense: true,
                                            title: Text(
                                              (doc.data()['chinese'] ?? '')
                                                  .toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            subtitle: Text(
                                              [
                                                    (doc.data()['pinyin'] ?? '')
                                                        .toString(),
                                                    (doc.data()['english'] ??
                                                            '')
                                                        .toString(),
                                                    (doc.data()['malay'] ?? '')
                                                        .toString(),
                                                  ]
                                                  .where(
                                                    (s) => s.trim().isNotEmpty,
                                                  )
                                                  .join(' • '),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded, color: _green),
                  title: const Text('Add Lesson Unit'),
                  subtitle: const Text(
                    'Create a new unit (title, order, materials)',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateLessonPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.style_rounded, color: _green),
                  title: const Text('Add Flashcards'),
                  subtitle: const Text('Add 3 flashcards to a level'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateFlashcardsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: _green),
                  title: const Text('AI Auto-Generate Lesson'),
                  subtitle: const Text('Type unit title to let AI generate vocabulary, listening & quiz'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateLessonPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String docId,
    String title,
    List<LearningMaterial> materials,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Lesson'),
              content: Text('Are you sure you want to delete "$title"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !context.mounted) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('lessons')
          .doc(docId)
          .delete();
      await _deleteStoredMaterials(materials);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson deleted successfully.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete lesson.')));
    }
  }

  Future<void> _deleteStoredMaterials(List<LearningMaterial> materials) async {
    for (final material in materials) {
      if (material.storagePath.isEmpty) {
        continue;
      }

      try {
        await FirebaseStorage.instance
            .ref()
            .child(material.storagePath)
            .delete();
      } catch (_) {
        // Ignore storage cleanup failures after the lesson document is deleted.
      }
    }
  }
}

class _TutorFlashcardLevel {
  const _TutorFlashcardLevel({
    required this.docId,
    required this.levelNumber,
    required this.order,
    required this.title,
    required this.description,
  });

  final String docId;
  final int levelNumber;
  final int order;
  final String title;
  final String description;
}
