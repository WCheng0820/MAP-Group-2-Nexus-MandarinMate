import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFFF6FBF8),
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
                                Text(
                                  word,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (pronunciation.isNotEmpty)
                                  Text(
                                    pronunciation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
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
                        style: const TextStyle(fontSize: 14),
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

        return AlertDialog(
          title: const Text('Add Vocabulary'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Word (Mandarin)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pronunciationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pronunciation (Pinyin)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meaningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meaning',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: listeningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Listening Text (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Example Sentence (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleMeaningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Example Meaning (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
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

        return AlertDialog(
          title: const Text('Edit Vocabulary'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Word (Mandarin)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pronunciationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pronunciation (Pinyin)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meaningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meaning',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: listeningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Listening Text (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Example Sentence (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleMeaningCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Example Meaning (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
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
        title: const Text('Delete Vocabulary'),
        content: Text('Are you sure you want to delete "$word"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
