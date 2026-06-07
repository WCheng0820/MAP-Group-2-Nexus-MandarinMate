import 'package:flutter/material.dart';

enum LessonType {
  vocabulary,
  listening,
  speaking,
  matching,
  quiz,
}

class LessonItem {
  final String id;
  final LessonType type;
  final String chinese;
  final String pinyin;
  final String english;
  final String? audioUrl;
  final String? exampleSentence;
  final String? exampleEnglish;
  final List<String>? options; // For quiz/listening/matching

  LessonItem({
    required this.id,
    required this.type,
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.audioUrl,
    this.exampleSentence,
    this.exampleEnglish,
    this.options,
  });
}

class Lesson {
  final String id;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isLocked;
  final List<LessonItem> items;
  final int xpReward;

  Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
    this.isCompleted = false,
    this.isLocked = true,
    this.xpReward = 50,
  });
}

class CourseUnit {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final List<Lesson> lessons;

  CourseUnit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lessons,
  });
}
