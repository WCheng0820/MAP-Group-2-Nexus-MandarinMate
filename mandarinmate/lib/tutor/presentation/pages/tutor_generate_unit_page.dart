import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/tutor/services/vocabulary_draft_service.dart';
import 'tutor_manage_units_page.dart';

class TutorGenerateUnitPage extends StatefulWidget {
  const TutorGenerateUnitPage({super.key});

  @override
  State<TutorGenerateUnitPage> createState() => _TutorGenerateUnitPageState();
}

class _TutorGenerateUnitPageState extends State<TutorGenerateUnitPage> {
  static const Color _green = Color(0xFF0F6E56);
  final _titleController = TextEditingController();
  final _service = VocabularyDraftService();
  bool _loading = false;
  Map<String, dynamic>? _lastGenerated;
  String? _errorMessage;
  bool _showEditForm = false;
  late List<TextEditingController> _vocabWordControllers;
  late List<TextEditingController> _vocabMeaningControllers;
  late List<TextEditingController> _vocabPronounceControllers;

  @override
  void initState() {
    super.initState();
    _vocabWordControllers = [];
    _vocabMeaningControllers = [];
    _vocabPronounceControllers = [];
  }

  Future<bool> _titleAlreadyExists(String title) async {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance.collection('lessons').get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingTitle = (data['title'] ?? '').toString().trim().toLowerCase();
      final existingNormalized = (data['normalizedTitle'] ?? existingTitle).toString().trim().toLowerCase();
      if (existingTitle == normalized || existingNormalized == normalized) {
        return true;
      }
    }

