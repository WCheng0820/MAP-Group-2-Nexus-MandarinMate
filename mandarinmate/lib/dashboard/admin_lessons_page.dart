import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminLessonsPage extends StatelessWidget {
  const AdminLessonsPage({super.key});

  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Admin Lessons'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openLessonForm(context),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load lessons.'));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: Colors.grey.shade500,
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  const Text('No lessons yet.'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = (data['title'] ?? '').toString();
              final titleChinese = (data['titleChinese'] ?? '').toString();
              final description = (data['description'] ?? '').toString();
              final unitNumber = _toInt(data['unitNumber']);
              final totalLessons = _toInt(data['totalLessons']);
              final xpReward = _toInt(data['xpReward']);
              final order = _toInt(data['order']);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  title: Text(
                    title.isEmpty ? 'Untitled lesson' : title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleChinese.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(titleChinese),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Badge(text: 'Unit $unitNumber'),
                          _Badge(text: 'Lessons $totalLessons'),
                          _Badge(text: 'XP $xpReward'),
                          _Badge(text: 'Order $order'),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _openLessonForm(context, docId: doc.id, existing: data);
                      }
                      if (value == 'delete') {
                        await _deleteLesson(context, doc.id, title);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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

  Future<void> _openLessonForm(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(
      text: (existing?['title'] ?? '').toString(),
    );
    final titleChineseCtrl = TextEditingController(
      text: (existing?['titleChinese'] ?? '').toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );
    final unitCtrl = TextEditingController(
      text: (existing?['unitNumber'] ?? '').toString(),
    );
    final totalLessonsCtrl = TextEditingController(
      text: (existing?['totalLessons'] ?? '').toString(),
    );
    final xpCtrl = TextEditingController(
      text: (existing?['xpReward'] ?? '').toString(),
    );
    final orderCtrl = TextEditingController(
      text: (existing?['order'] ?? '').toString(),
    );

    final save =
        await showDialog<bool>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: Text(docId == null ? 'Add Lesson' : 'Edit Lesson'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _input(
                          controller: titleCtrl,
                          label: 'Title',
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: titleChineseCtrl,
                          label: 'Title Chinese',
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: descriptionCtrl,
                          label: 'Description',
                          maxLines: 3,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: unitCtrl,
                          label: 'Unit Number',
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: totalLessonsCtrl,
                          label: 'Total Lessons',
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: xpCtrl,
                          label: 'XP Reward',
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          controller: orderCtrl,
                          label: 'Order',
                          isNumber: true,
                          validator: _required,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!save) {
      titleCtrl.dispose();
      titleChineseCtrl.dispose();
      descriptionCtrl.dispose();
      unitCtrl.dispose();
      totalLessonsCtrl.dispose();
      xpCtrl.dispose();
      orderCtrl.dispose();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final payload = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'titleChinese': titleChineseCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'unitNumber': int.tryParse(unitCtrl.text.trim()) ?? 0,
      'totalLessons': int.tryParse(totalLessonsCtrl.text.trim()) ?? 0,
      'xpReward': int.tryParse(xpCtrl.text.trim()) ?? 0,
      'order': int.tryParse(orderCtrl.text.trim()) ?? 0,
      'createdBy': user?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (docId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('lessons').add(payload);
      } else {
        await FirebaseFirestore.instance
            .collection('lessons')
            .doc(docId)
            .update(payload);
      }
    } finally {
      titleCtrl.dispose();
      titleChineseCtrl.dispose();
      descriptionCtrl.dispose();
      unitCtrl.dispose();
      totalLessonsCtrl.dispose();
      xpCtrl.dispose();
      orderCtrl.dispose();
    }
  }

  Future<void> _deleteLesson(
    BuildContext context,
    String id,
    String title,
  ) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Lesson'),
            content: Text('Delete "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) {
      return;
    }

    await FirebaseFirestore.instance.collection('lessons').doc(id).delete();
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6C3BFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C3BFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
