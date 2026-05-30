import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../domain/vocabulary_entry.dart';

class VocabularyDraftService {
  // Read AI configuration at runtime from .env via flutter_dotenv
  String get _aiProvider => (dotenv.env['TUTOR_AI_PROVIDER'] ?? 'openai');
  String get _aiBaseUrl => (dotenv.env['TUTOR_AI_BASE_URL'] ?? '');
  String get _aiApiKey => (dotenv.env['TUTOR_AI_API_KEY'] ?? '');

  String get _aiModel {
    final configuredModel = dotenv.env['TUTOR_AI_MODEL'] ?? '';
    if (configuredModel.isNotEmpty) return configuredModel;
    return _aiProvider.toLowerCase() == 'gemini' ? 'gemini-1.5-flash' : 'gpt-4o-mini';
  }

  /// Try to extract a JSON object from messy LLM output and repair common truncation
  /// issues. Returns a decoded Map if successful, otherwise null.
  Map<String, dynamic>? _extractAndRepairJson(String text) {
    var t = text.trim();

    // Remove markdown code fences if present (```json ... ```)
    final jsonFence = t.indexOf('```json');
    if (jsonFence != -1) {
      final after = t.substring(jsonFence + 7);
      final endFence = after.indexOf('```');
      t = endFence != -1 ? after.substring(0, endFence).trim() : after.trim();
    } else if (t.startsWith('```')) {
      // generic code fence
      final after = t.substring(3);
      final endFence = after.indexOf('```');
      t = endFence != -1 ? after.substring(0, endFence).trim() : after.trim();
    }

    // Try direct parse first
    try {
      final direct = jsonDecode(t);
      if (direct is Map<String, dynamic>) return direct;
    } catch (_) {}

    // Attempt to find the first '{' and last '}' and parse that slice
    final first = t.indexOf('{');
    if (first == -1) return null;
    final last = t.lastIndexOf('}');
    if (last > first) {
      final slice = t.substring(first, last + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Strategy 1: Trim trailing incomplete lines + close with }
    var candidate = t.substring(first);
    for (var i = 0; i < 15; i++) {
      final lastNl = candidate.lastIndexOf('\n');
      if (lastNl <= 0) break;
      candidate = candidate.substring(0, lastNl).trimRight();
      if (!candidate.endsWith('}')) {
        candidate = candidate + '}';
      }
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // continue trimming
      }
    }

    // Strategy 2: Remove incomplete trailing field by finding last ','
    // This handles cases like: {..., "field": "incomplete_value\n
    var candidate2 = t.substring(first);
    for (var i = 0; i < 10; i++) {
      final lastComma = candidate2.lastIndexOf(',');
      if (lastComma <= first + 1) break; // can't remove more
      candidate2 = candidate2.substring(0, lastComma).trimRight();
      if (!candidate2.endsWith('}')) {
        candidate2 = candidate2 + '}';
      }
      try {
        final decoded = jsonDecode(candidate2);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // continue
      }
    }

    // Strategy 3: Remove trailing incomplete field by finding last well-formed field boundary
    var candidate3 = t.substring(first);
    for (var i = 0; i < 10; i++) {
      try {
        final decoded = jsonDecode(candidate3);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}

      // find last colon (field separator) and try removing after it
      final lastColon = candidate3.lastIndexOf(':');
      if (lastColon <= 0 || lastColon < candidate3.indexOf('{') + 2) break;
      
      // find the comma before this field
      final beforeColon = candidate3.substring(0, lastColon);
      final lastCommaBeforeField = beforeColon.lastIndexOf(',');
      if (lastCommaBeforeField > 0) {
        candidate3 = beforeColon.substring(0, lastCommaBeforeField).trimRight() + '}';
      } else {
        break;
      }
      try {
        final decoded = jsonDecode(candidate3);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // continue
      }
    }

    return null;
  }