    return false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _vocabWordControllers) {
      controller.dispose();
    }
    for (final controller in _vocabMeaningControllers) {
      controller.dispose();
    }
    for (final controller in _vocabPronounceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (await _titleAlreadyExists(title)) {
      setState(() {
        _errorMessage = 'A unit with this title already exists. Please choose a different title.';
        _lastGenerated = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _lastGenerated = null;
    });
    final result = await _service.generateUnitFromTitle(title, vocabCount: 3);
    setState(() {
      _lastGenerated = result;
      _loading = false;
      if (result == null) {
        _errorMessage = 'AI generation failed. Check console for details. Verify TUTOR_AI_API_KEY, TUTOR_AI_MODEL, and internet connection.';
      }
    });
  }

  Future<void> _saveToFirestore() async {
    if (_lastGenerated == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final title = (_lastGenerated!['title'] ?? _titleController.text).toString().trim();
      final subtitle = (_lastGenerated!['subtitle'] ?? '').toString().trim();
      final description = (_lastGenerated!['description'] ?? 'Generated vocabulary unit').toString().trim();
      final vocab = (_lastGenerated!['vocab'] as List? ?? const []);
      final summaryQuiz = _lastGenerated!['summaryQuiz'];

      if (await _titleAlreadyExists(title)) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'A unit with this title already exists. Please choose a different title.';
        });
        return;
      }

      // Get the next order number and unit number
      final allLessons = await FirebaseFirestore.instance.collection('lessons').get();
      int maxOrder = 3;
      int maxUnitNumber = 3; // Static units are 1, 2, 3. Dynamic starts at Unit 4.
      for (final doc in allLessons.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        if (type == 'vocab_unit') {
          final order = (data['order'] as num?)?.toInt() ?? 0;
          if (order > maxOrder) maxOrder = order;
          
          final uNum = (data['unitNumber'] as num?)?.toInt() ?? 0;
          if (uNum > maxUnitNumber) maxUnitNumber = uNum;
        }
      }

      final docRef = await FirebaseFirestore.instance.collection('lessons').add({
        'title': title,
        'normalizedTitle': title.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'type': 'vocab_unit',
        'unitNumber': maxUnitNumber + 1, // Proceed progressively to Unit 4, Unit 5, etc.
        'titleChinese': subtitle, // Map AI-generated subtitle here (e.g. 'Getting Around & Vehicles')
        'description': description, // Map AI-generated description here
        'totalLessons': vocab.length + 1, // vocab items + 1 summary quiz
        'xpReward': vocab.length * 30 + 100, // 30 XP per vocab item + 100 XP for summary quiz
        'order': maxOrder + 1,
        'isLocked': true,
        'requiredPreviousUnitId': '', // Will be set when managing progression
      });

      final batch = FirebaseFirestore.instance.batch();
      final vocabCol = docRef.collection('vocabulary');
      for (final item in vocab) {
        if (item is Map<String, dynamic>) {
          final vDoc = vocabCol.doc();
          batch.set(vDoc, {
            'word': item['word'] ?? '',
            'meaning': item['meaning'] ?? '',
            'pronunciation': item['pronunciation'] ?? '',
            'listeningText': item['listeningText'] ?? '',
            'exampleSentence': item['exampleSentence'] ?? '',
            'exampleMeaning': item['exampleMeaning'] ?? '',
            'quizQuestion': item['quizQuestion'] ?? '',
            'quizOptions': item['quizOptions'] ?? [],
            'correctAnswerIndex': item['correctAnswerIndex'] ?? 0,
          });
        }
      }

      // store summary quiz at top-level of the lesson doc
      batch.update(docRef, {'summaryQuiz': summaryQuiz ?? {}});
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit created successfully!')),
      );
      // Navigate to manage units page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TutorManageUnitsPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error saving unit: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save unit: $e')),
      );
    }
  }

  Widget _preview() {
    final data = _lastGenerated;
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('No generated preview yet.'),
      );
    }

    if (_showEditForm) {
      return _buildEditForm();
    }

    final vocab = (data['vocab'] as List? ?? const []);
    final quiz = data['summaryQuiz'];
    final previewTitle = (data['title'] ?? _titleController.text.trim()).toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Preview: $previewTitle', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (vocab.isEmpty)
          const Text('No vocabulary items were returned.'),
        for (final item in vocab.take(10))
          if (item is Map)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text('${item['word'] ?? ''} — ${item['pronunciation'] ?? ''} — ${item['meaning'] ?? ''}'),
            ),
        const SizedBox(height: 8),
        if (quiz is Map) ...[
          const Text('Summary Quiz:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text((quiz['question'] ?? '').toString().isEmpty ? 'No summary quiz returned.' : quiz['question'].toString()),
        ],
      ],
    );
  }

  Widget _buildEditForm() {
    final data = _lastGenerated;
    if (data == null) return const SizedBox.shrink();

    final vocab = (data['vocab'] as List? ?? const []);
    final previewTitle = (data['title'] ?? _titleController.text.trim()).toString().trim();

    // Initialize controllers if empty
    if (_vocabWordControllers.isEmpty && vocab.isNotEmpty) {
      for (final item in vocab) {
        if (item is Map) {
          _vocabWordControllers.add(TextEditingController(text: item['word'] ?? ''));
          _vocabMeaningControllers.add(TextEditingController(text: item['meaning'] ?? ''));
          _vocabPronounceControllers.add(TextEditingController(text: item['pronunciation'] ?? ''));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Edit Unit Before Saving:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        const Text('Title:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: previewTitle),
          enabled: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFF5F5F5),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Vocabulary Items:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._vocabWordControllers.asMap().entries.map((e) {
          final idx = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item ${idx + 1}:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _vocabWordControllers[idx],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Word',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        (_lastGenerated!['vocab'] as List)[idx]['word'] = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _vocabMeaningControllers[idx],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Meaning',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        (_lastGenerated!['vocab'] as List)[idx]['meaning'] = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _vocabPronounceControllers[idx],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Pronunciation',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        (_lastGenerated!['vocab'] as List)[idx]['pronunciation'] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('AI Generate Unit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Unit Title (Mandarin or English)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _titleController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Food')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('AI Generate'),
            ),
            Expanded(child: SingleChildScrollView(child: _preview())),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
            if (_lastGenerated != null) ...[
              const SizedBox(height: 12),
              if (!_showEditForm) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        onPressed: () {
                          setState(() {
                            _showEditForm = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                        onPressed: _saveToFirestore,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        onPressed: () {
                          setState(() {
                            _showEditForm = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                        onPressed: _saveToFirestore,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
