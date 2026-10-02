import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/listing_draft.dart';

class GeminiVisionService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.5-flash-lite';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<ListingDraft> analyzeProductImage({
    required Uint8List imageBytes,
    required String mimeType,
    required String prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY กรุณารันด้วย --dart-define=GEMINI_API_KEY=your_key');
    }

    final uri = Uri.parse(_baseUrl);
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'thinkingConfig': {'thinkingLevel': 'low'},
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'category': {'type': 'STRING'},
            'description': {'type': 'STRING'},
          },
          'required': ['title', 'category', 'description'],
        },
      },
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Gemini API ตอบกลับผิดพลาด (สถานะ ${response.statusCode})');
      }

      // ชั้นที่ 1: แปลง Response ของ Gemini API เป็น Map
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น');
      }

      final candidate = candidates.first as Map<String, dynamic>;
      if (candidate['finishReason'] == 'SAFETY') {
        throw Exception('เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น');
      }

      final parts = candidate['content']?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น');
      }

      // ชั้นที่ 2: ข้อความใน text เป็น JSON อีกชั้นหนึ่งตาม responseSchema
      final text = parts.first['text'] as String;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return ListingDraft.fromJson(json);
    } on TimeoutException {
      throw Exception('AI ใช้เวลาวิเคราะห์นานเกินไป กรุณาลองใหม่อีกครั้ง');
    } on http.ClientException {
      throw Exception('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ');
    } on FormatException {
      throw Exception('ผลลัพธ์จาก AI ไม่อยู่ในรูปแบบที่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
    }
  }
}
