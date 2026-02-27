import 'dart:convert';
import 'package:http/http.dart' as http;

/// Central API service for communicating with the FastAPI backend.
class ApiService {
  // Change this to your deployed URL in production
  static const String baseUrl = 'http://localhost:8000';

  /// Calls /generate_analogy — returns culturally tailored analogies for a slang word.
  static Future<Map<String, dynamic>> generateAnalogy({
    required String slangText,
    required String userGeneration,
    required String userVibe,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate_analogy'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'slang_text': slangText,
        'user_generation': userGeneration,
        'user_vibe': userVibe,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Analogy generation failed: ${response.body}');
    }
  }

  /// Calls /live_translate — translates slang into polite senior-friendly text.
  static Future<Map<String, dynamic>> liveTranslate({
    required String text,
    required String userVibe,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live_translate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'user_vibe': userVibe}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Live translate failed: ${response.body}');
    }
  }

  /// Calls /api/save_word — saves a word to Firestore.
  static Future<Map<String, dynamic>> saveWord({
    required String userId,
    required String slangWord,
    required String literalTranslation,
    required String successfulAnalogy,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/save_word'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'slang_word': slangWord,
        'literal_translation': literalTranslation,
        'successful_analogy': successfulAnalogy,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Save word failed: ${response.body}');
    }
  }

  /// Calls /api/get_words/{user_id} — fetches all saved words.
  static Future<List<Map<String, dynamic>>> getWords(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/get_words/$userId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['words'] ?? []);
    } else {
      throw Exception('Fetch words failed: ${response.body}');
    }
  }
}
