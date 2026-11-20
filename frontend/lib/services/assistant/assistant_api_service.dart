import 'dart:convert';
import '../api/api_client.dart';

class AssistantMessage {
  const AssistantMessage({required this.role, required this.content});

  /// 'user' ou 'assistant'
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Client du chatbot d'aide (POST /api/mobile/assistant).
class AssistantApiService {
  AssistantApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> status() async {
    try {
      final response = await _client.get('/api/mobile/assistant/status');
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = json['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return const {
      'provider': 'faq',
      'mailEnabled': false,
      'smtpConfigured': false,
    };
  }

  Future<String> ask({
    required String userId,
    required String message,
    List<AssistantMessage> history = const [],
    String? module,
  }) async {
    try {
      final response = await _client.postJson(
        '/api/mobile/assistant',
        {
          'userId': userId,
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
          if (module != null) 'module': module,
        },
        timeout: const Duration(seconds: 25), // un appel LLM peut dépasser les 4 s par défaut
      );
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['ok'] == true) {
        return (json['data']?['reply'] as String?) ?? 'Pas de réponse.';
      }
      return (json['error'] as String?) ?? 'Erreur du serveur (${response.statusCode}).';
    } catch (_) {
      return 'Impossible de joindre l’assistant. Vérifiez la connexion au serveur.';
    }
  }
}
