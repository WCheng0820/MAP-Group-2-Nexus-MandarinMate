import 'package:flutter/material.dart';
import '../domain/active_lesson_model.dart';

List<LessonItem> generateItemsForVocab(
  String chinese,
  String pinyin,
  String english,
  String? exampleCh,
  String? exampleEn,
) {
  return [
    LessonItem(
      id: '_vocab',
      type: LessonType.vocabulary,
      chinese: chinese,
      pinyin: pinyin,
      english: english,
      exampleSentence: exampleCh,
      exampleEnglish: exampleEn,
    ),
    LessonItem(
      id: '_listen',
      type: LessonType.listening,
      chinese: chinese,
      pinyin: pinyin,
      english: english,
      options: [english, 'Goodbye', 'Thank you', 'Sorry']..shuffle(),
    ),
    LessonItem(
      id: '_speak',
      type: LessonType.speaking,
      chinese: chinese,
      pinyin: pinyin,
      english: english,
    ),
    LessonItem(
      id: '_quiz',
      type: LessonType.quiz,
      chinese: chinese,
      pinyin: pinyin,
      english: english,
      options: [english, 'Please', 'Good morning', 'How much?']..shuffle(),
    ),
  ];
}

final List<CourseUnit> mockCourseUnits = [
  CourseUnit(
    id: 'u1',
    title: 'Unit 1: Basics',
    subtitle: 'Greetings & Introductions',
    color: const Color(0xFFE53935), // Red
    lessons: [
      Lesson(
        id: 'u1_l1',
        title: '你好 - Hello',
        subtitle: 'Nǐ hǎo',
        isCompleted: false, // Calculated dynamically later
        isLocked: true,
        xpReward: 30,
        items: generateItemsForVocab(
          '你好',
          'Nǐ hǎo',
          'Hello',
          '你好！我叫小明。',
          'Hello! My name is Xiao Ming.',
        ),
      ),
      Lesson(
        id: 'u1_l2',
        title: '谢谢 - Thank You',
        subtitle: 'Xiè xiè',
        isCompleted: false,
        isLocked: true,
        xpReward: 30,
        items: generateItemsForVocab(
          '谢谢',
          'Xiè xiè',
          'Thank You',
          '谢谢你的帮助。',
          'Thank you for your help.',
        ),
      ),
      Lesson(
        id: 'u1_l3',
        title: '问候 - Greetings',
        subtitle: 'Wèn hòu',
        isCompleted: false,
        isLocked: true,
        xpReward: 50,
        items: generateItemsForVocab(
          '早上好',
          'Zǎo shang hǎo',
          'Good morning',
          '大家早上好。',
          'Good morning everyone.',
        ),
      ),
      Lesson(
        id: 'u1_l4',
        title: 'Unit 1 Summary Quiz',
        subtitle: 'Match & Review',
        isCompleted: false,
        isLocked: true,
        xpReward: 100,
        items: [
          LessonItem(
            id: 'u1_rev_match1',
            type: LessonType.matching,
            chinese: '配对',
            pinyin: 'Match',
            english: 'Match the words',
            options: ['你好', 'Hello', '谢谢', 'Thank You', '早上好', 'Good morning'],
          ),
          LessonItem(
            id: 'u1_rev_quiz1',
            type: LessonType.quiz,
            chinese: '早上好',
            pinyin: 'Zǎo shang hǎo',
            english: 'Good morning',
            options: ['Good morning', 'Good night', 'Hello', 'Sorry']
              ..shuffle(),
          ),
          LessonItem(
            id: 'u1_rev_speak1',
            type: LessonType.speaking,
            chinese: '谢谢',
            pinyin: 'Xiè xiè',
            english: 'Thank You',
          ),
        ],
      ),
    ],
  ),
  CourseUnit(
    id: 'u2',
    title: 'Unit 2: Numbers',
    subtitle: 'Counting & Time',
    color: const Color(0xFF4285F4), // Blue
    lessons: [
      Lesson(
        id: 'u2_l1',
        title: '数字 - Numbers',
        subtitle: 'Shù zì',
        isCompleted: false,
        isLocked: true,
        xpReward: 40,
        items: generateItemsForVocab(
          '一二三',
          'Yī èr sān',
          'One two three',
          '一二三四五。',
          '1 2 3 4 5.',
        ),
      ),
      Lesson(
        id: 'u2_l2',
        title: '时间 - Time',
        subtitle: 'Shí jiān',
        isCompleted: false,
        isLocked: true,
        xpReward: 50,
        items: generateItemsForVocab(
          '时间',
          'Shí jiān',
          'Time',
          '现场是什么时间？', // preserved original typo/characters exactly
          'What time is it now?',
        ),
      ),
      Lesson(
        id: 'u2_l3',
        title: 'Unit 2 Summary Quiz',
        subtitle: 'Match & Review',
        isCompleted: false,
        isLocked: true,
        xpReward: 100,
        items: [
          LessonItem(
            id: 'u2_rev_match1',
            type: LessonType.matching,
            chinese: '配对',
            pinyin: 'Match',
            english: 'Match the words',
            options: ['一二三', 'One two three', '时间', 'Time'],
          ),
        ],
      ),
    ],
  ),
  CourseUnit(
    id: 'u3',
    title: 'Unit 3: Daily Life',
    subtitle: 'Food, Places & Activities',
    color: const Color(0xFF8E24AA), // Purple
    lessons: [
      Lesson(
        id: 'u3_l1',
        title: '食物 - Food',
        subtitle: 'Shí wù',
        isCompleted: false,
        isLocked: true,
        xpReward: 50,
        items: generateItemsForVocab(
          '吃饭',
          'Chī fàn',
          'Eat a meal',
          '我们去吃饭吧。',
          'Let s go eat.',
        ),
      ),
      Lesson(
        id: 'u3_l2',
        title: '地方 - Places',
        subtitle: 'Dì fāng',
        isCompleted: false,
        isLocked: true,
        xpReward: 50,
        items: generateItemsForVocab(
          '学校',
          'Xué xiào',
          'School',
          '我在学校。',
          'I am at school.',
        ),
      ),
      Lesson(
        id: 'u3_l3',
        title: 'Unit 3 Summary Quiz',
        subtitle: 'Match & Review',
        isCompleted: false,
        isLocked: true,
        xpReward: 100,
        items: [
          LessonItem(
            id: 'u3_rev_match1',
            type: LessonType.matching,
            chinese: '配对',
            pinyin: 'Match',
            english: 'Match the words',
            options: ['吃饭', 'Eat a meal', '学校', 'School'],
          ),
        ],
      ),
    ],
  ),
];
