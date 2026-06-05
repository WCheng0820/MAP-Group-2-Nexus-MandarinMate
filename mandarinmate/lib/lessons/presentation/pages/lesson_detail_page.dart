import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';
import 'package:url_launcher/url_launcher.dart';

class LessonDetailPage extends StatefulWidget {
  final LessonUnit unit;
  final List<VocabItem> vocabItems;
  final bool isCompleted;

  const LessonDetailPage({
    super.key,
    required this.unit,
    required this.vocabItems,
    required this.isCompleted,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  bool _isSaving = false;
  late bool _completedLocally;

  @override
  void initState() {
    super.initState();
    _completedLocally = widget.isCompleted;
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.amber,
        ),
      ),
    );
  }

  Widget _materialCard(BuildContext context, LearningMaterial material) {
    final color = _materialColor(material.type);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_materialIcon(material.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _materialLabel(material.type),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (material.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              material.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
          if (material.fileName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              material.fileName,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openMaterial(context, material),
              icon: Icon(_materialActionIcon(material.type)),
              label: Text(_materialActionLabel(material.type)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _materialIcon(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return Icons.picture_as_pdf_outlined;
      case LearningMaterialType.video:
        return Icons.video_library_outlined;
      case LearningMaterialType.article:
      default:
        return Icons.article_outlined;
    }
  }

  IconData _materialActionIcon(String type) {
    switch (type) {
      case LearningMaterialType.video:
        return Icons.play_circle_outline;
      case LearningMaterialType.pdf:
        return Icons.open_in_new;
      case LearningMaterialType.article:
      default:
        return Icons.menu_book_outlined;
    }
  }

  String _materialLabel(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return 'PDF Reference';
      case LearningMaterialType.video:
        return 'Video Lesson';
      case LearningMaterialType.article:
      default:
        return 'Article';
    }
  }

  String _materialActionLabel(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return 'Open PDF';
      case LearningMaterialType.video:
        return 'Watch Video';
      case LearningMaterialType.article:
      default:
        return 'Read Article';
    }
  }

  Color _materialColor(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return const Color(0xFFC62828);
      case LearningMaterialType.video:
        return const Color(0xFF6A1B9A);
      case LearningMaterialType.article:
      default:
        return const Color(0xFF1565C0);
    }
  }

  Future<void> _openMaterial(
    BuildContext context,
    LearningMaterial material,
  ) async {
    final uri = Uri.tryParse(material.url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material link is invalid.')),
      );
      return;
    }

    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This material could not be opened.')),
      );
    }
  }

  Future<void> _completeLesson() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final currentCompleted = List<String>.from(snapshot.data()?['completedLessons'] ?? []);
        if (!currentCompleted.contains(widget.unit.id)) {
          transaction.update(docRef, {
            'xpPoints': FieldValue.increment(widget.unit.xpReward),
            'xp': FieldValue.increment(widget.unit.xpReward),
            'completedLessons': FieldValue.arrayUnion([widget.unit.id]),
          });
        }
      });

      setState(() {
        _completedLocally = true;
        _isSaving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set Completed! +${widget.unit.xpReward} XP earned! 🎉'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record completion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Unit ${widget.unit.unitNumber}: ${widget.unit.title}'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.unit.titleChinese,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.unit.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.unit.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _badge('+${widget.unit.xpReward} XP'),
                      const SizedBox(width: 8),
                      _badge('${widget.unit.totalLessons} lessons'),
                      if (widget.unit.materials.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _badge('${widget.unit.materials.length} materials'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (widget.unit.materials.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Learning Materials',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: widget.unit.materials
                    .map((material) => _materialCard(context, material))
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _completedLocally ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE0E0E0),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_isSaving || _completedLocally) ? null : _completeLesson,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _completedLocally ? Icons.check_circle : Icons.offline_pin_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _completedLocally ? 'Completed' : 'Complete Lesson (+${widget.unit.xpReward} XP)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
