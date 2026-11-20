import 'package:flutter/material.dart';
import '../../core/models/studyflow_models.dart';
import '../../providers/studyflow_provider.dart';
import '../../widgets/ai_insights_panel.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});
  final StudyFlowStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _onlyMyTasks = false;
  String _columnFilter = 'ALL';
  TaskPriority? _priorityFilter;
  String _search = '';
  String _sortBy = 'DUE';

  int _priorityRank(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgente:
        return 4;
      case TaskPriority.haute:
        return 3;
      case TaskPriority.normale:
        return 2;
      case TaskPriority.basse:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser!;
    final columns = widget.store.currentColumns;
    final doneIds = columns.where((c) => c.isDone).map((c) => c.id).toSet();
    final allTasks = widget.store.currentTasks;
    final now = DateTime.now();

    final totalCount = allTasks.length;
    final doneCount = allTasks.where((t) => doneIds.contains(t.columnId)).length;
    final overdueCount = allTasks
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(now) && !doneIds.contains(t.columnId))
        .length;

    final tasks = allTasks.where((t) {
      if (_columnFilter != 'ALL' && t.columnId != _columnFilter) return false;
      if (_onlyMyTasks && !t.assigneeIds.contains(user.id)) return false;
      if (_priorityFilter != null && t.priority != _priorityFilter) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    tasks.sort((a, b) {
      if (_sortBy == 'PRIORITY') {
        return _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
      }
      if (_sortBy == 'TITLE') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      final ad = a.dueDate ?? DateTime(2099);
      final bd = b.dueDate ?? DateTime(2099);
      return ad.compareTo(bd);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AiInsightsPanel(
            store: widget.store,
            module: 'tasks',
            title: 'Assistant IA des tâches',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              _StatBadge(label: 'Total', value: '$totalCount', color: const Color(0xFF818CF8)),
              const SizedBox(width: 8),
              _StatBadge(label: 'En retard', value: '$overdueCount', color: Colors.redAccent),
              const SizedBox(width: 8),
              _StatBadge(label: 'Terminées', value: '$doneCount', color: Colors.teal),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une tâche…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    selected: _onlyMyTasks,
                    label: Text('Mes tâches (${user.name.split(' ').first})'),
                    onSelected: (v) => setState(() => _onlyMyTasks = v),
                  ),
                  DropdownButton<String>(
                    value: _columnFilter,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('Toutes les colonnes')),
                      ...columns.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => _columnFilter = v ?? 'ALL'),
                  ),
                  DropdownButton<TaskPriority?>(
                    value: _priorityFilter,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<TaskPriority?>(value: null, child: Text('Toutes priorités')),
                      ...TaskPriority.values.map(
                        (p) => DropdownMenuItem<TaskPriority?>(value: p, child: Text(priorityToString(p))),
                      ),
                    ],
                    onChanged: (v) => setState(() => _priorityFilter = v),
                  ),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'DUE', child: Text('Tri : Échéance')),
                      DropdownMenuItem(value: 'PRIORITY', child: Text('Tri : Priorité')),
                      DropdownMenuItem(value: 'TITLE', child: Text('Tri : Titre')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v ?? 'DUE'),
                  ),
                  if (!user.isCoachOrViewer)
                    FilledButton.icon(
                      onPressed: () => _openAiCreateTaskDialog(context),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Tâche IA'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const Center(child: Text('Aucune tâche trouvée', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final task = tasks[idx];
                    final col = columns.isEmpty
                        ? null
                        : columns.firstWhere((c) => c.id == task.columnId, orElse: () => columns.first);
                    final subs = widget.store.subtasks.where((s) => s.taskId == task.id).toList();
                    final doneSubs = subs.where((s) => s.done).length;
                    final isOverdue = task.dueDate != null &&
                        task.dueDate!.isBefore(now) &&
                        !(col?.isDone ?? false);

                    return Card(
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priorityToString(task.priority),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(col?.name ?? 'Sans colonne', style: const TextStyle(fontSize: 11, color: Color(0xFF818CF8))),
                            if (task.dueDate != null)
                              Text(
                                '${task.dueDate!.day}/${task.dueDate!.month}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOverdue ? Colors.redAccent : Colors.grey,
                                  fontWeight: isOverdue ? FontWeight.bold : null,
                                ),
                              ),
                            if (subs.isNotEmpty)
                              Text('$doneSubs/${subs.length} sous-tâches', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        children: [
                          if (task.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(task.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            ),
                          ...subs.map(
                            (s) => CheckboxListTile(
                              value: s.done,
                              dense: true,
                              title: Text(s.title, style: const TextStyle(fontSize: 13)),
                              onChanged: user.isCoachOrViewer ? null : (_) => widget.store.toggleSubtask(s.id),
                            ),
                          ),
                          if (!user.isCoachOrViewer)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Génération des sous-tâches IA…')),
                                    );
                                    final res = await widget.store.aiGenerateSubtasks(task.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res != null
                                                ? '${res['subtasksCreated']} sous-tâches ajoutées à « ${task.title} ».'
                                                : 'Échec de la génération des sous-tâches.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.auto_awesome, size: 15),
                                  label: const Text('Découper avec IA', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openAiCreateTaskDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 20),
            SizedBox(width: 8),
            Text('Créer tâche + sous-tâches IA'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Décrivez la tâche',
              hintText: 'Ex : Préparer la soutenance finale avec slides et démo',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final res = await widget.store.aiGenerateTask(prompt: ctrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res != null
                ? 'Tâche IA créée avec ${res['subtasksCreated']} sous-tâches.'
                : 'Échec de la création IA.',
          ),
        ),
      );
    }
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
