import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tutor_create_flashcards_page.dart';
import 'tutor_edit_flashcards_page.dart';

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
      backgroundColor: const Color(0xFFFFF9F5),
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Manage Flashcards'),
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
          ? const Center(child: Text('Please log in to manage flashcards.'))
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
                  return Center(child: Text('Error: ${snapshot.error}'));
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No flashcard sets created yet. Tap + to add one.'),
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
                    final title = data['title'] ?? 'Untitled Level';
                    final description = data['description'] ?? '';
                    final docId = doc.id;

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
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
                                              'Level $levelNumber',
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
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
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
                                            color: Colors.grey.shade600,
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
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
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
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle, color: _orange),
                  title: const Text('Add New Flashcard Set'),
                  subtitle: const Text('Create a new flashcard set for a level'),
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
        title: const Text('Delete Flashcard Set'),
        content: Text('Are you sure you want to delete "$title"? All cards will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                    const SnackBar(content: Text('Flashcard set deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
