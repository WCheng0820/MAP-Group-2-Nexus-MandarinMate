import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mandarinmate/utils/app_theme.dart';

import '../../domain/vocabulary_entry.dart';
import '../../services/vocabulary_draft_service.dart';

class TutorVocabularyPage extends StatelessWidget {
  const TutorVocabularyPage({super.key});

  static const Color _green = Color(0xFF0F6E56);

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Manage Vocabulary'),
        actions: [
          IconButton(
            onPressed: user == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorVocabularyEditorPage(),
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: user == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorVocabularyEditorPage(),
                  ),
                );
              },
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to manage vocabulary.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('vocabulary_items')
                  .where('createdBy', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                final entries = docs
                    .map(
                      (doc) => TutorVocabularyEntry.fromMap(
                        doc.data(),
                        id: doc.id,
                      ),
                    )
                    .toList()
                  ..sort((a, b) {
                    final aOrder = _asInt(docs
                        .firstWhere((doc) => doc.id == a.id)
                        .data()['order']);
                    final bOrder = _asInt(docs
                        .firstWhere((doc) => doc.id == b.id)
                        .data()['order']);
                    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
                    return a.word.toLowerCase().compareTo(b.word.toLowerCase());
                  });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      'Vocabulary Bank',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textDeep),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create vocabulary with meaning, pronunciation, listening, and quiz data.',
                      style: TextStyle(color: context.textMuted),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.hasError)
                      const Text('Failed to load vocabulary items.')
                    else if (entries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderTheme),
                        ),
                        child: Text(
                          'No vocabulary entries created yet.',
                          style: TextStyle(color: context.textDeep),
                        ),
                      )
                    else
                      ...entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            elevation: 0,
                            color: context.cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: context.borderTheme),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.word,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: context.textDeep,
                                              ),
                                            ),
                                            if (entry.pronunciation.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                entry.pronunciation,
                                                style: TextStyle(
                                                  color: context.textMuted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        color: _green,
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TutorVocabularyEditorPage(entry: entry),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red.shade400,
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              backgroundColor: context.cardBg,
                                              title: Text('Delete vocabulary?', style: TextStyle(color: context.textDeep)),
                                              content: Text(
                                                'Delete "${entry.word}" from the vocabulary bank?',
                                                style: TextStyle(color: context.textMuted),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogContext, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.pop(dialogContext, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) return;
                                          await FirebaseFirestore.instance
                                              .collection('vocabulary_items')
                                              .doc(entry.id)
                                              .delete();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                   Text(
                                    entry.meaning,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textDeep),
                                  ),
                                  if (entry.listeningText.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Listening: ${entry.listeningText}',
                                      style: TextStyle(color: context.textMuted),
                                    ),
                                  ],
                                  if (entry.exampleSentence.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Example: ${entry.exampleSentence}',
                                      style: TextStyle(color: context.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        label: Text('Quiz options: ${entry.quizOptions.length}', style: TextStyle(color: context.textDeep)),
                                      ),
                                      Chip(
                                        label: Text('Source: ${entry.source}', style: TextStyle(color: context.textDeep)),
                                      ),
                                      if (entry.audioUrl.isNotEmpty)
                                        Chip(
                                          label: Text('Audio attached', style: TextStyle(color: context.textDeep)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class TutorVocabularyEditorPage extends StatefulWidget {
  const TutorVocabularyEditorPage({super.key, this.entry});

  final TutorVocabularyEntry? entry;

  @override
  State<TutorVocabularyEditorPage> createState() => _TutorVocabularyEditorPageState();
}

class _TutorVocabularyEditorPageState extends State<TutorVocabularyEditorPage> {
  static const Color _green = Color(0xFF0F6E56);

  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _meaningController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _listeningTextController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _exampleSentenceController = TextEditingController();
  final _exampleMeaningController = TextEditingController();
  final _quizQuestionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());

  int _correctAnswerIndex = 0;
  bool _isSaving = false;
  bool _isGenerating = false;

  final _draftService = VocabularyDraftService();

  bool get _isEditMode => widget.entry != null;

  bool _pinyinInCreator = true;
  bool _autoSaveDrafts = true;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _wordController.text = entry.word;
      _meaningController.text = entry.meaning;
      _pronunciationController.text = entry.pronunciation;
      _listeningTextController.text = entry.listeningText;
      _audioUrlController.text = entry.audioUrl;
      _exampleSentenceController.text = entry.exampleSentence;
      _exampleMeaningController.text = entry.exampleMeaning;
      _quizQuestionController.text = entry.quizQuestion;
      for (var i = 0; i < _optionControllers.length; i++) {
        if (i < entry.quizOptions.length) {
          _optionControllers[i].text = entry.quizOptions[i];
        }
      }
      _correctAnswerIndex = entry.correctAnswerIndex.clamp(0, 3);
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pinyinInCreator = prefs.getBool('pinyin_in_creator') ?? true;
        _autoSaveDrafts = prefs.getBool('auto_save_drafts') ?? true;
      });
      if (_autoSaveDrafts && !_isEditMode) {
        final savedWord = prefs.getString('tutor_draft_word') ?? '';
        final savedMeaning = prefs.getString('tutor_draft_meaning') ?? '';
        if (savedWord.isNotEmpty || savedMeaning.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRestoreDraftDialog(prefs, savedWord);
          });
        } else {
          _setupAutoSaveListeners();
        }
      }
    }
  }

  void _setupAutoSaveListeners() {
    _wordController.addListener(_onFieldChanged);
    _meaningController.addListener(_onFieldChanged);
    _pronunciationController.addListener(_onFieldChanged);
    _listeningTextController.addListener(_onFieldChanged);
    _exampleSentenceController.addListener(_onFieldChanged);
    _exampleMeaningController.addListener(_onFieldChanged);
    _quizQuestionController.addListener(_onFieldChanged);
    for (int i = 0; i < 4; i++) {
      _optionControllers[i].addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() async {
    if (!_autoSaveDrafts || _isEditMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tutor_draft_word', _wordController.text);
    await prefs.setString('tutor_draft_meaning', _meaningController.text);
    await prefs.setString('tutor_draft_pronunciation', _pronunciationController.text);
    await prefs.setString('tutor_draft_listeningText', _listeningTextController.text);
    await prefs.setString('tutor_draft_exampleSentence', _exampleSentenceController.text);
    await prefs.setString('tutor_draft_exampleMeaning', _exampleMeaningController.text);
    await prefs.setString('tutor_draft_quizQuestion', _quizQuestionController.text);
    for (int i = 0; i < 4; i++) {
      await prefs.setString('tutor_draft_quizOption$i', _optionControllers[i].text);
    }
    await prefs.setInt('tutor_draft_correctAnswerIndex', _correctAnswerIndex);
  }

  void _showRestoreDraftDialog(SharedPreferences prefs, String savedWord) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.restore_page_rounded, color: _green),
            const SizedBox(width: 10),
            Text('Unsaved Draft Found', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDeep)),
          ],
        ),
        content: Text(
          savedWord.isNotEmpty
              ? 'We found an autosaved draft for the word "$savedWord". Would you like to restore it and continue editing?'
              : 'We found an autosaved draft from your last session. Would you like to restore it and continue editing?',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearDraft(prefs);
              _setupAutoSaveListeners();
              Navigator.pop(ctx);
            },
            child: Text(
              'Discard Draft',
              style: TextStyle(
                color: context.isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _wordController.text = prefs.getString('tutor_draft_word') ?? '';
                _meaningController.text = prefs.getString('tutor_draft_meaning') ?? '';
                _pronunciationController.text = prefs.getString('tutor_draft_pronunciation') ?? '';
                _listeningTextController.text = prefs.getString('tutor_draft_listeningText') ?? '';
                _exampleSentenceController.text = prefs.getString('tutor_draft_exampleSentence') ?? '';
                _exampleMeaningController.text = prefs.getString('tutor_draft_exampleMeaning') ?? '';
                _quizQuestionController.text = prefs.getString('tutor_draft_quizQuestion') ?? '';
                for (int i = 0; i < 4; i++) {
                  _optionControllers[i].text = prefs.getString('tutor_draft_quizOption$i') ?? '';
                }
                _correctAnswerIndex = prefs.getInt('tutor_draft_correctAnswerIndex') ?? 0;
              });
              _setupAutoSaveListeners();
              Navigator.pop(ctx);
            },
            child: const Text('Restore Draft', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearDraft(SharedPreferences prefs) {
    prefs.remove('tutor_draft_word');
    prefs.remove('tutor_draft_meaning');
    prefs.remove('tutor_draft_pronunciation');
    prefs.remove('tutor_draft_listeningText');
    prefs.remove('tutor_draft_exampleSentence');
    prefs.remove('tutor_draft_exampleMeaning');
    prefs.remove('tutor_draft_quizQuestion');
    for (int i = 0; i < 4; i++) {
      prefs.remove('tutor_draft_quizOption$i');
    }
    prefs.remove('tutor_draft_correctAnswerIndex');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _pronunciationController.dispose();
    _listeningTextController.dispose();
    _audioUrlController.dispose();
    _exampleSentenceController.dispose();
    _exampleMeaningController.dispose();
    _quizQuestionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateDraft() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a vocabulary word first.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await _draftService.generateDraft(
        word: word,
        meaningHint: _meaningController.text.trim().isEmpty
            ? null
            : _meaningController.text.trim(),
      );

      _wordController.text = draft.word;
      if (_meaningController.text.trim().isEmpty) {
        _meaningController.text = draft.meaning;
      }
      if (_pinyinInCreator && _pronunciationController.text.trim().isEmpty) {
        _pronunciationController.text = draft.pronunciation;
      }
      if (_listeningTextController.text.trim().isEmpty) {
        _listeningTextController.text = draft.listeningText;
      }
      if (_exampleSentenceController.text.trim().isEmpty) {
        _exampleSentenceController.text = draft.exampleSentence;
      }
      if (_exampleMeaningController.text.trim().isEmpty) {
        _exampleMeaningController.text = draft.exampleMeaning;
      }
      if (_quizQuestionController.text.trim().isEmpty) {
        _quizQuestionController.text = draft.quizQuestion;
      }
      for (var i = 0; i < _optionControllers.length; i++) {
        if (_optionControllers[i].text.trim().isEmpty && i < draft.quizOptions.length) {
          _optionControllers[i].text = draft.quizOptions[i];
        }
      }
      _correctAnswerIndex = draft.correctAnswerIndex.clamp(0, 3);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated a ${draft.source} draft. Edit it before saving if needed.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate draft: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again to continue.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final entry = TutorVocabularyEntry(
        id: widget.entry?.id ?? '',
        word: _wordController.text.trim(),
        meaning: _meaningController.text.trim(),
        pronunciation: _pronunciationController.text.trim(),
        listeningText: _listeningTextController.text.trim(),
        audioUrl: _audioUrlController.text.trim(),
        exampleSentence: _exampleSentenceController.text.trim(),
        exampleMeaning: _exampleMeaningController.text.trim(),
        quizQuestion: _quizQuestionController.text.trim(),
        quizOptions: _optionControllers.map((controller) => controller.text.trim()).where((value) => value.isNotEmpty).toList(),
        correctAnswerIndex: _correctAnswerIndex,
        source: widget.entry?.source ?? 'manual',
      );

      final payload = <String, dynamic>{
        ...entry.toMap(),
        'createdBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final collection = FirebaseFirestore.instance.collection('vocabulary_items');
      if (_isEditMode) {
        await collection.doc(widget.entry!.id).update(payload);
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['order'] = DateTime.now().millisecondsSinceEpoch;
        final docRef = collection.doc();
        await docRef.set(payload);
      }

      if (_autoSaveDrafts && !_isEditMode) {
        final prefs = await SharedPreferences.getInstance();
        _clearDraft(prefs);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Vocabulary updated successfully.' : 'Vocabulary saved successfully.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save vocabulary: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: context.textDeep),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textMuted),
        hintText: hintText,
        hintStyle: TextStyle(color: context.textMuted),
        filled: true,
        fillColor: context.cardBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderTheme),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator ??
          (value) {
            if ((value ?? '').trim().isEmpty) {
              return '$label is required';
            }
            return null;
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(_isEditMode ? 'Edit Vocabulary' : 'Create Vocabulary'),
        actions: [
          TextButton.icon(
            onPressed: _isGenerating ? null : _generateDraft,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('AI / Dictionary', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(controller: _wordController, label: 'Vocabulary Word'),
            const SizedBox(height: 12),
            _field(controller: _meaningController, label: 'Meaning'),
            const SizedBox(height: 12),
            _field(controller: _pronunciationController, label: 'Pronunciation'),
            const SizedBox(height: 12),
            _field(
              controller: _listeningTextController,
              label: 'Listening Text',
              maxLines: 2,
              hintText: 'Text used for listening practice or TTS playback',
            ),
            const SizedBox(height: 12),
            _field(
              controller: _audioUrlController,
              label: 'Audio URL (optional)',
              validator: (_) => null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _exampleSentenceController,
              label: 'Example Sentence',
              maxLines: 2,
              validator: (_) => null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _exampleMeaningController,
              label: 'Example Meaning',
              maxLines: 2,
              validator: (_) => null,
            ),
            const SizedBox(height: 12),
            _field(controller: _quizQuestionController, label: 'Quiz Question', maxLines: 2),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++) ...[
              _field(controller: _optionControllers[i], label: 'Quiz Option ${i + 1}'),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<int>(
              initialValue: _correctAnswerIndex,
              dropdownColor: context.cardBg,
              style: TextStyle(color: context.textDeep),
              decoration: InputDecoration(
                labelText: 'Correct Answer',
                labelStyle: TextStyle(color: context.textMuted),
                filled: true,
                fillColor: context.cardBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderTheme),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green, width: 2),
                ),
              ),
              items: [
                DropdownMenuItem(value: 0, child: Text('Option 1', style: TextStyle(color: context.textDeep))),
                DropdownMenuItem(value: 1, child: Text('Option 2', style: TextStyle(color: context.textDeep))),
                DropdownMenuItem(value: 2, child: Text('Option 3', style: TextStyle(color: context.textDeep))),
                DropdownMenuItem(value: 3, child: Text('Option 4', style: TextStyle(color: context.textDeep))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _correctAnswerIndex = value;
                  _onFieldChanged();
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditMode ? 'Update Vocabulary' : 'Save Vocabulary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
