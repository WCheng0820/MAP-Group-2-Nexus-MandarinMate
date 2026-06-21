import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';

class FlashcardGamePage extends StatefulWidget {
  final int levelNumber;
  final String levelTitle;
  final List<VocabItem> vocabItems;

  const FlashcardGamePage({
    super.key,
    required this.levelNumber,
    required this.levelTitle,
    required this.vocabItems,
  });

  @override
  State<FlashcardGamePage> createState() => _FlashcardGamePageState();
}

class _FlashcardGamePageState extends State<FlashcardGamePage>
    with TickerProviderStateMixin {
  static const int _cardsPerLevel = 3;

  late final FlutterTts _tts;
  late final List<VocabItem> _items;
  late final AnimationController _flipController;
  int _index = 0;
  bool _isSpeaking = false;
  bool _showChinese = true;
  bool _showPinyin = true;

  @override
  void initState() {
    super.initState();
    _items = widget.vocabItems.take(_cardsPerLevel).toList(growable: false);
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _initTts();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showChinese = prefs.getBool('show_chinese_characters') ?? true;
        _showPinyin = prefs.getBool('show_pinyin') ?? true;
      });
    }
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('zh-CN');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
    _tts.setErrorHandler((message) {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _speakCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final soundEffects = prefs.getBool('sound_effects') ?? true;
    if (!soundEffects) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sound effects are disabled in settings.'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_isSpeaking || _items.isEmpty) {
      return;
    }
    setState(() => _isSpeaking = true);
    try {
      final result = await _tts.speak(_items[_index].chinese);
      if (result == 0) {
        // Success
      } else {
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  void _next() {
    if (_index >= _items.length - 1) {
      return;
    }
    _flipController.reset();
    setState(() {
      _index++;
    });
  }

  void _previous() {
    if (_index <= 0) {
      return;
    }
    _flipController.reset();
    setState(() {
      _index--;
    });
  }

  void _toggleFlip() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Level ${widget.levelNumber} Flashcards')),
        body: const Center(child: Text('No flashcards available.')),
      );
    }

    final item = _items[_index];
    final progress = (_index + 1) / _items.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text('Level ${widget.levelNumber}: ${widget.levelTitle}'),
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
              '${_index + 1}/${_items.length}',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GestureDetector(
                onTap: _toggleFlip,
                child: AnimatedBuilder(
                  animation: _flipController,
                  builder: (context, child) {
                    final angle = _flipController.value * 3.14159;
                    final isFlipped = angle > 1.5707; // π/2

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(isFlipped ? angle + 3.14159 : angle),
                      child: Container(
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
                        child: isFlipped
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
                                    'Tap to flip back',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_showChinese)
                                    Text(
                                      item.chinese,
                                      style: const TextStyle(
                                        fontSize: 52,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  if (_showChinese && _showPinyin) const SizedBox(height: 12),
                                  if (_showPinyin)
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
                                    'Tap to reveal meaning',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
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
                  child: _index < _items.length - 1
                      ? ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C3BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Next'),
                        )
                      : ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Finish'),
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
