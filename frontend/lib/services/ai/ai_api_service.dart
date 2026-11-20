import 'dart:convert';
import '../api/api_client.dart';

class AiApiService {
  AiApiService(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> analyze({
    required String module,
    required String userId,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final response = await _client.postJson('/api/mobile/ai', {
        'module': module,
        'userId': userId,
        'payload': payload,
      });
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'];
      if (json['ok'] == true && data is List) {
        return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> generate({
    required String type,
    required String userId,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final response = await _client.postJson(
        '/api/mobile/ai/generate',
        {
          'type': type,
          'userId': userId,
          'payload': payload,
        },
        timeout: const Duration(seconds: 20),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['ok'] == true && json['data'] is Map) {
        return Map<String, dynamic>.from(json['data'] as Map);
      }
    } catch (_) {}
    return null;
  }
}
