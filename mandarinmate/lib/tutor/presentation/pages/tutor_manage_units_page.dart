import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'tutor_generate_unit_page.dart';
import 'tutor_edit_vocabulary_page.dart';
import 'package:mandarinmate/utils/app_language.dart';

class TutorManageUnitsPage extends StatefulWidget {
  const TutorManageUnitsPage({super.key});

  @override
  State<TutorManageUnitsPage> createState() => _TutorManageUnitsPageState();
}

class _TutorManageUnitsPageState extends State<TutorManageUnitsPage> {
  static const Color _green = Color(0xFF0F6E56);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(AppLanguage.t('manage_vocab_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateMenu(context),
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? Center(child: Text(AppLanguage.t('tutor_login_manage_units')))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('lessons')
                  .where('createdBy', isEqualTo: user.uid)
                  .where('type', isEqualTo: 'vocab_unit')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('${AppLanguage.t('action_failed')}: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? const [];
                
                // Sort client-side by creation date (newest first)
                final sortedDocs = [...docs]
                  ..sort((a, b) {
                    final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    return bTime.compareTo(aTime);
                  });
                
                if (sortedDocs.isEmpty) {
                  return Center(child: Text(AppLanguage.t('no_units_created')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final title = doc['title'] ?? AppLanguage.t('untitled_unit');
                    final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
                    final docId = doc.id;

                    return Card(
                      elevation: 0,
                      color: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.borderTheme),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: context.textDeep,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 4),
                                          Text(
                                            '${AppLanguage.t('label_created')}: ${createdAt.toString().split('.')[0]}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.textMuted,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.book),
                                    label: Text(AppLanguage.t('vocabulary')),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TutorEditVocabularyPage(
                                              unitDocId: docId,
                                              unitTitle: title,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: Text(AppLanguage.t('edit')),
                                    onPressed: () => _showEditDialog(context, docId, title),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: Text(AppLanguage.t('delete'), style: const TextStyle(color: Colors.red)),
                                    onPressed: () => _showDeleteConfirmation(context, docId, title),
                                  ),
                                ],
                              ),
                            ),
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

  void _showEditDialog(BuildContext context, String docId, String currentTitle) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final titleController = TextEditingController(text: currentTitle);
        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(AppLanguage.t('edit_unit_title'), style: TextStyle(color: context.textDeep)),
          content: TextField(
            controller: titleController,
            style: TextStyle(color: context.textDeep),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: AppLanguage.t('unit_title_label'),
              labelStyle: TextStyle(color: context.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text(AppLanguage.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isEmpty) return;

                await FirebaseFirestore.instance
                    .collection('lessons')
                    .doc(docId)
                    .update({
                  'title': newTitle,
                  'normalizedTitle': newTitle.toLowerCase(),
                });

                if (mounted) {
                  titleController.dispose();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLanguage.t('unit_updated_success'))),
                  );
                }
              },
              child: Text(AppLanguage.t('update')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(AppLanguage.t('delete_unit_title'), style: TextStyle(color: context.textDeep)),
        content: Text(
          AppLanguage.t('delete_unit_confirm'),
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLanguage.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                // Try to delete all vocabulary items first
                try {
                  final vocabDocs = await FirebaseFirestore.instance
                      .collection('lessons')
                      .doc(docId)
                      .collection('vocabulary')
                      .get();

                  final batch = FirebaseFirestore.instance.batch();
                  for (final vDoc in vocabDocs.docs) {
                    batch.delete(vDoc.reference);
                  }
                  await batch.commit();
                } catch (e) {
                  // If vocabulary collection can't be read due to permissions,
                  // proceed with deleting the unit document directly
                  print('Warning: Could not delete vocabulary items: $e');
                }

                // Delete the unit document
                await FirebaseFirestore.instance
                    .collection('lessons')
                    .doc(docId)
                    .delete();

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLanguage.t('unit_deleted_success'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppLanguage.t('error_deleting_unit')}: $e')),
                  );
                }
              }
            },
            child: Text(AppLanguage.t('delete')),
          ),
        ],
      ),
    );
  }

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle, color: _green),
                  title: Text(
                    AppLanguage.t('ai_generate_unit'),
                    style: TextStyle(color: context.textDeep),
                  ),
                  subtitle: Text(
                    AppLanguage.t('ai_generate_desc'),
                    style: TextStyle(color: context.textMuted),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorGenerateUnitPage(),
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
}
