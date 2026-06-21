import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiModerationService {
  String get _aiProvider => (dotenv.env['TUTOR_AI_PROVIDER'] ?? 'openai').toLowerCase();
  String get _aiBaseUrl => (dotenv.env['TUTOR_AI_BASE_URL'] ?? '');
  String get _aiApiKey => (dotenv.env['TUTOR_AI_API_KEY'] ?? '');

  String get _aiModel {
    final configuredModel = dotenv.env['TUTOR_AI_MODEL'] ?? '';
    if (configuredModel.isNotEmpty) return configuredModel;
    return _aiProvider == 'gemini' ? 'gemini-1.5-flash' : 'gpt-4o-mini';
  }

  /// Scans the provided text for inappropriate content.
  /// Returns a clear rejection message if flagged, or null if clean.
  Future<String?> scanText(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return null;

    if (_aiApiKey.isEmpty) {
      print('[AiModerationService] Warning: TUTOR_AI_API_KEY is not configured in .env.');
      return null;
    }

    try {
      if (_aiProvider == 'openai') {
        return await _scanTextWithOpenAi(trimmedText);
      } else {
        return await _scanTextWithGemini(trimmedText);
      }
    } catch (e) {
      print('[AiModerationService] Exception during text scanning: $e');
      // Fail-safe: allow posting if external AI service is unreachable/errored
      return null;
    }
  }

  /// Scans local image file for inappropriate content.
  /// Returns a rejection message if flagged, or null if clean.
  Future<String?> scanImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    if (_aiApiKey.isEmpty) {
      print('[AiModerationService] Warning: TUTOR_AI_API_KEY is not configured for image scanning.');
      return null;
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      if (_aiProvider == 'openai') {
        return await _scanImageWithOpenAi(base64Image, mimeType);
      } else {
        return await _scanImageWithGemini(base64Image, mimeType);
      }
    } catch (e) {
      print('[AiModerationService] Exception during image scanning: $e');
      return null; // Fail-safe
    }
  }

  Future<String?> _scanTextWithOpenAi(String text) async {
    final baseUrl = _aiBaseUrl.isNotEmpty ? _aiBaseUrl : 'https://api.openai.com/v1';
    final response = await http.post(
      Uri.parse('$baseUrl/moderations'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey',
      },
      body: jsonEncode(<String, dynamic>{
        'input': text,
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[AiModerationService] OpenAI Moderation API returned status: ${response.statusCode}');
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) return null;

    final results = payload['results'] as List?;
    if (results == null || results.isEmpty) return null;

    final result = results.first as Map<String, dynamic>;
    final flagged = result['flagged'] as bool? ?? false;

    if (flagged) {
      final categories = result['categories'] as Map<String, dynamic>? ?? {};
      final flaggedCategories = <String>[];
      categories.forEach((key, value) {
        if (value == true) {
          flaggedCategories.add(key.replaceAll('/', ' ').replaceAll('_', ' '));
        }
      });

      String msg = 'Inappropriate content detected';
      if (flaggedCategories.isNotEmpty) {
        msg += ': This content contains ${flaggedCategories.join(', ')}.';
      }
      msg += ' Please revise your content to keep MandarinMate positive and friendly.';
      return msg;
    }

    return null;
  }

  Future<String?> _scanTextWithGemini(String text) async {
    final prompt = '''
You are an AI content moderation assistant. Analyze the text below for inappropriate content including hate speech, profanity, harassment, sexual content, violence, or self-harm.

Text to analyze: "$text"

Return ONLY a valid JSON object with the following fields:
- "flagged": a boolean indicating if the text contains inappropriate content.
- "categories": a list of strings representing the violated categories (e.g. ["profanity", "harassment"]). If not flagged, return an empty list.
- "reason": a short description of why it was flagged, or empty string if not flagged.

Strictly return JSON only. No markdown formatting.
''';

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_aiModel:generateContent?key=$_aiApiKey'),
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
          'temperature': 0.0,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[AiModerationService] Gemini Content Moderation returned status: ${response.statusCode}');
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) return null;

    final candidates = (payload['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return null;

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? (content['parts'] as List?) ?? const [] : const [];
    var textResponse = parts
        .whereType<Map>()
        .map((part) => (part['text'] ?? '').toString())
        .join('\n')
        .trim();

    textResponse = textResponse.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();

    return _parseFlaggedJsonResponse(textResponse);
  }

  Future<String?> _scanImageWithOpenAi(String base64Image, String mimeType) async {
    final baseUrl = _aiBaseUrl.isNotEmpty ? _aiBaseUrl : 'https://api.openai.com/v1';
    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey',
      },
      body: jsonEncode(<String, dynamic>{
        'model': _aiModel == 'gemini-2.5-flash' || _aiModel.contains('gemini') ? 'gpt-4o-mini' : _aiModel,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'text',
                'text': 'Analyze this image for inappropriate content including violence, nudity, hate symbols, harassment, or self-harm. Return ONLY a JSON object: {"flagged": true/false, "categories": ["category_name"], "reason": "reason description"}'
              },
              <String, dynamic>{
                'type': 'image_url',
                'image_url': <String, String>{
                  'url': 'data:$mimeType;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'response_format': <String, String>{
          'type': 'json_object'
        },
        'temperature': 0.0,
      }),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[AiModerationService] OpenAI Image Scan returned status: ${response.statusCode}');
      return null;
    }

    final payload = jsonDecode(response.body);
    final choices = (payload['choices'] as List?) ?? const [];
    if (choices.isEmpty) return null;

    final message = choices.first['message'];
    final content = message is Map<String, dynamic> ? (message['content'] ?? '').toString().trim() : '';

    return _parseFlaggedJsonResponse(content);
  }

  Future<String?> _scanImageWithGemini(String base64Image, String mimeType) async {
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_aiModel:generateContent?key=$_aiApiKey'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, dynamic>>[
              <String, String>{
                'text': 'Analyze this image for inappropriate content including violence, nudity, hate symbols, harassment, or self-harm. Return ONLY a JSON object: {"flagged": true/false, "categories": ["category_name"], "reason": "reason description"}'
              },
              <String, dynamic>{
                'inlineData': <String, String>{
                  'mimeType': mimeType,
                  'data': base64Image
                }
              }
            ],
          },
        ],
        'generationConfig': <String, dynamic>{
          'temperature': 0.0,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('[AiModerationService] Gemini Image Scan returned status: ${response.statusCode}');
      return null;
    }

    final payload = jsonDecode(response.body);
    final candidates = (payload['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return null;

    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) return null;

    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? (content['parts'] as List?) ?? const [] : const [];
    var textResponse = parts
        .whereType<Map>()
        .map((part) => (part['text'] ?? '').toString())
        .join('\n')
        .trim();

    textResponse = textResponse.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();

    return _parseFlaggedJsonResponse(textResponse);
  }

  String? _parseFlaggedJsonResponse(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;

      final flagged = decoded['flagged'] as bool? ?? false;
      if (flagged) {
        final categories = (decoded['categories'] as List?)?.map((c) => c.toString()).toList() ?? [];
        final reason = decoded['reason']?.toString() ?? '';

        String msg = 'Inappropriate content detected';
        if (categories.isNotEmpty) {
          msg += ': This content contains ${categories.join(', ')}.';
        } else if (reason.isNotEmpty) {
          msg += ': $reason.';
        }
        msg += ' Please revise your content to keep MandarinMate positive and friendly.';
        return msg;
      }
    } catch (e) {
      print('[AiModerationService] Error parsing JSON: $e. Raw response: $jsonString');
    }
    return null;
  }
}
