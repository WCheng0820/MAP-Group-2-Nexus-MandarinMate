import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/services/notification_service.dart';


class TutorCreateFlashcardsPage extends StatefulWidget {
  const TutorCreateFlashcardsPage({super.key});

  @override
  State<TutorCreateFlashcardsPage> createState() =>
      _TutorCreateFlashcardsPageState();
}

class _TutorCreateFlashcardsPageState extends State<TutorCreateFlashcardsPage> {
  static const Color _orange = Color(0xFFFF8A21);
  static const int _cardsPerLevel = 3;

  final _levelNumberController = TextEditingController();
  final _levelTitleController = TextEditingController();
  final _levelDescriptionController = TextEditingController();

  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  late final List<TextEditingController> _chineseControllers;
  late final List<TextEditingController> _pinyinControllers;
  late final List<TextEditingController> _malayControllers;
  late final List<TextEditingController> _englishControllers;

  @override
  void initState() {
    super.initState();
    _chineseControllers = List.generate(
      _cardsPerLevel,
      (_) => TextEditingController(),
    );
    _pinyinControllers = List.generate(
      _cardsPerLevel,
      (_) => TextEditingController(),
    );
    _malayControllers = List.generate(
      _cardsPerLevel,
      (_) => TextEditingController(),
    );
    _englishControllers = List.generate(
      _cardsPerLevel,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _levelNumberController.dispose();
    _levelTitleController.dispose();
    _levelDescriptionController.dispose();
    for (final controller in _chineseControllers) {
      controller.dispose();
    }
    for (final controller in _pinyinControllers) {
      controller.dispose();
    }
    for (final controller in _malayControllers) {
      controller.dispose();
    }
    for (final controller in _englishControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again to continue.')),
      );
      return;
    }

    final levelNumber = int.tryParse(_levelNumberController.text.trim());
    if (levelNumber == null || levelNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid level number.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final levelDoc = FirebaseFirestore.instance
          .collection('flashcard_levels')
          .doc(levelNumber.toString());
      final cardsRef = levelDoc.collection('cards');

      final title = _levelTitleController.text.trim().isEmpty
          ? 'Flashcards'
          : _levelTitleController.text.trim();
      final description = _levelDescriptionController.text.trim();

      final batch = FirebaseFirestore.instance.batch();

      batch.set(levelDoc, <String, dynamic>{
        'levelNumber': levelNumber,
        'title': title,
        'description': description,
        'order': levelNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      }, SetOptions(merge: true));

      for (var i = 0; i < _cardsPerLevel; i++) {
        final docRef = cardsRef.doc();
        batch.set(docRef, <String, dynamic>{
          'chinese': _chineseControllers[i].text.trim(),
          'pinyin': _pinyinControllers[i].text.trim(),
          'malay': _malayControllers[i].text.trim(),
          'english': _englishControllers[i].text.trim(),
          'order': i + 1,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
        });
      }

      await batch.commit();

      await NotificationService.notifyAllStudents(
        title: '🃏 New Flashcards Available!',
        body: 'A new set of flashcards is available for Level $levelNumber: "$title"',
        type: 'flashcards',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $_cardsPerLevel flashcards successfully.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add flashcards: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFlashcardFields(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flashcard ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _chineseControllers[index],
            decoration: const InputDecoration(
              labelText: 'Chinese',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Chinese is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pinyinControllers[index],
            decoration: const InputDecoration(
              labelText: 'Pinyin',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Pinyin is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _malayControllers[index],
            decoration: const InputDecoration(
              labelText: 'Malay meaning',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Malay meaning is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _englishControllers[index],
            decoration: const InputDecoration(
              labelText: 'English meaning',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'English meaning is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Add Flashcards'),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to continue.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _levelNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Level number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid level number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _levelTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Level title (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _levelDescriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Level description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add $_cardsPerLevel flashcards',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _cardsPerLevel; i++)
                    _buildFlashcardFields(i),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Flashcards'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
