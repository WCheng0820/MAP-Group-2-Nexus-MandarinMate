import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';

class FlashcardGamePage extends StatefulWidget {
  final LessonUnit unit;
  final List<VocabItem> vocabItems;

  const FlashcardGamePage({
    super.key,
    required this.unit,
    required this.vocabItems,
  });

  @override
  State<FlashcardGamePage> createState() => _FlashcardGamePageState();
}

class _FlashcardGamePageState extends State<FlashcardGamePage> {
  late final FlutterTts _tts;
  int _index = 0;
  bool _showBack = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.4);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _speakCurrent() async {
    if (_isSpeaking || widget.vocabItems.isEmpty) {
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(widget.vocabItems[_index].chinese);
  }

  void _next() {
    if (_index >= widget.vocabItems.length - 1) {
      return;
    }
    setState(() {
      _index++;
      _showBack = false;
    });
  }

  void _previous() {
    if (_index <= 0) {
      return;
    }
    setState(() {
      _index--;
      _showBack = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vocabItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Flashcards: ${widget.unit.title}')),
        body: const Center(child: Text('No flashcards available.')),
      );
    }

    final item = widget.vocabItems[_index];
    final progress = (_index + 1) / widget.vocabItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text('Flashcards: ${widget.unit.title}'),
        backgroundColor: const Color(0xFF6C3BFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white,
              color: const Color(0xFF6C3BFF),
            ),
            const SizedBox(height: 8),
            Text(
              '${_index + 1}/${widget.vocabItems.length}',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: _showBack
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.malay,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.english,
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Tap card to show front',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.chinese,
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.pinyin,
                              style: TextStyle(
                                fontSize: 26,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Tap card to reveal meaning',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _speakCurrent,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3BFF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              icon: Icon(
                _isSpeaking
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
              ),
              label: Text(_isSpeaking ? 'Speaking...' : 'Pronunciation'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index > 0 ? _previous : null,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index < widget.vocabItems.length - 1
                        ? _next
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C3BFF),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
