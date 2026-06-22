import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'tutor_create_flashcards_page.dart';
import 'tutor_edit_flashcards_page.dart';
import 'package:mandarinmate/utils/app_language.dart';

class TutorManageFlashcardsPage extends StatefulWidget {
  const TutorManageFlashcardsPage({super.key});

  @override
  State<TutorManageFlashcardsPage> createState() =>
      _TutorManageFlashcardsPageState();
}

class _TutorManageFlashcardsPageState extends State<TutorManageFlashcardsPage> {
  static const Color _orange = Color(0xFFFF8A21);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: Text(AppLanguage.t('manage_flashcards')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateMenu(context),
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? Center(child: Text(AppLanguage.t('tutor_login_manage_flashcards')))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .where('createdBy', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('${AppLanguage.t('action_failed')}: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? const [];

                // Sort client-side by level number
                final sortedDocs = [...docs]
                  ..sort((a, b) {
                    final aLevel = (a['levelNumber'] as num?)?.toInt() ?? 0;
                    final bLevel = (b['levelNumber'] as num?)?.toInt() ?? 0;
                    return aLevel.compareTo(bLevel);
                  });

                if (sortedDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(AppLanguage.t('no_flashcards_created')),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data();
                    final levelNumber = data['levelNumber'] ?? 0;
                    final title = data['title'] ?? AppLanguage.t('untitled_level');
                    final description = data['description'] ?? '';
                    final docId = doc.id;

                    return Card(
                      elevation: 0,
                      color: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.borderTheme),
                      ),
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
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${AppLanguage.t('level')} $levelNumber',
                                              style: const TextStyle(
                                                color: _orange,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: context.textDeep,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.textMuted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TutorEditFlashcardsPage(
                                                docId: docId,
                                                levelNumber: levelNumber,
                                                title: title,
                                                description: description,
                                              ),
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, docId, title);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, size: 18),
                                          const SizedBox(width: 8),
                                          Text(AppLanguage.t('edit')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, size: 18, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(AppLanguage.t('delete'), style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                  leading: const Icon(Icons.add_circle, color: _orange),
                  title: Text(
                    AppLanguage.t('add_new_flashcard_set'),
                    style: TextStyle(color: context.textDeep),
                  ),
                  subtitle: Text(
                    AppLanguage.t('create_set_desc'),
                    style: TextStyle(color: context.textMuted),
                  ),
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(AppLanguage.t('delete_flashcard_set'), style: TextStyle(color: context.textDeep)),
        content: Text(
          AppLanguage.t('delete_flashcard_set_confirm'),
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
                // Delete all cards first
                final cardsSnapshot = await FirebaseFirestore.instance
                    .collection('flashcard_levels')
                    .doc(docId)
                    .collection('cards')
                    .get();

                final batch = FirebaseFirestore.instance.batch();
                for (final cardDoc in cardsSnapshot.docs) {
                  batch.delete(cardDoc.reference);
                }

                // Delete the level document
                batch.delete(
                  FirebaseFirestore.instance
                      .collection('flashcard_levels')
                      .doc(docId),
                );

                await batch.commit();

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLanguage.t('flashcard_set_deleted'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppLanguage.t('action_failed')}: $e')),
                  );
                }
              }
            },
            child: Text(AppLanguage.t('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
