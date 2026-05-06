import 'package:equatable/equatable.dart';

class LearningMaterialType {
  static const String article = 'article';
  static const String pdf = 'pdf';
  static const String video = 'video';

  static const List<String> values = <String>[article, pdf, video];
}

class LearningMaterial extends Equatable {
  final String id;
  final String type;
  final String title;
  final String description;
  final String url;
  final String fileName;
  final String storagePath;

  const LearningMaterial({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.url,
    required this.fileName,
    required this.storagePath,
  });

  bool get isArticle => type == LearningMaterialType.article;
  bool get isPdf => type == LearningMaterialType.pdf;
  bool get isVideo => type == LearningMaterialType.video;

  factory LearningMaterial.fromMap(Map<String, dynamic> data) {
    final rawType = (data['type'] ?? '').toString().trim().toLowerCase();
    final type = LearningMaterialType.values.contains(rawType)
        ? rawType
        : LearningMaterialType.article;

    return LearningMaterial(
      id: (data['id'] ?? '').toString(),
      type: type,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      url: (data['url'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'url': url,
      'fileName': fileName,
      'storagePath': storagePath,
    };
  }

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    description,
    url,
    fileName,
    storagePath,
  ];
}

class LessonUnit extends Equatable {
  final String id;
  final int unitNumber;
  final String title;
  final String titleChinese;
  final String description;
  final int totalLessons;
  final int xpReward;
  final int order;
  final List<LearningMaterial> materials;

  const LessonUnit({
    required this.id,
    required this.unitNumber,
    required this.title,
    required this.titleChinese,
    required this.description,
    required this.totalLessons,
    required this.xpReward,
    required this.order,
    required this.materials,
  });

  factory LessonUnit.fromFirestore(Map<String, dynamic> data, String docId) {
    final rawMaterials = (data['materials'] as List?) ?? const <dynamic>[];

    return LessonUnit(
      id: docId,
      unitNumber: (data['unitNumber'] as num?)?.toInt() ?? 0,
      title: (data['title'] ?? '').toString(),
      titleChinese: (data['titleChinese'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      totalLessons: (data['totalLessons'] as num?)?.toInt() ?? 0,
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
      materials: rawMaterials
          .map(
            (item) => item is Map
                ? LearningMaterial.fromMap(Map<String, dynamic>.from(item))
                : null,
          )
          .whereType<LearningMaterial>()
          .toList(),
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
    materials,
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
