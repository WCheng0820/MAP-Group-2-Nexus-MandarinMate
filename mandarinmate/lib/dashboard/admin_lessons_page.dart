import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/utils/app_language.dart';

class AdminLessonsPage extends StatelessWidget {
  const AdminLessonsPage({super.key});

  static const Color _primary = Color(0xFF6C3BFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          AppLanguage.t('manage_lessons'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: context.isDarkMode ? context.cardBg : _primary,
        foregroundColor: context.isDarkMode ? context.textDeep : Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openLessonForm(context),
        backgroundColor: context.isDarkMode ? Colors.purple.shade300 : _primary,
        foregroundColor: context.isDarkMode ? Colors.black : Colors.white,
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
            return Center(child: Text(AppLanguage.t('failed_load_lessons')));
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
                  Text(AppLanguage.t('no_lessons_yet')),
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
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderTheme),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  title: Text(
                    title.isEmpty ? AppLanguage.t('untitled_lesson') : title,
                    style: TextStyle(color: context.textDeep, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleChinese.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(titleChinese, style: TextStyle(color: context.textMuted)),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(color: context.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Badge(text: '${AppLanguage.t('label_unit_number')} $unitNumber'),
                          _Badge(text: '${AppLanguage.t('label_total_lessons')} $totalLessons'),
                          _Badge(text: '${AppLanguage.t('xp')} $xpReward'),
                          _Badge(text: '${AppLanguage.t('label_order')} $order'),
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
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(AppLanguage.t('edit'))),
                      PopupMenuItem(value: 'delete', child: Text(AppLanguage.t('delete'))),
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
                backgroundColor: context.cardBg,
                title: Text(
                  docId == null ? AppLanguage.t('add_lesson') : AppLanguage.t('edit_lesson'),
                  style: TextStyle(color: context.textDeep),
                ),
                content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _input(
                          context: context,
                          controller: titleCtrl,
                          label: AppLanguage.t('label_title'),
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: titleChineseCtrl,
                          label: AppLanguage.t('label_title_chinese'),
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: descriptionCtrl,
                          label: AppLanguage.t('label_description'),
                          maxLines: 3,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: unitCtrl,
                          label: AppLanguage.t('label_unit_number'),
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: totalLessonsCtrl,
                          label: AppLanguage.t('label_total_lessons'),
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: xpCtrl,
                          label: AppLanguage.t('label_xp_reward'),
                          isNumber: true,
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        _input(
                          context: context,
                          controller: orderCtrl,
                          label: AppLanguage.t('label_order'),
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
                  child: Text(AppLanguage.t('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(AppLanguage.t('save')),
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
              backgroundColor: context.cardBg,
              title: Text(AppLanguage.t('delete_lesson'), style: TextStyle(color: context.textDeep)),
              content: Text('${AppLanguage.t('delete_lesson_confirm')} ($title)', style: TextStyle(color: context.textMuted)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLanguage.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(AppLanguage.t('delete')),
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
      return AppLanguage.t('validation_required');
    }
    return null;
  }

  Widget _input({
    required BuildContext context,
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
      style: TextStyle(color: context.textDeep),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderTheme),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderTheme),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.isDarkMode ? Colors.purple.shade300 : _primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final badgeColor = context.isDarkMode ? Colors.purple.shade300 : const Color(0xFF6C3BFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
