import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_create_lesson_page.dart';

class TutorLessonsPage extends StatelessWidget {
  const TutorLessonsPage({super.key});

  static const Color _green = Color(0xFF0F6E56);

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
            onPressed: user == null
                ? null
                : () {
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: user == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorCreateLessonPage(),
                  ),
                );
              },
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to manage lessons.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('lessons')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load lessons.'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No lessons yet. Add a new lesson.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lessonDoc = docs[index];
                    final data = lessonDoc.data();
                    final unitNumber = (data['unitNumber'] ?? '').toString();
                    final title = (data['title'] ?? '').toString();
                    final titleChinese = (data['titleChinese'] ?? '')
                        .toString();
                    final description = (data['description'] ?? '').toString();
                    final materials = ((data['materials'] as List?) ?? const [])
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
                                        builder: (_) => TutorCreateLessonPage(
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
                                style: TextStyle(color: Colors.grey.shade600),
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
