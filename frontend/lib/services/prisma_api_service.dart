import 'api/api_client.dart';
import 'auth/auth_api_service.dart';
import 'calendar/calendar_api_service.dart';
import 'coaching/coaching_api_service.dart';
import 'communication/communication_api_service.dart';
import 'kanban/kanban_api_service.dart';
import 'sync/sync_api_service.dart';
import 'ai/ai_api_service.dart';
import 'assistant/assistant_api_service.dart';

/// Façade unifiée sur les services HTTP organisés par module.
class PrismaApiService {
  PrismaApiService({String? baseUrl}) : _client = ApiClient(baseUrl: baseUrl) {
    auth = AuthApiService(_client);
    sync = SyncApiService(_client);
    kanban = KanbanApiService(sync);
    calendar = CalendarApiService(sync);
    communication = CommunicationApiService(sync);
    coaching = CoachingApiService(sync);
    ai = AiApiService(_client);
    assistant = AssistantApiService(_client);
  }

  final ApiClient _client;
  late final AuthApiService auth;
  late final SyncApiService sync;
  late final KanbanApiService kanban;
  late final CalendarApiService calendar;
  late final CommunicationApiService communication;
  late final CoachingApiService coaching;
  late final AiApiService ai;
  late final AssistantApiService assistant;

  String get baseUrl => _client.baseUrl;
  set baseUrl(String value) => _client.baseUrl = value;

  Future<Map<String, dynamic>?> postAuth({
    required String mode,
    required String email,
    required String password,
    String? name,
    String? inviteToken,
    String? projectName,
    String? projectDescription,
    String? projectColor,
  }) =>
      auth.postAuth(
        mode: mode,
        email: email,
        password: password,
        name: name,
        inviteToken: inviteToken,
        projectName: projectName,
        projectDescription: projectDescription,
        projectColor: projectColor,
      );

  Future<Map<String, dynamic>?> fetchBootstrap(String userId) => sync.fetchBootstrap(userId);

  Future<bool> syncAction({
    required String action,
    required String userId,
    required Map<String, dynamic> payload,
  }) =>
      sync.syncAction(action: action, userId: userId, payload: payload);
}