  Map<String, dynamic> _normalizeUnitDraft(
    Map<String, dynamic> draft,
    String fallbackTitle,
    int vocabCount,
  ) {
    final title = (draft['title'] ?? '').toString().trim().isEmpty
        ? fallbackTitle
        : draft['title'].toString().trim();

    final subtitle = (draft['subtitle'] ?? '').toString().trim();
    final description = (draft['description'] ?? '').toString().trim().isEmpty
        ? 'Learn vocabulary about $title'
        : draft['description'].toString().trim();

    final normalizedVocab = <Map<String, dynamic>>[];
    final rawVocab = draft['vocab'];
    if (rawVocab is List) {
      for (final item in rawVocab) {
        if (item is Map) {
          normalizedVocab.add(<String, dynamic>{
            'word': (item['word'] ?? '').toString().trim(),
            'meaning': (item['meaning'] ?? '').toString().trim(),
            'pronunciation': (item['pronunciation'] ?? '').toString().trim(),
            'listeningText': (item['listeningText'] ?? '').toString().trim(),
            'exampleSentence': (item['exampleSentence'] ?? '').toString().trim(),
            'exampleMeaning': (item['exampleMeaning'] ?? '').toString().trim(),
            'quizQuestion': (item['quizQuestion'] ?? '').toString().trim(),
            'quizOptions': (item['quizOptions'] is List)
                ? List<dynamic>.from(item['quizOptions'] as List)
                : <dynamic>[],
            'correctAnswerIndex': (item['correctAnswerIndex'] as num?)?.toInt() ?? 0,
          });
        }
      }
    }

    final summaryQuiz = draft['summaryQuiz'];
    final normalizedSummaryQuiz = summaryQuiz is Map
        ? <String, dynamic>{
            'question': (summaryQuiz['question'] ?? '').toString().trim(),
            'options': (summaryQuiz['options'] is List)
                ? List<dynamic>.from(summaryQuiz['options'] as List)
                : <dynamic>[],
            'correctAnswerIndex': (summaryQuiz['correctAnswerIndex'] as num?)?.toInt() ?? 0,
          }
        : <String, dynamic>{
            'question': 'What does $fallbackTitle mean?',
            'options': <dynamic>[],
            'correctAnswerIndex': 0,
          };

    return <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'normalizedTitle': title.toLowerCase(),
      'vocab': normalizedVocab,
      'summaryQuiz': normalizedSummaryQuiz,
    };
  }

  Future<TutorVocabularyEntry> generateDraft({
    required String word,
    String? meaningHint,
  }) async {
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      throw ArgumentError('Word is required');
    }

    final aiDraft = await _tryAiDraft(trimmedWord, meaningHint: meaningHint);
    if (aiDraft != null) {
      return aiDraft;
    }

    final dictionaryDraft = await _tryDictionaryDraft(trimmedWord);
    if (dictionaryDraft != null) {
      return dictionaryDraft;
    }

    return TutorVocabularyEntry(
      id: '',
      word: trimmedWord,
      meaning: meaningHint?.trim() ?? '',
      pronunciation: '',
      listeningText: trimmedWord,
      audioUrl: '',
      exampleSentence: '',
      exampleMeaning: '',
      quizQuestion: 'What does $trimmedWord mean?',
      quizOptions: meaningHint == null || meaningHint.trim().isEmpty
          ? <String>['Edit after AI draft', 'Placeholder A', 'Placeholder B', 'Placeholder C']
          : <String>[meaningHint.trim(), 'Placeholder A', 'Placeholder B', 'Placeholder C'],
      correctAnswerIndex: 0,
      source: 'manual',
    );
  }

  Future<TutorVocabularyEntry?> _tryDictionaryDraft(String word) async {
    if (!RegExp(r'^[A-Za-z][A-Za-z\-\s]*$').hasMatch(word)) {
      return null;
    }

    final response = await http
        .get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! List || payload.isEmpty) {
      return null;
    }

    final entry = payload.first;
    if (entry is! Map<String, dynamic>) {
      return null;
    }

    final phonetics = (entry['phonetics'] as List?) ?? const [];
    final meanings = (entry['meanings'] as List?) ?? const [];
    final phonetic = phonetics
            .whereType<Map>()
            .map((item) => (item['text'] ?? '').toString())
            .where((value) => value.isNotEmpty)
            .firstOrNull ??
        '';
    final firstMeaning = meanings
            .whereType<Map>()
            .map((meaning) => meaning['definitions'])
            .whereType<List>()
            .expand((definitions) => definitions)
            .whereType<Map>()
            .map((definition) => (definition['definition'] ?? '').toString())
            .where((value) => value.isNotEmpty)
            .firstOrNull ??
        '';

    return TutorVocabularyEntry(
      id: '',
      word: word,
      meaning: firstMeaning,
      pronunciation: phonetic,
      listeningText: word,
      audioUrl: '',
      exampleSentence: '',
      exampleMeaning: '',
      quizQuestion: 'What does $word mean?',
      quizOptions: <String>[
        firstMeaning.isEmpty ? 'Edit meaning' : firstMeaning,
        'Option B',
        'Option C',
        'Option D',
      ],
      correctAnswerIndex: 0,
      source: 'dictionary',
    );
  }

  Future<TutorVocabularyEntry?> _tryAiDraft(
    String word, {
    String? meaningHint,
  }) async {
    if (_aiApiKey.isEmpty) {
      return null;
    }

    if (_aiProvider.toLowerCase() == 'gemini') {
      return _tryGeminiDraft(word, meaningHint: meaningHint);
    }

    return _tryOpenAiDraft(word, meaningHint: meaningHint);
  }

  Future<TutorVocabularyEntry?> _tryOpenAiDraft(
    String word, {
    String? meaningHint,
  }) async {
    if (_aiBaseUrl.isEmpty) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse('$_aiBaseUrl/chat/completions'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_aiApiKey',
          },
          body: jsonEncode(<String, dynamic>{
            'model': _aiModel,
            'messages': <Map<String, String>>[
              <String, String>{
                'role': 'system',
                'content':
                    'Return only JSON with keys word, meaning, pronunciation, listeningText, exampleSentence, exampleMeaning, quizQuestion, quizOptions, correctAnswerIndex. Create a Mandarin vocabulary draft for a tutor.',
              },
              <String, String>{
                'role': 'user',
                'content':
                    'Word: $word. Meaning hint: ${meaningHint ?? ''}. Generate a draft for tutoring.',
              },
            ],
            'temperature': 0.3,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final choices = (payload['choices'] as List?) ?? const [];
    if (choices.isEmpty) {
      return null;
    }

    final choice = choices.first;
    if (choice is! Map<String, dynamic>) {
      return null;
    }

    final message = choice['message'];
    final content = message is Map<String, dynamic>
        ? (message['content'] ?? '').toString().trim()
        : '';

    return _parseJsonDraft(content, word: word, meaningHint: meaningHint, source: 'ai');
  }

  Future<TutorVocabularyEntry?> _tryGeminiDraft(
    String word, {
    String? meaningHint,
  }) async {
    final prompt =
        'Return only JSON with keys word, meaning, pronunciation, listeningText, exampleSentence, exampleMeaning, quizQuestion, quizOptions, correctAnswerIndex. Create a Mandarin vocabulary draft for a tutor. Word: $word. Meaning hint: ${meaningHint ?? ''}.';

    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$_aiModel:generateContent?key=$_aiApiKey',
          ),
          headers: const <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'contents': <Map<String, dynamic>>[
              <String, dynamic>{
                'role': 'user',
                'parts': <Map<String, String>>[
                  <String, String>{'text': prompt},
                ],
              },
            ],
            'generationConfig': <String, dynamic>{
              'temperature': 0.3,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final candidates = (payload['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      return null;
    }

    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      return null;
    }

    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? (content['parts'] as List?) ?? const [] : const [];
    final text = parts
        .whereType<Map>()
        .map((part) => (part['text'] ?? '').toString())
        .join('\n')
        .trim();

    return _parseJsonDraft(text, word: word, meaningHint: meaningHint, source: 'gemini');
  }

  /// Generate a full unit from a single title using the configured AI provider.
  /// Returns a map with keys: 'title', 'vocab' (List<Map>), 'summaryQuiz' (Map).
  Future<Map<String, dynamic>?> generateUnitFromTitle(String title, {int vocabCount = 3}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    if (_aiApiKey.isEmpty) return null;

    final prompt = '''Generate JSON for a Mandarin vocabulary unit on the topic "$trimmed". The unit must continue from the previous 3 units (Unit 1: Basics - Greetings & Introductions, Unit 2: Numbers - Counting & Time, Unit 3: Daily Life - Food, Places & Activities) and represent Unit 4 or subsequent units.

Return only this JSON (no other text, no markdown fences like ```json):
{
  "title": "Short title in English (e.g., 'Transportation' or 'Family')",
  "subtitle": "Engaging subtitle or topic focus in English (e.g., 'Getting Around & Vehicles' or 'Family Members & Relatives')",
  "description": "A short, motivating description of what the student will learn (e.g., 'Learn common vehicles and how to ask for directions.')",
  "vocab": [
    {
      "word": "Chinese characters of the vocabulary item (e.g., '地铁')",
      "meaning": "English meaning (e.g., 'Subway')",
      "pronunciation": "Pinyin pronunciation with tone marks (e.g., 'dìtiě')",
      "listeningText": "Text used for listening exercises, typically the word or a short phrase in Chinese (e.g., '坐地铁')",
      "exampleSentence": "A simple example sentence in Chinese characters using the word (e.g., '我每天坐地铁上学。')",
      "exampleMeaning": "English translation of the example sentence (e.g., 'I take the subway to school every day.')",
      "quizQuestion": "Multiple-choice quiz question testing this vocabulary item (e.g., 'What does \"地铁\" mean?')",
      "quizOptions": ["Subway", "Bus", "Train", "Taxi"],
      "correctAnswerIndex": 0
    }
  ],
  "summaryQuiz": {
    "question": "A summary multiple-choice question reviewing the whole unit's words",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswerIndex": 0
  }
}

Create at least $vocabCount vocabulary items. Make sure the pinyin, example sentences, and translations are highly accurate and friendly for beginner to intermediate students.''';

    try {
      if (_aiProvider.toLowerCase() == 'gemini') {
        final response = await http
            .post(
              Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_aiModel:generateContent?key=$_aiApiKey'),
              headers: const <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': prompt}
                    ],
                  }
                ],
                'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 2000}
              }),
            )
            .timeout(const Duration(seconds: 15));

        print('[VocabularyDraftService] Gemini raw response status: ${response.statusCode}');

        if (response.statusCode < 200 || response.statusCode >= 300) {
          // ignore: avoid_print
          print('[VocabularyDraftService] Gemini request failed: ${response.statusCode} ${response.body}');
          return null;
        }

        final payload = jsonDecode(response.body);
        final candidates = (payload['candidates'] as List?) ?? const [];
        if (candidates.isEmpty) return null;
        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List?) ?? const [];
        var text = parts.map((p) => (p['text'] ?? '').toString()).join('\n');
        
        print('[VocabularyDraftService] Gemini raw text before strip: "${text.substring(0, text.length > 300 ? 300 : text.length)}"');
        
        // Aggressively strip all markdown fence variants
        text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
        text = text.trim();
        
        print('[VocabularyDraftService] Gemini raw text after strip: "${text.substring(0, text.length > 300 ? 300 : text.length)}"');

        final repaired = _extractAndRepairJson(text);
        if (repaired == null) {
          print('[VocabularyDraftService] Gemini JSON parsing FAILED. Raw response: $text');
          return null;
        }
        final normalized = _normalizeUnitDraft(repaired, trimmed, vocabCount);
        print('[VocabularyDraftService] Gemini repaired JSON keys: ${repaired.keys.toList()}');
        final vocabCount2 = (repaired['vocab'] as List?)?.length ?? 0;
        print('[VocabularyDraftService] Gemini repaired object vocab count: $vocabCount2');
        print('[VocabularyDraftService] Gemini title: ${normalized['title']}, vocab count: ${(normalized['vocab'] as List?)?.length ?? 0}');
        if ((normalized['vocab'] as List?)?.isEmpty ?? true) {
          print('[VocabularyDraftService] Gemini returned no vocabulary items after normalization.');
          return null;
        }
        return normalized;
      }

      // OpenAI-style
      final response = await http
          .post(
            Uri.parse('$_aiBaseUrl/chat/completions'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_aiApiKey',
            },
            body: jsonEncode(<String, dynamic>{
              'model': _aiModel,
              'messages': [
                {'role': 'system', 'content': prompt},
                {'role': 'user', 'content': ''}
              ],
              'temperature': 0.2,
              'max_tokens': 1200,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // ignore: avoid_print
        print('[VocabularyDraftService] OpenAI request failed: ${response.statusCode} ${response.body}');
        return null;
      }

      final payload = jsonDecode(response.body);
      final choices = (payload['choices'] as List?) ?? const [];
      if (choices.isEmpty) return null;
      final message = choices.first['message'];
      var textContent = message is Map ? (message['content'] ?? '') as String : (choices.first['text'] ?? '');
      
      // Strip markdown blocks
      if (textContent.startsWith('```json')) {
        textContent = textContent.replaceFirst('```json\n', '');
        if (textContent.endsWith('```\n')) {
          textContent = textContent.substring(0, textContent.length - 4);
        } else if (textContent.endsWith('```')) {
          textContent = textContent.substring(0, textContent.length - 3);
        }
      }

      final repaired = _extractAndRepairJson(textContent);
      if (repaired == null) {
        print('[VocabularyDraftService] OpenAI JSON parsing FAILED. Raw response: $textContent');
        return null;
      }
      final normalized = _normalizeUnitDraft(repaired, trimmed, vocabCount);
      print('[VocabularyDraftService] OpenAI repaired JSON keys: ${repaired.keys.toList()}');
      print('[VocabularyDraftService] OpenAI title: ${normalized['title']}, vocab count: ${(normalized['vocab'] as List?)?.length ?? 0}');
      if ((normalized['vocab'] as List?)?.isEmpty ?? true) {
        print('[VocabularyDraftService] OpenAI returned no vocabulary items after normalization.');
        return null;
      }
      return normalized;
    } catch (e) {
      // ignore: avoid_print
      print('[VocabularyDraftService] Request Exception: $e');
      return null;
    }
  }

  TutorVocabularyEntry? _parseJsonDraft(
    String content, {
    required String word,
    required String? meaningHint,
    required String source,
  }) {
    if (content.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return TutorVocabularyEntry(
        id: '',
        word: (decoded['word'] ?? word).toString(),
        meaning: (decoded['meaning'] ?? meaningHint ?? '').toString(),
        pronunciation: (decoded['pronunciation'] ?? '').toString(),
        listeningText: (decoded['listeningText'] ?? word).toString(),
        audioUrl: '',
        exampleSentence: (decoded['exampleSentence'] ?? '').toString(),
        exampleMeaning: (decoded['exampleMeaning'] ?? '').toString(),
        quizQuestion: (decoded['quizQuestion'] ?? 'What does $word mean?').toString(),
        quizOptions:
            (decoded['quizOptions'] as List?)
                ?.map((value) => (value ?? '').toString())
                .toList() ??
            <String>[word, meaningHint ?? '', 'Option B', 'Option C'],
        correctAnswerIndex: (decoded['correctAnswerIndex'] as num?)?.toInt() ?? 0,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
