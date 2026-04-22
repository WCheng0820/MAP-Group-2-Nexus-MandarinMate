import 'package:flutter/material.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizPage extends StatefulWidget {
  final LessonUnit unit;
  final List<QuizQuestion> questions;

  const QuizPage({super.key, required this.unit, required this.questions});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentQ = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  List<bool> _results = [];

  void _selectAnswer(int index) {
    if (_answered) return;
    final isCorrect = index == widget.questions[_currentQ].correctIndex;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _results.add(isCorrect);
      if (isCorrect) _score++;
    });
  }

  Future<void> _saveProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final xpEarned = _score * 10;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await tx.get(docRef);
      final currentXp = (doc.data()?['xp'] ?? 0) as int;
      tx.update(docRef, {'xp': currentXp + xpEarned});
    });
  }

  void _nextQuestion() {
    if (_currentQ < widget.questions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _saveProgress();
      _showResult();
    }
  }

  void _showResult() {
    final percentage = (_score / widget.questions.length * 100).round();
    final xpEarned = _score * 10;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(percentage >= 70 ? '🎉 Bagus!' : '📚 Cuba Lagi!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$percentage%',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            Text('+$xpEarned XP'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.questions.asMap().entries.map((e) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _results[e.key] ? Colors.green : Colors.red,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          if (percentage < 70)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentQ = 0;
                  _selectedAnswer = null;
                  _answered = false;
                  _score = 0;
                  _results = [];
                });
              },
              child: const Text('Cuba Lagi'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Kembali ke Unit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQ];
    final progress = (_currentQ + 1) / widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Kuiz'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              'Skor: $_score/${widget.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...question.options.asMap().entries.map((e) {
              final isSelected = _selectedAnswer == e.key;
              final isCorrect = e.key == question.correctIndex;
              Color? bgColor;
              if (_answered) {
                if (isCorrect) {
                  bgColor = Colors.green.shade100;
                } else if (isSelected) {
                  bgColor = Colors.red.shade100;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: _answered ? null : () => _selectAnswer(e.key),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgColor ?? Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(e.value, textAlign: TextAlign.center),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                ),
                child: const Text('Soalan Seterusnya'),
              ),
          ],
        ),
      ),
    );
  }
}
