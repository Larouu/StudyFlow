import '../../core/models/studyflow_models.dart';
import '../studyflow_provider_base.dart';

/// Provider du domaine Agenda, Jalons & Rapports.
mixin CalendarProviderMixin on StudyFlowStoreBase {
  Future<bool> generateReport({String period = 'ALL'}) async {
    if (currentUser == null) return false;
    final doneCols = currentColumns.where((c) => c.isDone).map((c) => c.id).toSet();
    var selectedTasks = currentTasks;
    final now = DateTime.now();
    if (period != 'ALL') {
      final days = int.tryParse(period) ?? 30;
      selectedTasks = currentTasks.where((task) {
        if (task.dueDate == null) return false;
        return task.dueDate!.isAfter(now.subtract(Duration(days: days)));
      }).toList();
    }
    final total = selectedTasks.length;
    final done = selectedTasks.where((t) => doneCols.contains(t.columnId)).length;
    final rate = total > 0 ? ((done / total) * 100).round() : 0;
    final overdue = selectedTasks.where((task) =>
      task.dueDate != null &&
      task.dueDate!.isBefore(now) &&
      !doneCols.contains(task.columnId)
    ).length;

    final success = await calendarRepo.sync('GENERATE_REPORT', currentUser!.id, {
      'projectId': activeProject.id,
      'period': period,
      'totalTasks': total,
      'completedTasks': done,
      'completionRate': rate,
      'overdueTasks': overdue,
    });
    if (!success) {
      statusMessage = 'Impossible de générer le rapport.';
      notifyListeners();
      return false;
    }
    await hydrateFromPrisma();
    statusMessage = null;
    notifyListeners();
    return true;
  }

  Future<void> deleteReport(String reportId) async {
    if (currentUser == null) return;
    reports = reports.where((r) => r.id != reportId).toList();
    notifyListeners();

    await calendarRepo.sync('DELETE_REPORT', currentUser!.id, {'reportId': reportId});
  }

  Future<void> createMilestone({
    required String title,
    required DateTime date,
    String? description,
  }) async {
    if (currentUser == null || currentUser!.isCoachOrViewer) return;
    final m = MilestoneItem(
      id: 'ms-${DateTime.now().millisecondsSinceEpoch}',
      projectId: activeProject.id,
      title: title.trim(),
      date: date,
      description: description?.trim(),
    );
    milestones = [...milestones, m];
    notifyListeners();

    await calendarRepo.sync('CREATE_MILESTONE', currentUser!.id, {
      'projectId': activeProject.id,
      'title': m.title,
      'date': m.date.toIso8601String(),
      'description': m.description,
    });
    await hydrateFromPrisma();
  }

  Future<void> updateMilestone(
    String milestoneId, {
    String? title,
    DateTime? date,
    String? description,
  }) async {
    if (currentUser == null || currentUser!.isCoachOrViewer) return;
    milestones = milestones
        .map((m) => m.id == milestoneId
            ? m.copyWith(title: title?.trim(), date: date, description: description?.trim())
            : m)
        .toList();
    notifyListeners();

    await calendarRepo.sync('UPDATE_MILESTONE', currentUser!.id, {
      'milestoneId': milestoneId,
      if (title != null) 'title': title.trim(),
      if (date != null) 'date': date.toIso8601String(),
      if (description != null) 'description': description.trim(),
    });
  }
}

