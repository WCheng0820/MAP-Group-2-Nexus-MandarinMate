import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tutor_generate_unit_page.dart';
import 'tutor_edit_vocabulary_page.dart';

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
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Manage Vocabulary Units'),
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
          ? const Center(child: Text('Please log in to manage units.'))
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
                  return Center(child: Text('Error: ${snapshot.error}'));
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
                  return const Center(child: Text('No units created yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final title = doc['title'] ?? 'Untitled Unit';
                    final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
                    final docId = doc.id;

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
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
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Created: ${createdAt.toString().split('.')[0]}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
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
                                    label: const Text('Vocabulary'),
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
                                    label: const Text('Edit'),
                                    onPressed: () => _showEditDialog(context, docId, title),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
          title: const Text('Edit Unit Title'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Unit Title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
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
                    const SnackBar(content: Text('Unit updated successfully.')),
                  );
                }
              },
              child: const Text('Update'),
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
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                    const SnackBar(content: Text('Unit deleted successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting unit: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
                  leading: const Icon(Icons.add_circle, color: _green),
                  title: const Text('Generate with AI'),
                  subtitle: const Text('Let AI create vocabulary from a title'),
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
