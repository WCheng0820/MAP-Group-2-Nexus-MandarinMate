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
              final titleText = _titleController.text.trim();
              final descText = _descriptionController.text.trim();
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              await FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .doc(widget.docId)
                  .update({
                'title': titleText,
                'description': descText,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Flashcard set updated.')),
              );

              if (context.mounted) {
                Navigator.pop(context);
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
      builder: (_) => _AddCardDialog(docId: widget.docId),
    );
  }

  void _showEditCardDialog(BuildContext context, String cardId, String chinese,
      String pinyin, String english, String malay) {
    showDialog(
      context: context,
      builder: (_) => _EditCardDialog(
        docId: widget.docId,
        cardId: cardId,
        chinese: chinese,
        pinyin: pinyin,
        english: english,
        malay: malay,
      ),
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await FirebaseFirestore.instance
                  .collection('flashcard_levels')
                  .doc(widget.docId)
                  .collection('cards')
                  .doc(cardId)
                  .delete();

              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Card deleted.')),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// standalone widget for clean lifecycle management of TextEditingControllers in Add Dialog
class _AddCardDialog extends StatefulWidget {
  final String docId;
  const _AddCardDialog({required this.docId});

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _chineseCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  final _englishCtrl = TextEditingController();
  final _malayCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _chineseCtrl.dispose();
    _pinyinCtrl.dispose();
    _englishCtrl.dispose();
    _malayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _chineseCtrl,
              decoration: const InputDecoration(
                labelText: 'Chinese',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinyinCtrl,
              decoration: const InputDecoration(
                labelText: 'Pinyin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _englishCtrl,
              decoration: const InputDecoration(
                labelText: 'English',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _malayCtrl,
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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveCard,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _saveCard() async {
    final chinese = _chineseCtrl.text.trim();
    final pinyin = _pinyinCtrl.text.trim();
    final english = _englishCtrl.text.trim();
    final malay = _malayCtrl.text.trim();

    if (chinese.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chinese field is required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('flashcard_levels')
          .doc(widget.docId)
          .collection('cards')
          .add({
        'chinese': chinese,
        'pinyin': pinyin,
        'english': english,
        'malay': malay,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'order': 0, // default order field
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Card added successfully.')),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error adding card: $e')),
      );
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// standalone widget for clean lifecycle management of TextEditingControllers in Edit Dialog
class _EditCardDialog extends StatefulWidget {
  final String docId;
  final String cardId;
  final String chinese;
  final String pinyin;
  final String english;
  final String malay;

  const _EditCardDialog({
    required this.docId,
    required this.cardId,
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.malay,
  });

  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  late TextEditingController _chineseCtrl;
  late TextEditingController _pinyinCtrl;
  late TextEditingController _englishCtrl;
  late TextEditingController _malayCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _chineseCtrl = TextEditingController(text: widget.chinese);
    _pinyinCtrl = TextEditingController(text: widget.pinyin);
    _englishCtrl = TextEditingController(text: widget.english);
    _malayCtrl = TextEditingController(text: widget.malay);
  }

  @override
  void dispose() {
    _chineseCtrl.dispose();
    _pinyinCtrl.dispose();
    _englishCtrl.dispose();
    _malayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _chineseCtrl,
              decoration: const InputDecoration(
                labelText: 'Chinese',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinyinCtrl,
              decoration: const InputDecoration(
                labelText: 'Pinyin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _englishCtrl,
              decoration: const InputDecoration(
                labelText: 'English',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _malayCtrl,
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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveCard,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveCard() async {
    final chinese = _chineseCtrl.text.trim();
    final pinyin = _pinyinCtrl.text.trim();
    final english = _englishCtrl.text.trim();
    final malay = _malayCtrl.text.trim();

    if (chinese.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chinese field is required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('flashcard_levels')
          .doc(widget.docId)
          .collection('cards')
          .doc(widget.cardId)
          .update({
        'chinese': chinese,
        'pinyin': pinyin,
        'english': english,
        'malay': malay,
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Card updated.')),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error updating card: $e')),
      );
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
