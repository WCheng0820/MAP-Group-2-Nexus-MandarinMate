import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mandarinmate/features/lessons/models/lesson_model.dart';

class AiLessonGeneratorService {
  // TODO: You will need to get a free API key from Google AI Studio (aistudio.google.com)
  static const String _apiKey = 'AIzaSyDIYB3DXaw-8QkM2QxDxMA8cdrYVBn-EO0';

  Future<List<LessonItem>> generateLessonItems(String unitTitle) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );

    final prompt = '''
      You are an expert Mandarin Chinese tutor. 
      Generate to a JSON an array of interactive lesson items for the unit titled: "$unitTitle".
      
      Return ONLY valid JSON array with objects using this exact schema structure:
      [
        {
          "type": "vocabulary", // can be "vocabulary", "listening", "speaking", "quiz", "matching"
          "chinese": "你好",
          "pinyin": "nǐ hǎo",
          "english": "Hello",
          "exampleSentence": "你好，很高兴认识你。",
          "exampleEnglish": "Hello, nice to meet you.",
          "options": [] // Only for quiz or matching, give 4 wrong & right translation options
        }
      ]
      
      Requirements:
      - Include exactly 5 "vocabulary" types.
      - Include exactly 2 "listening" types.
      - Include exactly 2 "speaking" types (pronunciation).
      - Include exactly 2 "quiz" types.
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text ?? '[]';
      
      final cleanJson = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> jsonList = jsonDecode(cleanJson);
      
      return jsonList.map((item) {
        LessonType parsedType = LessonType.vocabulary;
        switch(item['type']) {
          case 'listening': parsedType = LessonType.listening; break;
          case 'speaking': parsedType = LessonType.speaking; break;
          case 'quiz': parsedType = LessonType.quiz; break;
          case 'matching': parsedType = LessonType.matching; break;
        }

        return LessonItem(
          id: DateTime.now().microsecondsSinceEpoch.toString() + (item['chinese'].hashCode).toString(),
          type: parsedType,
          chinese: item['chinese'] ?? '',
          pinyin: item['pinyin'] ?? '',
          english: item['english'] ?? '',
          exampleSentence: item['exampleSentence'],
          exampleEnglish: item['exampleEnglish'],
          options: item['options'] != null ? List<String>.from(item['options']) : null,
        );
      }).toList();

    } catch (e) {
      print('AI Generation failed: $e');
      return [];
    }
  }
}
