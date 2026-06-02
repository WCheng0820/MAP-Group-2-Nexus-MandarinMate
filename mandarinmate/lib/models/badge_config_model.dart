import 'package:equatable/equatable.dart';

class BadgeConfig extends Equatable { //equatable for value comparison
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int? xpThreshold;
  final int? lessonThreshold;
  final int? streakThreshold;
  final int? levelThreshold;

  const BadgeConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.xpThreshold,
    this.lessonThreshold,
    this.streakThreshold,
    this.levelThreshold,
  });

  @override
  List<Object?> get props => [id, name, description, imageUrl, xpThreshold, lessonThreshold, streakThreshold, levelThreshold];

  factory BadgeConfig.fromMap(Map<String, dynamic> map) {
    return BadgeConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      imageUrl: map['imageUrl'] as String,
      xpThreshold: map['xpThreshold'] as int?,
      lessonThreshold: map['lessonThreshold'] as int?,
      streakThreshold: map['streakThreshold'] as int?,
      levelThreshold: map['levelThreshold'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'xpThreshold': xpThreshold,
      'lessonThreshold': lessonThreshold,
      'streakThreshold': streakThreshold,
      'levelThreshold': levelThreshold,
    };
  }
}