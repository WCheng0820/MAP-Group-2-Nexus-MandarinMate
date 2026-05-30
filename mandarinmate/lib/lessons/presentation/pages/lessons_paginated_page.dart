import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/lessons/domain/lesson_model.dart';
import 'lesson_detail_page.dart';
import 'dart:math';

class LessonsPaginatedPage extends StatefulWidget {
  const LessonsPaginatedPage({super.key});

  @override
  State<LessonsPaginatedPage> createState() => _LessonsPaginatedPageState();
}

class _LessonsPaginatedPageState extends State<LessonsPaginatedPage> {
  int _currentPage = 0;
  static const int _itemsPerPage = 3;
  final Random _random = Random();
  late Map<String, Color> _unitColors;
  List<LessonUnit> _learningPathUnits = []; // System units 1-3 + tutor vocab units
  List<LessonUnit> _communityUnits = []; // System units 4+
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unitColors = {};
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('lessons').get();
      
      final regularUnits = <LessonUnit>[];
      final communityUnits = <LessonUnit>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final type = data['type'] as String?;
          final materialsList = data['materials'] as List?;
          
          final isMaterial = type == 'material' || (type != 'vocab_unit' && materialsList != null && materialsList.isNotEmpty);

          if (isMaterial) {
            communityUnits.add(LessonUnit.fromFirestore(data, doc.id));
          } else {
            // Include both system and vocab_unit as regular path
            final unit = LessonUnit.fromFirestore(data, doc.id);
            // If it's a vocab_unit but it missed totalLessons/xpReward fields in constructor, 
            // fromFirestore will handle it properly if fields are present.
            regularUnits.add(unit);
          }
        } catch (e) {
          print('Error loading unit ${doc.id}: $e');
        }
      }

      // Sort both lists by order
      regularUnits.sort((a, b) => a.order.compareTo(b.order));
      communityUnits.sort((a, b) => a.order.compareTo(b.order));

      setState(() {
        _learningPathUnits = regularUnits;
        _communityUnits = communityUnits; // We'll just append it to the common list
        _loading = false;
      });

      // Assign random colors
      for (final unit in [..._learningPathUnits, ..._communityUnits]) {
        _assignRandomColor(unit.id);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load units: $e';
        _loading = false;
      });
    }
  }

  Color _assignRandomColor(String unitId) {
    if (!_unitColors.containsKey(unitId)) {
      final colors = [
        const Color(0xFF1565C0),
        const Color(0xFF6A1B9A),
        const Color(0xFF00695C),
        const Color(0xFFC62828),
        const Color(0xFFE65100),
        const Color(0xFF2E7D32),
        const Color(0xFF0277BD),
        const Color(0xFF5E35B1),
        const Color(0xFF00796B),
        const Color(0xFFC53030),
      ];
      _unitColors[unitId] = colors[_random.nextInt(colors.length)];
    }
    return _unitColors[unitId]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pelajaran Mandarin'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pelajaran Mandarin'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(_error!)),
      );
    }

    final allUnits = [..._learningPathUnits, ..._communityUnits];
    
    final start = _currentPage * _itemsPerPage;
    final end = min(start + _itemsPerPage, allUnits.length);
    final pageUnits = allUnits.sublist(start, end);
    final totalPages = (allUnits.length + _itemsPerPage - 1) ~/ _itemsPerPage;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pelajaran Mandarin'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: allUnits.isEmpty
                ? const Center(child: Text('No units available yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pageUnits.length,
                    itemBuilder: (context, index) {
                      final unit = pageUnits[index];
                      final color = _assignRandomColor(unit.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LessonCard(
                          unit: unit,
                          color: color,
                          onTap: () {
                            _loadAndNavigate(context, unit.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
          // Pagination controls
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    onPressed: _currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadAndNavigate(BuildContext context, String unitId) async {
    try {
      // Load unit document
      final unitDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(unitId)
          .get();

      if (!unitDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unit not found')),
          );
        }
        return;
      }

      final unit = LessonUnit.fromFirestore(unitDoc.data()!, unitDoc.id);

      // Load vocabulary items for this unit
      final vocabDocs = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(unitId)
          .collection('vocabulary')
          .get();

      final vocabItems = <VocabItem>[];
      for (final doc in vocabDocs.docs) {
        final data = doc.data();
        vocabItems.add(VocabItem(
          chinese: data['word'] ?? '',
          pinyin: data['pronunciation'] ?? '',
          malay: data['listeningText'] ?? '',
          english: data['meaning'] ?? '',
        ));
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonDetailPage(
              unit: unit,
              vocabItems: vocabItems,
              isCompleted: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lesson: $e')),
        );
      }
    }
  }
}

class _LessonCard extends StatelessWidget {
  final LessonUnit unit;
  final Color color;
  final VoidCallback onTap;

  const _LessonCard({
    required this.unit,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          unit.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit.titleChinese,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unit.description.isNotEmpty) ...[
                      Text(
                        unit.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Icon(Icons.book, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${unit.totalLessons} lessons',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          '+${unit.xpReward} XP',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
