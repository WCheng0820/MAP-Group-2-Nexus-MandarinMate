import 'package:equatable/equatable.dart';

class LessonUnit extends Equatable {
  final String id;
  final int unitNumber;
  final String title;
  final String titleChinese;
  final String description;
  final int totalLessons;
  final int xpReward;
  final int order;

  const LessonUnit({
    required this.id,
    required this.unitNumber,
    required this.title,
    required this.titleChinese,
    required this.description,
    required this.totalLessons,
    required this.xpReward,
    required this.order,
  });

  factory LessonUnit.fromFirestore(Map<String, dynamic> data, String docId) {
    return LessonUnit(
      id: docId,
      unitNumber: (data['unitNumber'] as num?)?.toInt() ?? 0,
      title: (data['title'] ?? '').toString(),
      titleChinese: (data['titleChinese'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      totalLessons: (data['totalLessons'] as num?)?.toInt() ?? 0,
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    unitNumber,
    title,
    titleChinese,
    description,
    totalLessons,
    xpReward,
    order,
  ];
}

class VocabItem extends Equatable {
  final String chinese;
  final String pinyin;
  final String malay;
  final String english;

  const VocabItem({
    required this.chinese,
    required this.pinyin,
    required this.malay,
    required this.english,
  });

  factory VocabItem.fromMap(Map<String, dynamic> data) {
    return VocabItem(
      chinese: (data['chinese'] ?? '').toString(),
      pinyin: (data['pinyin'] ?? '').toString(),
      malay: (data['malay'] ?? '').toString(),
      english: (data['english'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [chinese, pinyin, malay, english];
}

class QuizQuestion extends Equatable {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String type;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.type,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    return QuizQuestion(
      question: (data['question'] ?? '').toString(),
      options:
          (data['options'] as List?)
              ?.map((e) => (e ?? '').toString())
              .toList() ??
          <String>[],
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      type: (data['type'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [question, options, correctIndex, type];
}
