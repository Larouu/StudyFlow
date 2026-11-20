import 'dart:convert';
import '../api/api_client.dart';

/// Service HTTP dédié à l'authentification et aux équipes.
class AuthApiService {
  AuthApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>?> postAuth({
    required String mode,
    required String email,
    required String password,
    String? name,
    String? inviteToken,
    String? projectName,
    String? projectDescription,
    String? projectColor,
  }) async {
    final res = await _client.postJson('/api/mobile/auth', {
      'mode': mode,
      'email': email,
      'password': password,
      if (name != null) 'name': name,
      if (inviteToken != null) 'inviteToken': inviteToken,
      if (projectName != null) 'projectName': projectName,
      if (projectDescription != null) 'projectDescription': projectDescription,
      if (projectColor != null) 'projectColor': projectColor,
    });
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['ok'] == true) {
      return data;
    }
    return null;
  }

  Future<bool> joinTeam(String userId, String inviteToken) =>
      _sync('JOIN_TEAM', userId, {'inviteToken': inviteToken});

  Future<bool> inviteMember(String userId, String email, {String role = 'MEMBER'}) =>
      _sync('INVITE_MEMBER', userId, {'email': email, 'role': role});

  Future<bool> updateMemberRole(String userId, String targetUserId, String newRole) =>
      _sync('UPDATE_MEMBER_ROLE', userId, {'targetUserId': targetUserId, 'newRole': newRole});

  Future<bool> removeMember(String userId, String targetUserId) =>
      _sync('REMOVE_MEMBER', userId, {'targetUserId': targetUserId});

  Future<bool> _sync(String action, String userId, Map<String, dynamic> payload) async {
    try {
      final res = await _client.postJson('/api/mobile/sync', {
        'action': action,
        'userId': userId,
        'payload': payload,
      });
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return res.statusCode == 200 && json['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
