import '../../core/models/studyflow_models.dart';
import '../studyflow_provider_base.dart';

/// Provider du domaine Authentification & Équipe.
mixin AuthProviderMixin on StudyFlowStoreBase {
  String get serverUrl => authRepository.serverUrl;

  void updateServerUrl(String url) {
    authRepository.updateServerUrl(url);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final user = await authRepository.login(email, password);
    if (user == null) {
      isLoading = false;
      statusMessage = 'Identifiants invalides ou utilisateur introuvable.';
      notifyListeners();
      return false;
    }

    currentUser = user;
    if (!users.any((u) => u.id == user.id)) {
      users = [...users, user];
    }
    await hydrateFromPrisma();
    isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final user = await authRepository.register(name, email, password);
    if (user == null) {
      isLoading = false;
      statusMessage = 'Impossible de créer le compte (e-mail déjà utilisé ou invalide).';
      notifyListeners();
      return false;
    }

    currentUser = user;
    users = [user];
    projects = [];
    columns = [];
    tasks = [];
    subtasks = [];
    milestones = [];
    messages = [];
    files = [];
    activities = [];
    reports = [];
    trainings = [];
    enrollments = [];
    coachingSessions = [];
    coachingGoals = [];
    skillLevels = [];
    await hydrateFromPrisma();
    isLoading = false;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    isPrismaConnected = false;
    notifyListeners();
  }

  Future<bool> joinTeam(String inviteToken) async {
    if (currentUser == null || inviteToken.trim().isEmpty) return false;
    final ok = await authRepository.joinTeam(currentUser!.id, inviteToken.trim());
    if (ok) {
      await hydrateFromPrisma();
    }
    return ok;
  }

  Future<bool> inviteMember(String email, {String role = 'MEMBER'}) async {
    if (currentUser == null || email.trim().isEmpty) return false;
    final ok = await authRepository.inviteMember(currentUser!.id, email.trim(), role: role);
    if (ok) {
      await hydrateFromPrisma();
    }
    return ok;
  }

  Future<bool> updateMemberRole(String targetUserId, UserRole newRole) async {
    if (currentUser == null) return false;
    if (currentUser!.role != UserRole.owner && currentUser!.role != UserRole.admin) return false;
    users = users
        .map((u) => u.id == targetUserId ? u.copyWith(role: newRole) : u)
        .toList();
    notifyListeners();

    final ok = await authRepository.updateMemberRole(
      currentUser!.id,
      targetUserId,
      roleToString(newRole),
    );
    if (ok) {
      await hydrateFromPrisma();
    }
    return ok;
  }

  Future<bool> removeMember(String targetUserId) async {
    if (currentUser == null || targetUserId == currentUser!.id) return false;
    if (currentUser!.role != UserRole.owner && currentUser!.role != UserRole.admin) return false;
    users = users.where((u) => u.id != targetUserId).toList();
    notifyListeners();

    final ok = await authRepository.removeMember(currentUser!.id, targetUserId);
    if (ok) {
      await hydrateFromPrisma();
    }
    return ok;
  }
}

