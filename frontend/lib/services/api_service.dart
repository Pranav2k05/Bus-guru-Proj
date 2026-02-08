// frontend/lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Update if your backend runs on a different host/port
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// POST /api/chatbot/chat
  /// returns Map { 'reply': String, 'detected_lang': String }
  static Future<Map<String, dynamic>> chatWithRetry(
    String text, {
    String? forceLang,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('empty_text');
    }

    final url = Uri.parse('$baseUrl/api/chatbot/chat');
    final payload = <String, dynamic>{'text': text};
    if (forceLang != null && forceLang.isNotEmpty) payload['force_lang'] = forceLang;

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
            .timeout(timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          // normalize
          final reply = (data['reply'] ?? '').toString();
          final detected = (data['detected_lang'] ?? 'en').toString();
          return {'reply': reply, 'detected_lang': detected};
        } else {
          // Non-200 — treat as recoverable for a couple attempts
          final body = resp.body;
          if (attempt >= maxAttempts) {
            throw Exception('backend-error: ${resp.statusCode} ${body}');
          }
          // small exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
      } catch (e) {
        if (attempt >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 400 * attempt));
        continue;
      }
    }
  }
}
