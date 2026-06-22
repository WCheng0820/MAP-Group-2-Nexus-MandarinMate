import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class TutorEditVocabularyPage extends StatefulWidget {
  final String unitDocId;
  final String unitTitle;

  const TutorEditVocabularyPage({
    required this.unitDocId,
    required this.unitTitle,
    super.key,
  });

  @override
  State<TutorEditVocabularyPage> createState() =>
      _TutorEditVocabularyPageState();
}

class _TutorEditVocabularyPageState extends State<TutorEditVocabularyPage> {
  static const Color _green = Color(0xFF0F6E56);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text('Edit Vocabulary - ${widget.unitTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVocabDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => _showAddVocabDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .doc(widget.unitDocId)
            .collection('vocabulary')
            .orderBy('word')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final vocabDocs = snapshot.data?.docs ?? [];
          if (vocabDocs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No vocabulary items. Tap + to add one.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vocabDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = vocabDocs[index];
              final data = doc.data();
              final word = data['word'] ?? '';
              final meaning = data['meaning'] ?? '';
              final pronunciation = data['pronunciation'] ?? '';

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
                                Text(
                                  word,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.textDeep,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (pronunciation.isNotEmpty)
                                  Text(
                                    pronunciation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditVocabDialog(context, doc.id, data);
                                } else if (value == 'delete') {
                                  _confirmDeleteVocab(context, doc.id, word);
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
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meaning,
                        style: TextStyle(fontSize: 14, color: context.textDeep),
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

  void _showAddVocabDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final wordCtrl = TextEditingController();
        final meaningCtrl = TextEditingController();
        final pronunciationCtrl = TextEditingController();
        final listeningCtrl = TextEditingController();
        final exampleCtrl = TextEditingController();
        final exampleMeaningCtrl = TextEditingController();

        Widget vocabTextField(TextEditingController ctrl, String label, {bool isOptional = false}) {
          return TextField(
            controller: ctrl,
            style: TextStyle(color: context.textDeep),
            decoration: InputDecoration(
              labelText: isOptional ? '$label (Optional)' : label,
              labelStyle: TextStyle(color: context.textMuted),
              filled: true,
              fillColor: context.cardBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.borderTheme),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _green, width: 2),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text('Add Vocabulary', style: TextStyle(color: context.textDeep)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                vocabTextField(wordCtrl, 'Word (Mandarin)'),
                const SizedBox(height: 12),
                vocabTextField(pronunciationCtrl, 'Pronunciation (Pinyin)'),
                const SizedBox(height: 12),
                vocabTextField(meaningCtrl, 'Meaning'),
                const SizedBox(height: 12),
                vocabTextField(listeningCtrl, 'Listening Text', isOptional: true),
                const SizedBox(height: 12),
                vocabTextField(exampleCtrl, 'Example Sentence', isOptional: true),
                const SizedBox(height: 12),
                vocabTextField(exampleMeaningCtrl, 'Example Meaning', isOptional: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                wordCtrl.dispose();
                meaningCtrl.dispose();
                pronunciationCtrl.dispose();
                listeningCtrl.dispose();
                exampleCtrl.dispose();
                exampleMeaningCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (wordCtrl.text.trim().isEmpty) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Word is required')),
                    );
                  }
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('lessons')
                      .doc(widget.unitDocId)
                      .collection('vocabulary')
                      .add({
                    'word': wordCtrl.text.trim(),
                    'pronunciation': pronunciationCtrl.text.trim(),
                    'meaning': meaningCtrl.text.trim(),
                    'listeningText': listeningCtrl.text.trim(),
                    'exampleSentence': exampleCtrl.text.trim(),
                    'exampleMeaning': exampleMeaningCtrl.text.trim(),
                    'quizQuestion': '',
                    'quizOptions': [],
                    'correctAnswerIndex': 0,
                  });

                  if (dialogContext.mounted) {
                    wordCtrl.dispose();
                    meaningCtrl.dispose();
                    pronunciationCtrl.dispose();
                    listeningCtrl.dispose();
                    exampleCtrl.dispose();
                    exampleMeaningCtrl.dispose();
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Vocabulary added.')),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditVocabDialog(BuildContext context, String vocabId,
      Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final wordCtrl =
            TextEditingController(text: data['word'] ?? '');
        final meaningCtrl =
            TextEditingController(text: data['meaning'] ?? '');
        final pronunciationCtrl =
            TextEditingController(text: data['pronunciation'] ?? '');
        final listeningCtrl =
            TextEditingController(text: data['listeningText'] ?? '');
        final exampleCtrl =
            TextEditingController(text: data['exampleSentence'] ?? '');
        final exampleMeaningCtrl =
            TextEditingController(text: data['exampleMeaning'] ?? '');

        Widget vocabTextField(TextEditingController ctrl, String label, {bool isOptional = false}) {
          return TextField(
            controller: ctrl,
            style: TextStyle(color: context.textDeep),
            decoration: InputDecoration(
              labelText: isOptional ? '$label (Optional)' : label,
              labelStyle: TextStyle(color: context.textMuted),
              filled: true,
              fillColor: context.cardBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.borderTheme),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _green, width: 2),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text('Edit Vocabulary', style: TextStyle(color: context.textDeep)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                vocabTextField(wordCtrl, 'Word (Mandarin)'),
                const SizedBox(height: 12),
                vocabTextField(pronunciationCtrl, 'Pronunciation (Pinyin)'),
                const SizedBox(height: 12),
                vocabTextField(meaningCtrl, 'Meaning'),
                const SizedBox(height: 12),
                vocabTextField(listeningCtrl, 'Listening Text', isOptional: true),
                const SizedBox(height: 12),
                vocabTextField(exampleCtrl, 'Example Sentence', isOptional: true),
                const SizedBox(height: 12),
                vocabTextField(exampleMeaningCtrl, 'Example Meaning', isOptional: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                wordCtrl.dispose();
                meaningCtrl.dispose();
                pronunciationCtrl.dispose();
                listeningCtrl.dispose();
                exampleCtrl.dispose();
                exampleMeaningCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (wordCtrl.text.trim().isEmpty) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Word is required')),
                    );
                  }
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('lessons')
                      .doc(widget.unitDocId)
                      .collection('vocabulary')
                      .doc(vocabId)
                      .update({
                    'word': wordCtrl.text.trim(),
                    'pronunciation': pronunciationCtrl.text.trim(),
                    'meaning': meaningCtrl.text.trim(),
                    'listeningText': listeningCtrl.text.trim(),
                    'exampleSentence': exampleCtrl.text.trim(),
                    'exampleMeaning': exampleMeaningCtrl.text.trim(),
                  });

                  if (dialogContext.mounted) {
                    wordCtrl.dispose();
                    meaningCtrl.dispose();
                    pronunciationCtrl.dispose();
                    listeningCtrl.dispose();
                    exampleCtrl.dispose();
                    exampleMeaningCtrl.dispose();
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Vocabulary updated.')),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteVocab(
      BuildContext context, String vocabId, String word) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Delete Vocabulary', style: TextStyle(color: context.textDeep)),
        content: Text('Are you sure you want to delete "$word"?', style: TextStyle(color: context.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('lessons')
                    .doc(widget.unitDocId)
                    .collection('vocabulary')
                    .doc(vocabId)
                    .delete();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Vocabulary deleted.')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
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
