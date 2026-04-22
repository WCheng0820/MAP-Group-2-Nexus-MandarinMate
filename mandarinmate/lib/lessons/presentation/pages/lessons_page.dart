import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/features/lessons/data/lesson_repository.dart';
import 'package:mandarinmate/features/lessons/presentation/bloc/lesson_bloc.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';
import 'package:mandarinmate/features/lessons/presentation/pages/lesson_detail_page.dart';

class LessonsPage extends StatelessWidget {
  const LessonsPage({super.key});

  static const List<Color> _cardColors = [
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFFC62828),
    Color(0xFFE65100),
    Color(0xFF2E7D32),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LessonBloc(repository: LessonRepository())..add(LessonLoadUnits()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('Pelajaran Mandarin'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: BlocConsumer<LessonBloc, LessonState>(
          listener: (context, state) {
            if (state is LessonVocabLoaded) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonDetailPage(
                    unit: state.unit,
                    vocabItems: state.vocabItems,
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            final units = state is LessonUnitsLoaded
                ? state.units
                : state is LessonVocabLoaded
                ? state.units
                : <LessonUnit>[];

            if (state is LessonLoading && units.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is LessonError && units.isEmpty) {
              return Center(child: Text(state.message));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                return _LessonCard(
                  unit: unit,
                  color: _cardColors[index % _cardColors.length],
                  onTap: () {
                    context.read<LessonBloc>().add(LessonLoadVocab(unit.id));
                  },
                );
              },
            );
          },
        ),
      ),
    );
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
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          avatar: const Icon(Icons.book_outlined, size: 16),
                          label: Text('${unit.totalLessons} lessons'),
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(
                            Icons.bolt,
                            size: 16,
                            color: Colors.amber,
                          ),
                          label: Text('+${unit.xpReward} XP'),
                          backgroundColor: Colors.amber.shade50,
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unit.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
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
