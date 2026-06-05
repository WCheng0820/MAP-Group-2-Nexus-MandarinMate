import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TutorEditFlashcardsPage extends StatefulWidget {
  final String docId;
  final int levelNumber;
  final String title;
  final String description;

  const TutorEditFlashcardsPage({
    required this.docId,
    required this.levelNumber,
    required this.title,
    required this.description,
    super.key,
  });

  @override
  State<TutorEditFlashcardsPage> createState() =>
      _TutorEditFlashcardsPageState();
}

class _TutorEditFlashcardsPageState extends State<TutorEditFlashcardsPage> {
  static const Color _orange = Color(0xFFFF8A21);
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Edit Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .doc(widget.docId)
                  .update({
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Flashcard set updated.')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCardDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Edit title and description
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Set Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text(
              'Flashcards',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // List of cards
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .doc(widget.docId)
                  .collection('cards')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final cardDocs = snapshot.data?.docs ?? [];
                if (cardDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No cards yet. Tap + to add one.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cardDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = cardDocs[index];
                    final data = doc.data();
                    final chinese = data['chinese'] ?? '';
                    final pinyin = data['pinyin'] ?? '';
                    final english = data['english'] ?? '';
                    final malay = data['malay'] ?? '';

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
                                Text(
                                  'Card ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _orange,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditCardDialog(
                                        context,
                                        doc.id,
                                        chinese,
                                        pinyin,
                                        english,
                                        malay,
                                      );
                                    } else if (value == 'delete') {
                                      _confirmDeleteCard(context, doc.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              chinese,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$pinyin • $english • $malay',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
          ],
        ),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final chineseCtrl = TextEditingController();
        final pinyinCtrl = TextEditingController();
        final englishCtrl = TextEditingController();
        final malayCtrl = TextEditingController();

        return AlertDialog(
          title: const Text('Add New Card'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: chineseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chinese',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinyinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pinyin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: englishCtrl,
                  decoration: const InputDecoration(
                    labelText: 'English',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: malayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Malay',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                chineseCtrl.dispose();
                pinyinCtrl.dispose();
                englishCtrl.dispose();
                malayCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (chineseCtrl.text.trim().isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chinese field is required')),
                    );
                  }
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('flashcard_levels')
                    .doc(widget.docId)
                    .collection('cards')
                    .add({
                  'chinese': chineseCtrl.text.trim(),
                  'pinyin': pinyinCtrl.text.trim(),
                  'english': englishCtrl.text.trim(),
                  'malay': malayCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                });

                if (context.mounted) {
                  chineseCtrl.dispose();
                  pinyinCtrl.dispose();
                  englishCtrl.dispose();
                  malayCtrl.dispose();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card added successfully.')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCardDialog(BuildContext context, String cardId, String chinese,
      String pinyin, String english, String malay) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final chineseCtrl = TextEditingController(text: chinese);
        final pinyinCtrl = TextEditingController(text: pinyin);
        final englishCtrl = TextEditingController(text: english);
        final malayCtrl = TextEditingController(text: malay);

        return AlertDialog(
          title: const Text('Edit Card'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: chineseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chinese',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinyinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pinyin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: englishCtrl,
                  decoration: const InputDecoration(
                    labelText: 'English',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: malayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Malay',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                chineseCtrl.dispose();
                pinyinCtrl.dispose();
                englishCtrl.dispose();
                malayCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (chineseCtrl.text.trim().isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chinese field is required')),
                    );
                  }
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('flashcard_levels')
                    .doc(widget.docId)
                    .collection('cards')
                    .doc(cardId)
                    .update({
                  'chinese': chineseCtrl.text.trim(),
                  'pinyin': pinyinCtrl.text.trim(),
                  'english': englishCtrl.text.trim(),
                  'malay': malayCtrl.text.trim(),
                });

                if (context.mounted) {
                  chineseCtrl.dispose();
                  pinyinCtrl.dispose();
                  englishCtrl.dispose();
                  malayCtrl.dispose();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card updated.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCard(BuildContext context, String cardId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .doc(widget.docId)
                  .collection('cards')
                  .doc(cardId)
                  .delete();

              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card deleted.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
