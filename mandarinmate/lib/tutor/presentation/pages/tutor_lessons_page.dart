import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/tutor/presentation/pages/tutor_create_lesson_page.dart';


class TutorLessonsPage extends StatefulWidget {
  const TutorLessonsPage({super.key});

  @override
  State<TutorLessonsPage> createState() => _TutorLessonsPageState();
}

class _TutorLessonsPageState extends State<TutorLessonsPage> {
  static const int _pageSize = 3;
  int _currentPage = 0;

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
      backgroundColor: const Color(0xFFF9F8FF),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        title: const Text('Manage Learning Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: user == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateLearningMaterialsPage(),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        onPressed: user == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorCreateLearningMaterialsPage(),
                  ),
                ),
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to manage learning materials.'))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _sectionHeader('Your Learning Materials'),
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
                        child: Text('Failed to load your learning materials.'),
                      );
                    }

                    // Client-side filter: exclude vocabulary units
                    final docs = (snapshot.data?.docs ?? [])
                        .where((doc) =>
                            (doc.data()['type'] ?? '').toString() !=
                            'vocab_unit')
                        .toList();

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text('No learning materials created yet.'),
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

                    // Client-side pagination: chunk sortedDocs into pages of size _pageSize
                    final pages = <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[];
                    for (var i = 0; i < sortedDocs.length; i += _pageSize) {
                      pages.add(sortedDocs.sublist(i, (i + _pageSize).clamp(0, sortedDocs.length)));
                    }
                    final totalPages = pages.isEmpty ? 1 : pages.length;
                    if (_currentPage >= totalPages) {
                      _currentPage = totalPages - 1;
                    }
                    final visibleDocs = pages.isEmpty ? <QueryDocumentSnapshot<Map<String, dynamic>>>[] : pages[_currentPage];

                    return Column(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visibleDocs.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final lessonDoc = visibleDocs[index];
                            final data = lessonDoc.data();
                            final unitNumber = (data['unitNumber'] ?? '').toString();
                            final title = (data['title'] ?? '').toString();
                            final titleChinese = (data['titleChinese'] ?? '').toString();
                            final description = (data['description'] ?? '').toString();
                            final materials = ((data['materials'] as List?) ?? const [])
                                .map((item) => item is Map ? LearningMaterial.fromMap(Map<String, dynamic>.from(item)) : null)
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
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _purple.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text('Set $unitNumber', style: const TextStyle(color: _purple, fontWeight: FontWeight.w700)),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          color: _purple,
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => TutorCreateLearningMaterialsPage(docId: lessonDoc.id, existingData: data)),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: Colors.red.shade400,
                                          onPressed: () => _confirmDelete(context, lessonDoc.id, title, materials),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                    if (titleChinese.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(titleChinese, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                    ],
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(description, style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                    if (materials.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Chip(
                                            avatar: const Icon(Icons.attach_file, size: 16),
                                            label: Text('${materials.length} material${materials.length == 1 ? '' : 's'}'),
                                            backgroundColor: _purple.withValues(alpha: 0.08),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Pagination controls
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('lessons')
                      .where('createdBy', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final allDocs = snapshot.data?.docs ?? [];
                    // Client-side filter: exclude vocabulary units
                    final docsCount = allDocs
                        .where((doc) =>
                            (doc.data()['type'] ?? '').toString() !=
                            'vocab_unit')
                        .length;
                    final totalPages = (docsCount / _pageSize).ceil();
                    if (totalPages <= 1) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          for (var i = 0; i < totalPages; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: i == _currentPage ? _purple : Colors.grey.shade200,
                                  foregroundColor: i == _currentPage ? Colors.white : Colors.black,
                                  minimumSize: const Size(40, 36),
                                ),
                                onPressed: () => setState(() => _currentPage = i),
                                child: Text('${i + 1}'),
                              ),
                            ),
                          IconButton(
                            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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
              title: const Text('Delete Learning Materials'),
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
        const SnackBar(content: Text('Learning materials deleted successfully.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete learning materials.')));
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
        // Ignore storage cleanup failures after the learning materials document is deleted.
      }
    }
  }
}
