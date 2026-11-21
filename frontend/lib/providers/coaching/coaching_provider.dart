import '../../core/models/studyflow_models.dart';
import '../studyflow_provider_base.dart';

/// Provider du domaine Formations, Coaching, Objectifs & Compétences.
mixin CoachingProviderMixin on StudyFlowStoreBase {
  Future<String?> enrollTraining(String trainingId) async {
    if (currentUser == null) return 'Non connecté';
    final tr = trainings.firstWhere((t) => t.id == trainingId);
    final currentCount =
        enrollments.where((e) => e.trainingId == trainingId && e.status == 'ENROLLED').length;
    if (currentCount >= tr.capacity) {
      return 'Formation complète : capacité maximale atteinte.';
    }
    enrollments = [
      ...enrollments,
      TrainingEnrollmentItem(
        id: 'enr-${DateTime.now().millisecondsSinceEpoch}',
        trainingId: trainingId,
        userId: currentUser!.id,
        status: 'ENROLLED',
        attended: false,
      ),
    ];
    notifyListeners();

    await coachingRepo.sync('ENROLL_TRAINING', currentUser!.id, {'trainingId': trainingId});
    return null;
  }

  Future<void> unenrollTraining(String trainingId) async {
    if (currentUser == null) return;
    enrollments = enrollments
        .where((e) => !(e.trainingId == trainingId && e.userId == currentUser!.id))
        .toList();
    notifyListeners();

    await coachingRepo.sync('UNENROLL_TRAINING', currentUser!.id, {'trainingId': trainingId});
  }

  Future<void> createTraining({
    required String title,
    required String description,
    required String skill,
    String level = 'INTERMEDIATE',
    int capacity = 10,
    String mode = 'ONLINE',
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    if (currentUser == null) return;
    final start = startsAt ?? DateTime.now().add(const Duration(days: 3));
    final end = endsAt ?? start.add(const Duration(hours: 2));
    final tr = TrainingItem(
      id: 'tr-${DateTime.now().millisecondsSinceEpoch}',
      teamId: projects.isNotEmpty ? activeProject.teamId : 'team-1',
      title: title.trim(),
      description: description.trim(),
      skill: skill.trim(),
      level: level,
      trainerId: currentUser!.id,
      startsAt: start,
      endsAt: end,
      capacity: capacity,
      mode: mode,
      location: location?.trim(),
    );
    trainings = [...trainings, tr];
    notifyListeners();

    await coachingRepo.sync('CREATE_TRAINING', currentUser!.id, {
      'title': tr.title,
      'description': tr.description,
      'skill': tr.skill,
      'level': tr.level,
      'capacity': tr.capacity,
      'mode': tr.mode,
      'location': tr.location,
      'startsAt': tr.startsAt.toIso8601String(),
      'endsAt': tr.endsAt.toIso8601String(),
    });
    await hydrateFromPrisma();
  }

  Future<void> updateTraining(
    String trainingId, {
    String? title,
    String? description,
    String? skill,
    String? level,
    int? capacity,
    String? mode,
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    if (currentUser == null) return;
    trainings = trainings
        .map((t) => t.id == trainingId
            ? t.copyWith(
                title: title?.trim(),
                description: description?.trim(),
                skill: skill?.trim(),
                level: level,
                capacity: capacity,
                mode: mode,
                location: location?.trim(),
                startsAt: startsAt,
                endsAt: endsAt,
              )
            : t)
        .toList();
    notifyListeners();

    await coachingRepo.sync('UPDATE_TRAINING', currentUser!.id, {
      'trainingId': trainingId,
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (skill != null) 'skill': skill.trim(),
      if (level != null) 'level': level,
      if (capacity != null) 'capacity': capacity,
      if (mode != null) 'mode': mode,
      if (location != null) 'location': location.trim(),
      if (startsAt != null) 'startsAt': startsAt.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
    });
  }

  Future<void> deleteTraining(String trainingId) async {
    if (currentUser == null) return;
    trainings = trainings.where((t) => t.id != trainingId).toList();
    enrollments = enrollments.where((e) => e.trainingId != trainingId).toList();
    notifyListeners();

    await coachingRepo.sync('DELETE_TRAINING', currentUser!.id, {'trainingId': trainingId});
  }

  Future<void> requestCoaching({
    required String coachId,
    required String topic,
    required int durationMin,
    required String mode,
    DateTime? proposedSlot,
    List<DateTime>? proposedSlots,
  }) async {
    if (currentUser == null) return;
    final slots = (proposedSlots != null && proposedSlots.isNotEmpty)
        ? proposedSlots.map((s) => s.toIso8601String()).toList()
        : [(proposedSlot ?? DateTime.now().add(const Duration(days: 2))).toIso8601String()];
    coachingSessions = [
      CoachingSessionItem(
        id: 'cs-${DateTime.now().millisecondsSinceEpoch}',
        coachId: coachId,
        coacheeId: currentUser!.id,
        topic: topic,
        proposedSlots: slots,
        durationMin: durationMin,
        mode: mode,
        status: 'REQUESTED',
      ),
      ...coachingSessions,
    ];
    notifyListeners();

    await coachingRepo.sync('REQUEST_COACHING', currentUser!.id, {
      'coachId': coachId,
      'topic': topic,
      'proposedSlots': slots,
      'durationMin': durationMin,
      'mode': mode,
      'projectId': activeProject.id,
    });
    await hydrateFromPrisma();
  }

  Future<void> confirmCoaching(String sessionId, String slotIso) async {
    if (currentUser == null) return;
    coachingSessions = coachingSessions
        .map((s) => s.id == sessionId
            ? s.copyWith(status: 'CONFIRMED', scheduledAt: DateTime.tryParse(slotIso) ?? DateTime.now())
            : s)
        .toList();
    notifyListeners();

    await coachingRepo.sync('CONFIRM_COACHING', currentUser!.id, {
      'sessionId': sessionId,
      'scheduledAt': slotIso,
    });
    await hydrateFromPrisma();
  }

  Future<void> completeCoaching(String sessionId, String sharedReport, String? privateNotes) async {
    if (currentUser == null) return;
    coachingSessions = coachingSessions
        .map((s) => s.id == sessionId
            ? s.copyWith(
                status: 'DONE',
                sharedReport: sharedReport,
                privateNotes: s.coachId == currentUser!.id ? privateNotes : s.privateNotes,
              )
            : s)
        .toList();
    notifyListeners();

    await coachingRepo.sync('COMPLETE_COACHING', currentUser!.id, {
      'sessionId': sessionId,
      'sharedReport': sharedReport,
      'privateNotes': privateNotes,
    });
  }

  Future<void> deleteCoaching(String sessionId) async {
    if (currentUser == null) return;
    coachingSessions = coachingSessions.where((s) => s.id != sessionId).toList();
    notifyListeners();

    await coachingRepo.sync('DELETE_COACHING', currentUser!.id, {'sessionId': sessionId});
  }

  Future<void> rescheduleCoaching(String sessionId, String slotIso) async {
    if (currentUser == null) return;
    coachingSessions = coachingSessions
        .map((s) => s.id == sessionId
            ? s.copyWith(status: 'RESCHEDULED', scheduledAt: DateTime.tryParse(slotIso) ?? DateTime.now())
            : s)
        .toList();
    notifyListeners();

    await coachingRepo.sync('RESCHEDULE_COACHING', currentUser!.id, {
      'sessionId': sessionId,
      'scheduledAt': slotIso,
    });
    await hydrateFromPrisma();
  }

  Future<void> cancelCoaching(String sessionId) async {
    if (currentUser == null) return;
    coachingSessions = coachingSessions
        .map((s) => s.id == sessionId ? s.copyWith(status: 'CANCELLED') : s)
        .toList();
    notifyListeners();

    await coachingRepo.sync('CANCEL_COACHING', currentUser!.id, {'sessionId': sessionId});
  }

  Future<void> addFeedback({
    required String targetType,
    required String targetId,
    required int rating,
    String? comment,
  }) async {
    if (currentUser == null) return;
    final fb = FeedbackItem(
      id: 'fb-${DateTime.now().millisecondsSinceEpoch}',
      targetType: targetType,
      targetId: targetId,
      authorId: currentUser!.id,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    feedbacks = [fb, ...feedbacks];
    notifyListeners();

    await coachingRepo.sync('ADD_FEEDBACK', currentUser!.id, {
      'targetType': targetType,
      'targetId': targetId,
      'rating': rating,
      'comment': comment,
    });
    await hydrateFromPrisma();
  }

  Future<void> addTrainingResource({
    required String trainingId,
    required String title,
    String? url,
  }) async {
    if (currentUser == null) return;
    final res = TrainingResourceItem(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      trainingId: trainingId,
      title: title,
      url: url,
    );
    trainingResources = [...trainingResources, res];
    notifyListeners();

    await coachingRepo.sync('ADD_TRAINING_RESOURCE', currentUser!.id, {
      'trainingId': trainingId,
      'title': title,
      'url': url,
    });
    await hydrateFromPrisma();
  }

  Future<void> deleteTrainingResource(String resourceId) async {
    if (currentUser == null) return;
    trainingResources = trainingResources.where((r) => r.id != resourceId).toList();
    notifyListeners();

    await coachingRepo.sync('DELETE_TRAINING_RESOURCE', currentUser!.id, {
      'resourceId': resourceId,
    });
  }

  Future<void> markTrainingAttendance(String enrollmentId, bool attended) async {
    if (currentUser == null) return;
    enrollments = enrollments
        .map((e) => e.id == enrollmentId ? e.copyWith(attended: attended) : e)
        .toList();
    notifyListeners();

    await coachingRepo.sync('MARK_ATTENDANCE', currentUser!.id, {
      'enrollmentId': enrollmentId,
      'attended': attended,
    });
  }

  Future<void> updateGoalProgress(String goalId, int progress) async {
    if (currentUser == null) return;
    coachingGoals = coachingGoals
        .map((g) => g.id == goalId
            ? g.copyWith(progress: progress, status: progress >= 100 ? 'ACHIEVED' : 'OPEN')
            : g)
        .toList();
    notifyListeners();

    await coachingRepo.sync('UPDATE_GOAL_PROGRESS', currentUser!.id, {
      'goalId': goalId,
      'progress': progress,
    });
  }

  Future<void> createGoal({required String title, required String skill}) async {
    if (currentUser == null || title.trim().isEmpty || skill.trim().isEmpty) return;
    final created = CoachingGoalItem(
      id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser!.id,
      title: title.trim(),
      skill: skill.trim(),
      progress: 0,
      status: 'OPEN',
    );
    coachingGoals = [created, ...coachingGoals];
    notifyListeners();

    await coachingRepo.sync('CREATE_GOAL', currentUser!.id, {
      'title': title.trim(),
      'skill': skill.trim(),
    });
    await hydrateFromPrisma();
  }

  Future<void> deleteGoal(String goalId) async {
    if (currentUser == null) return;
    coachingGoals = coachingGoals.where((g) => g.id != goalId).toList();
    notifyListeners();

    await coachingRepo.sync('DELETE_GOAL', currentUser!.id, {'goalId': goalId});
  }

  Future<void> assessSkill({
    required String targetUserId,
    required String skill,
    required int level,
    bool selfAssessed = true,
  }) async {
    if (currentUser == null || skill.trim().isEmpty) return;
    final trimmedSkill = skill.trim();
    final existingIdx = skillLevels.indexWhere(
      (s) => s.userId == targetUserId && s.skill.toLowerCase() == trimmedSkill.toLowerCase(),
    );
    if (existingIdx != -1) {
      skillLevels = [
        for (var i = 0; i < skillLevels.length; i++)
          if (i == existingIdx)
            skillLevels[i].copyWith(level: level, selfAssessed: selfAssessed)
          else
            skillLevels[i],
      ];
    } else {
      skillLevels = [
        ...skillLevels,
        SkillLevelItem(
          id: 'sk-${DateTime.now().millisecondsSinceEpoch}',
          userId: targetUserId,
          skill: trimmedSkill,
          level: level,
          selfAssessed: selfAssessed,
        ),
      ];
    }
    notifyListeners();

    await coachingRepo.sync('ASSESS_SKILL', currentUser!.id, {
      'targetUserId': targetUserId,
      'skill': trimmedSkill,
      'level': level,
      'selfAssessed': selfAssessed,
    });
    await hydrateFromPrisma();
  }

  Future<void> deleteSkill(String skillId) async {
    if (currentUser == null) return;
    skillLevels = skillLevels.where((s) => s.id != skillId).toList();
    notifyListeners();

    await coachingRepo.sync('DELETE_SKILL', currentUser!.id, {'skillId': skillId});
  }
}

