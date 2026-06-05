import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';

class VocabLessonPage extends StatefulWidget {
  final LessonUnit unit;
  final List<VocabItem> vocabItems;
  final bool focusAudio;

  const VocabLessonPage({
    super.key,
    required this.unit,
    required this.vocabItems,
    this.focusAudio = false,
  });

  @override
  State<VocabLessonPage> createState() => _VocabLessonPageState();
}

class _VocabLessonPageState extends State<VocabLessonPage> {
  late FlutterTts _tts;
  int _currentIndex = 0;
  bool _isSpeaking = false;
  final Set<int> _learned = {};

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
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  void _next() {
    if (_currentIndex < widget.vocabItems.length - 1) {
      setState(() {
        _currentIndex++;
        _learned.add(_currentIndex - 1);
      });
    } else {
      _learned.add(_currentIndex);
      _showCompletion();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _showCompletion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Tahniah!'),
        content: Text('Anda telah menyelesaikan ${widget.unit.title}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Kembali ke Unit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.vocabItems[_currentIndex];
    final progress = (_currentIndex + 1) / widget.vocabItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.focusAudio ? '🔊 Sebutan' : '📖 Kosa Kata'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Soalan ${_currentIndex + 1}/${widget.vocabItems.length}'),
                Text('Dipelajari: ${_learned.length}'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            vocab.chinese,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vocab.pinyin,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isSpeaking
                                ? null
                                : () => _speak(vocab.chinese),
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.volume_up
                                  : Icons.volume_up_outlined,
                            ),
                            label: Text(
                              _isSpeaking ? 'Berbicara...' : 'Dengar sebutan',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSpeaking
                                  ? Colors.orange
                                  : const Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.pink.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  '🇲🇾',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vocab.malay,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  '🇬🇧',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vocab.english,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex > 0 ? _previous : null,
                    child: const Text('Sebelum'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                    ),
                    child: Text(
                      _currentIndex < widget.vocabItems.length - 1
                          ? 'Seterusnya'
                          : 'Selesai',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
