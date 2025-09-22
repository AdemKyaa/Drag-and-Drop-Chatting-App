// lib/services/translate_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  TranslateService({
    this.baseUrl = 'https://libretranslate.com', // kendi endpoint’iniz varsa değiştirin
    this.apiKey,
  });

  final String baseUrl;
  final String? apiKey;

  Future<String> translate({
    required String text,
    String source = 'auto',
    required String target, // 'en', 'tr' vs.
  }) async {
    if (text.trim().isEmpty) return text;

    final uri = Uri.parse('$baseUrl/translate');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'source': source,
        'target': target,
        'format': 'text',
        if (apiKey != null) 'api_key': apiKey,
      }),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['translatedText'] ?? text) as String;
    } else {
      // Başarısız olursa orijinali dön
      return text;
    }
  }
}
