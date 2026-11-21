import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/studyflow_models.dart';
import '../../providers/studyflow_provider.dart';
import '../../widgets/ai_insights_panel.dart';

class TrainingCoachingScreen extends StatelessWidget {
  const TrainingCoachingScreen({super.key, required this.store});
  final StudyFlowStore store;

  Future<void> _openMeeting(String url, BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la visioconférence.')),
      );
    }
  }

  Future<void> _copyMeeting(String url, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien de visioconférence copié.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = store.currentUser!;
    final canManageTraining =
        user.role == UserRole.coach || user.role == UserRole.owner;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AiInsightsPanel(
              store: store,
              module: 'coaching',
              title: 'Assistant IA formation & coaching',
            ),
          ),
          TabBar(
            isScrollable: MediaQuery.sizeOf(context).width < 480,
            tabs: [
              Tab(icon: const Icon(Icons.school_outlined), text: 'Formations (${store.trainings.length})'),
              Tab(icon: const Icon(Icons.psychology_outlined), text: 'Coaching (${store.coachingSessions.length})'),
              const Tab(icon: Icon(Icons.track_changes_outlined), text: 'Compétences'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. Catalogue de Formations
                Column(
                  children: [
                    if (canManageTraining)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openTrainingDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Nouvelle formation'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: store.trainings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final tr = store.trainings[idx];
                          final enrolled = store.enrollments
                              .where((e) => e.trainingId == tr.id && e.status == 'ENROLLED')
                              .toList();
                          final isEnrolled = enrolled.any((e) => e.userId == user.id);
                          final isFull = enrolled.length >= tr.capacity;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(tr.skill, style: const TextStyle(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${tr.mode} · ${tr.level}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ),
                                      Text(
                                        '${enrolled.length}/${tr.capacity} places',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isFull ? Colors.redAccent : Colors.teal,
                                        ),
                                      ),
                                      if (canManageTraining) ...[
                                        IconButton(
                                          tooltip: 'Modifier',
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => _openTrainingDialog(context, existing: tr),
                                        ),
                                        IconButton(
                                          tooltip: 'Supprimer',
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          onPressed: () => store.deleteTraining(tr.id),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(tr.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(tr.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  if (tr.mode == 'ONLINE') ...[
                                    if (tr.meetingUrl != null)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton.icon(
                                            onPressed: () => _openMeeting(tr.meetingUrl!, context),
                                            icon: const Icon(Icons.video_camera_front_outlined, size: 17),
                                            label: const Text('Rejoindre la formation'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _copyMeeting(tr.meetingUrl!, context),
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('Copier le lien'),
                                          ),
                                        ],
                                      )
                                    else
                                      OutlinedButton.icon(
                                        onPressed: () => _openMeeting(
                                          'https://meet.jit.si/studyflow-training-${tr.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').padRight(12, 'x').substring(0, 12)}',
                                          context,
                                        ),
                                        icon: const Icon(Icons.video_camera_front_outlined, size: 17),
                                        label: const Text('Créer / rejoindre la visio'),
                                      ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (isEnrolled)
                                    OutlinedButton.icon(
                                      onPressed: () => store.unenrollTraining(tr.id),
                                      icon: const Icon(Icons.check_circle_outline, color: Colors.teal),
                                      label: const Text('Inscrit (Se désinscrire)'),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: isFull
                                          ? null
                                          : () async {
                                              final err = await store.enrollTraining(tr.id);
                                              if (err != null && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                              }
                                            },
                                      child: Text(isFull ? 'Formation complète' : 'S\'inscrire à la formation'),
                                    ),
                                  const SizedBox(height: 10),
                                  // Ressources pédagogiques
                                  ...() {
                                    final resources = store.trainingResources
                                        .where((r) => r.trainingId == tr.id)
                                        .toList();
                                    final trFeedbacks = store.feedbacks
                                        .where((f) => f.targetType == 'TRAINING' && f.targetId == tr.id)
                                        .toList();
                                    return [
                                      if (resources.isNotEmpty) ...[
                                        const Text('Ressources :',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: resources
                                              .map((r) => InputChip(
                                                    avatar: const Icon(Icons.link, size: 14),
                                                    label: Text(r.title, style: const TextStyle(fontSize: 11)),
                                                    onPressed: r.url != null && r.url!.isNotEmpty
                                                        ? () => _openMeeting(r.url!, context)
                                                        : null,
                                                    onDeleted: canManageTraining
                                                        ? () => store.deleteTrainingResource(r.id)
                                                        : null,
                                                  ))
                                              .toList(),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (canManageTraining) ...[
                                            ActionChip(
                                              avatar: const Icon(Icons.attach_file, size: 15),
                                              label: const Text('Ressource', style: TextStyle(fontSize: 11)),
                                              onPressed: () => _openAddResourceDialog(context, tr.id),
                                            ),
                                            ActionChip(
                                              avatar: const Icon(Icons.fact_check_outlined, size: 15),
                                              label: Text(
                                                'Présences (${enrolled.where((e) => e.attended).length}/${enrolled.length})',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              onPressed: () => _openAttendanceDialog(context, tr, enrolled),
                                            ),
                                          ],
                                          if (isEnrolled || canManageTraining)
                                            ActionChip(
                                              avatar: const Icon(Icons.star_outline, size: 15, color: Colors.amber),
                                              label: Text(
                                                trFeedbacks.isEmpty
                                                    ? 'Laisser un avis'
                                                    : 'Avis (${trFeedbacks.length} · ${(trFeedbacks.map((f) => f.rating).reduce((a, b) => a + b) / trFeedbacks.length).toStringAsFixed(1)}★)',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              onPressed: () => _openFeedbackDialog(
                                                context,
                                                targetType: 'TRAINING',
                                                targetId: tr.id,
                                                existing: trFeedbacks,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ];
                                  }(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // 2. Espace Coaching (avec Notes Privées strictement réservées au Coach)
                Column(
                  children: [
                    if (!user.isCoach)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openRequestCoaching(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Demander un coaching'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: store.coachingSessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final cs = store.coachingSessions[idx];
                          final isCoachAuthor = user.id == cs.coachId;
                          final coachee = store.users.firstWhere(
                            (u) => u.id == cs.coacheeId,
                            orElse: () => user,
                          );
                          final coach = store.users.firstWhere(
                            (u) => u.id == cs.coachId,
                            orElse: () => user,
                          );
                          final slotDate = cs.scheduledAt ??
                              (cs.proposedSlots.isNotEmpty
                                  ? DateTime.tryParse(cs.proposedSlots.first)
                                  : null);

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _StatusBadge(status: cs.status),
                                      const SizedBox(width: 8),
                                      Text('${cs.durationMin} min · ${cs.mode}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      const Spacer(),
                                      Text('Coach : ${coach.name} · Étudiant : ${coachee.name}',
                                          style: const TextStyle(fontSize: 11)),
                                      if (isCoachAuthor ||
                                          user.id == cs.coacheeId ||
                                          user.role == UserRole.owner)
                                        IconButton(
                                          tooltip: 'Supprimer la séance',
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          onPressed: () => store.deleteCoaching(cs.id),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(cs.topic, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  if (slotDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${cs.scheduledAt != null ? 'Confirmé le' : 'Créneau proposé :'} '
                                      '${slotDate.day.toString().padLeft(2, '0')}/${slotDate.month.toString().padLeft(2, '0')}/${slotDate.year} '
                                      'à ${slotDate.hour.toString().padLeft(2, '0')}:${slotDate.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                  if (cs.mode == 'ONLINE' &&
                                      cs.status == 'CONFIRMED' &&
                                      cs.meetingUrl != null) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => _openMeeting(cs.meetingUrl!, context),
                                          icon: const Icon(Icons.video_camera_front_outlined, size: 17),
                                          label: const Text('Rejoindre la séance'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _copyMeeting(cs.meetingUrl!, context),
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Copier le lien'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (cs.sharedReport != null && cs.sharedReport!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Synthèse partagée :',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(cs.sharedReport!, style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Confidentialité stricte des notes privées (§7.3)
                                  if (isCoachAuthor)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B0764).withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.lock_open, size: 14, color: Color(0xFFD8B4FE)),
                                              SizedBox(width: 6),
                                              Text(
                                                'Notes privées du Coach (Déverrouillées)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD8B4FE),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            cs.privateNotes?.isNotEmpty == true
                                                ? cs.privateNotes!
                                                : 'Aucune note privée enregistrée.',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFFF3E8FF)),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Notes privées réservées exclusivement au Coach',
                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (isCoachAuthor && (cs.status == 'REQUESTED' || cs.status == 'RESCHEDULED')) ...[
                                    const SizedBox(height: 10),
                                    if (cs.proposedSlots.length > 1 && cs.status == 'REQUESTED') ...[
                                      const Text('Créneaux proposés :',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: cs.proposedSlots.map((slotIso) {
                                          final dt = DateTime.tryParse(slotIso);
                                          final label = dt != null
                                              ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                              : slotIso;
                                          return ActionChip(
                                            avatar: const Icon(Icons.check, size: 15),
                                            label: Text('Confirmer $label', style: const TextStyle(fontSize: 11)),
                                            onPressed: () => store.confirmCoaching(cs.id, slotIso),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (cs.status == 'REQUESTED' && cs.proposedSlots.length <= 1)
                                          FilledButton(
                                            onPressed: () => store.confirmCoaching(
                                              cs.id,
                                              cs.proposedSlots.isNotEmpty
                                                  ? cs.proposedSlots.first
                                                  : DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                                            ),
                                            child: const Text('Confirmer le créneau'),
                                          ),
                                        OutlinedButton.icon(
                                          onPressed: () => _pickRescheduleSlot(context, cs),
                                          icon: const Icon(Icons.schedule, size: 16),
                                          label: const Text('Reprogrammer'),
                                        ),
                                        TextButton(
                                          onPressed: () => store.cancelCoaching(cs.id),
                                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                          child: const Text('Annuler'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (!isCoachAuthor &&
                                      user.id == cs.coacheeId &&
                                      (cs.status == 'REQUESTED' || cs.status == 'RESCHEDULED')) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => store.cancelCoaching(cs.id),
                                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                                      label: const Text('Annuler ma demande', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                  if (isCoachAuthor && (cs.status == 'CONFIRMED' || cs.status == 'RESCHEDULED')) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        FilledButton(
                                          onPressed: () => _openCompleteCoaching(context, cs),
                                          child: const Text('Clôturer & Rédiger la synthèse'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _pickRescheduleSlot(context, cs),
                                          icon: const Icon(Icons.schedule, size: 16),
                                          label: const Text('Reprogrammer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (cs.status == 'DONE') ...[
                                    const SizedBox(height: 8),
                                    ...() {
                                      final csFeedbacks = store.feedbacks
                                          .where((f) => f.targetType == 'SESSION' && f.targetId == cs.id)
                                          .toList();
                                      return [
                                        ActionChip(
                                          avatar: const Icon(Icons.star_outline, size: 15, color: Colors.amber),
                                          label: Text(
                                            csFeedbacks.isEmpty
                                                ? 'Évaluer la séance'
                                                : 'Avis (${csFeedbacks.length} · ${(csFeedbacks.map((f) => f.rating).reduce((a, b) => a + b) / csFeedbacks.length).toStringAsFixed(1)}★)',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          onPressed: () => _openFeedbackDialog(
                                            context,
                                            targetType: 'SESSION',
                                            targetId: cs.id,
                                            existing: csFeedbacks,
                                          ),
                                        ),
                                      ];
                                    }(),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // 3. Objectifs & Compétences
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Objectifs de progression', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        FilledButton.tonalIcon(
                          onPressed: () => _openCreateGoalDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Objectif'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (store.coachingGoals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Aucun objectif défini. Créez-en un depuis une compétence ci-dessous ou via "+ Objectif".',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ...store.coachingGoals.map((g) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  Chip(
                                    label: Text(g.status, style: const TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer l\'objectif',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => store.deleteGoal(g.id),
                                  ),
                                ],
                              ),
                              Text('${g.skill} · ${g.progress}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Slider(
                                value: g.progress.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 10,
                                label: '${g.progress}%',
                                onChanged: (val) => store.updateGoalProgress(g.id, val.round()),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Matrice de compétences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        FilledButton.tonalIcon(
                          onPressed: () => _openAssessSkillDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Évaluer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...store.skillLevels.map((sk) {
                      final owner = store.users.firstWhere((u) => u.id == sk.userId, orElse: () => user);
                      final canEdit = sk.userId == user.id || user.isCoach || user.role == UserRole.owner;
                      final hasGoal = store.coachingGoals.any(
                        (g) => g.skill.toLowerCase() == sk.skill.toLowerCase() && g.userId == sk.userId,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: canEdit
                              ? () => _openAssessSkillDialog(
                                    context,
                                    initialSkill: sk.skill,
                                    initialLevel: sk.level,
                                    targetUserId: sk.userId,
                                  )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${sk.skill} · ${owner.name}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sk.selfAssessed ? 'Auto-évalué' : 'Évalué par coach',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Niveau ${sk.level}/5',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: sk.level < 3 ? Colors.amber : const Color(0xFF818CF8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (canEdit)
                                      ActionChip(
                                        avatar: const Icon(Icons.edit_outlined, size: 15),
                                        label: const Text('Modifier niveau', style: TextStyle(fontSize: 11)),
                                        onPressed: () => _openAssessSkillDialog(
                                          context,
                                          initialSkill: sk.skill,
                                          initialLevel: sk.level,
                                          targetUserId: sk.userId,
                                        ),
                                      ),
                                    if (!hasGoal)
                                      ActionChip(
                                        avatar: const Icon(Icons.flag_outlined, size: 15),
                                        label: const Text('Créer objectif', style: TextStyle(fontSize: 11)),
                                        onPressed: () async {
                                          await store.createGoal(
                                            title: 'Progresser en ${sk.skill}',
                                            skill: sk.skill,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Objectif ajouté pour ${sk.skill}')),
                                          );
                                        },
                                      ),
                                    if (!user.isCoach)
                                      ActionChip(
                                        avatar: const Icon(Icons.psychology_outlined, size: 15),
                                        label: const Text('Coaching', style: TextStyle(fontSize: 11)),
                                        onPressed: () => _openRequestCoaching(
                                          context,
                                          initialTopic: 'Renforcer : ${sk.skill}',
                                        ),
                                      ),
                                    if (canEdit)
                                      ActionChip(
                                        avatar: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                                        label: const Text('Supprimer', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                        onPressed: () => store.deleteSkill(sk.id),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRequestCoaching(BuildContext context, {String? initialTopic}) {
    final topicCtrl = TextEditingController(text: initialTopic ?? '');
    final coaches = store.users.where((u) => u.isCoach).toList();
    final selectableCoaches = coaches.isNotEmpty
        ? coaches
        : store.users.where((u) => u.id != store.currentUser?.id).toList();
    final users = selectableCoaches.isNotEmpty ? selectableCoaches : store.users;
    final defaultCoach = users.first;
    var selectedCoachId = defaultCoach.id;
    var selectedDuration = 45;
    var selectedMode = 'ONLINE';
    final firstSlot = DateTime.now().add(const Duration(days: 1));
    final proposedSlots = <DateTime>[
      DateTime(firstSlot.year, firstSlot.month, firstSlot.day, 14, 0),
    ];

    String fmtSlot(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Demander une séance de coaching'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCoachId,
                  decoration: const InputDecoration(labelText: 'Coach / Mentor'),
                  items: users
                      .map((u) => DropdownMenuItem(
                            value: u.id,
                            child: Text('${u.name} (${roleToString(u.role)})'),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedCoachId = v ?? defaultCoach.id),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sujet',
                    hintText: 'Ex: Architecture & Tests',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedDuration,
                        decoration: const InputDecoration(labelText: 'Durée'),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 45, child: Text('45 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                          DropdownMenuItem(value: 90, child: Text('90 min')),
                        ],
                        onChanged: (v) => setStateDialog(() => selectedDuration = v ?? 45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedMode,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const [
                          DropdownMenuItem(value: 'ONLINE', child: Text('En ligne')),
                          DropdownMenuItem(value: 'ONSITE', child: Text('Présentiel')),
                        ],
                        onChanged: (v) => setStateDialog(() => selectedMode = v ?? 'ONLINE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < proposedSlots.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text('Créneau ${i + 1} : ${fmtSlot(proposedSlots[i])}',
                        style: const TextStyle(fontSize: 13)),
                    trailing: proposedSlots.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setStateDialog(() => proposedSlots.removeAt(i)),
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: proposedSlots[i],
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(proposedSlots[i]),
                      );
                      setStateDialog(() {
                        proposedSlots[i] = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? proposedSlots[i].hour,
                          time?.minute ?? proposedSlots[i].minute,
                        );
                      });
                    },
                  ),
                if (proposedSlots.length < 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setStateDialog(() {
                        final next = proposedSlots.last.add(const Duration(days: 1));
                        proposedSlots.add(next);
                      }),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Proposer un autre créneau (max 3)', style: TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (topicCtrl.text.trim().isEmpty) return;
                store.requestCoaching(
                  coachId: selectedCoachId,
                  topic: topicCtrl.text.trim(),
                  durationMin: selectedDuration,
                  mode: selectedMode,
                  proposedSlots: proposedSlots,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompleteCoaching(BuildContext context, CoachingSessionItem cs) {
    final sharedCtrl = TextEditingController();
    final privateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synthèse de coaching'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sharedCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Synthèse partagée (visible par l\'étudiant)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: privateCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes privées (strictement confidentielles)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              store.completeCoaching(cs.id, sharedCtrl.text.trim(), privateCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _openTrainingDialog(BuildContext context, {TrainingItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final skillCtrl = TextEditingController(text: existing?.skill ?? '');
    final capCtrl = TextEditingController(text: (existing?.capacity ?? 12).toString());
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    var mode = existing?.mode ?? 'ONLINE';
    final defaultStart = existing?.startsAt ?? DateTime.now().add(const Duration(days: 1));
    var startsAt = DateTime(defaultStart.year, defaultStart.month, defaultStart.day, defaultStart.hour, 0);
    var endsAt = existing?.endsAt ?? startsAt.add(const Duration(hours: 2));

    String fmtDateTime(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle formation' : 'Modifier la formation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: skillCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Compétence',
                    hintText: 'Ex: Flutter, Architecture, Git...',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: capCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Capacité'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const [
                          DropdownMenuItem(value: 'ONLINE', child: Text('En ligne')),
                          DropdownMenuItem(value: 'ONSITE', child: Text('Présentiel')),
                        ],
                        onChanged: (v) => setStateDialog(() => mode = v ?? 'ONLINE'),
                      ),
                    ),
                  ],
                ),
                if (mode == 'ONSITE') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Lieu / Salle'),
                  ),
                ],
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline, size: 20),
                  title: Text('Début : ${fmtDateTime(startsAt)}', style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: startsAt,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(startsAt),
                    );
                    setStateDialog(() {
                      startsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time?.hour ?? startsAt.hour,
                        time?.minute ?? startsAt.minute,
                      );
                      if (!endsAt.isAfter(startsAt)) {
                        endsAt = startsAt.add(const Duration(hours: 2));
                      }
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop_circle_outlined, size: 20),
                  title: Text('Fin : ${fmtDateTime(endsAt)}', style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: endsAt.isAfter(startsAt) ? endsAt : startsAt,
                      firstDate: startsAt,
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(endsAt),
                    );
                    setStateDialog(() {
                      endsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time?.hour ?? endsAt.hour,
                        time?.minute ?? endsAt.minute,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final cap = int.tryParse(capCtrl.text.trim()) ?? 10;
                final skill = skillCtrl.text.trim().isEmpty ? 'Général' : skillCtrl.text.trim();
                final loc = mode == 'ONSITE' && locationCtrl.text.trim().isNotEmpty
                    ? locationCtrl.text.trim()
                    : null;
                if (existing == null) {
                  store.createTraining(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    skill: skill,
                    capacity: cap,
                    mode: mode,
                    location: loc,
                    startsAt: startsAt,
                    endsAt: endsAt,
                  );
                } else {
                  store.updateTraining(
                    existing.id,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    skill: skill,
                    capacity: cap,
                    mode: mode,
                    location: loc,
                    startsAt: startsAt,
                    endsAt: endsAt,
                  );
                }
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAssessSkillDialog(
    BuildContext context, {
    String? initialSkill,
    int initialLevel = 3,
    String? targetUserId,
  }) {
    final user = store.currentUser!;
    final skillCtrl = TextEditingController(text: initialSkill ?? '');
    var selectedLevel = initialLevel.clamp(1, 5);
    final resolvedTargetId = targetUserId ?? user.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(initialSkill == null ? 'Évaluer une compétence' : 'Modifier : $initialSkill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: skillCtrl,
                decoration: const InputDecoration(
                  labelText: 'Compétence (existante ou personnalisée)',
                  hintText: 'Ex: Flutter, Architecture, Leadership...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Niveau : $selectedLevel / 5', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(5, (i) {
                      final lvl = i + 1;
                      return IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        icon: Icon(
                          lvl <= selectedLevel ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 22,
                        ),
                        onPressed: () => setStateDialog(() => selectedLevel = lvl),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (skillCtrl.text.trim().isEmpty) return;
                store.assessSkill(
                  targetUserId: resolvedTargetId,
                  skill: skillCtrl.text.trim(),
                  level: selectedLevel,
                  selfAssessed: !user.isCoach,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateGoalDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final skillCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvel objectif de progression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Objectif',
                hintText: 'Ex: Maîtriser les tests Flutter',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: skillCtrl,
              decoration: const InputDecoration(
                labelText: 'Compétence associée',
                hintText: 'Ex: Flutter, DevOps, IA...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || skillCtrl.text.trim().isEmpty) return;
              await store.createGoal(
                title: titleCtrl.text.trim(),
                skill: skillCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRescheduleSlot(BuildContext context, CoachingSessionItem cs) async {
    final initial = cs.scheduledAt ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final nextSlot = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );
    await store.rescheduleCoaching(cs.id, nextSlot.toIso8601String());
  }

  void _openAddResourceDialog(BuildContext context, String trainingId) {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une ressource'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre', hintText: 'Ex: Slides Flutter'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL (optionnel)', hintText: 'https://...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await store.addTrainingResource(
                trainingId: trainingId,
                title: titleCtrl.text.trim(),
                url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _openAttendanceDialog(
    BuildContext context,
    TrainingItem tr,
    List<TrainingEnrollmentItem> enrolled,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Présences · ${tr.title}'),
          content: SizedBox(
            width: 360,
            child: enrolled.isEmpty
                ? const Text('Aucun inscrit pour le moment.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: enrolled.map((e) {
                      final member = store.users.firstWhere(
                        (u) => u.id == e.userId,
                        orElse: () => store.currentUser!,
                      );
                      final current = store.enrollments.firstWhere(
                        (item) => item.id == e.id,
                        orElse: () => e,
                      );
                      return CheckboxListTile(
                        title: Text(member.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(member.email, style: const TextStyle(fontSize: 11)),
                        value: current.attended,
                        onChanged: (val) async {
                          await store.markTrainingAttendance(e.id, val ?? false);
                          setStateDialog(() {});
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  void _openFeedbackDialog(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required List<FeedbackItem> existing,
  }) {
    var rating = 5;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(targetType == 'TRAINING' ? 'Avis sur la formation' : 'Avis sur la séance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing.isNotEmpty) ...[
                  const Text('Avis précédents :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...existing.take(4).map((f) {
                    final author = store.users.firstWhere(
                      (u) => u.id == f.authorId,
                      orElse: () => store.currentUser!,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${author.name} (${f.rating}★) : ${f.comment?.isNotEmpty == true ? f.comment : 'Sans commentaire'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  }),
                  const Divider(),
                ],
                Row(
                  children: [
                    const Text('Note : ', style: TextStyle(fontSize: 13)),
                    for (var s = 1; s <= 5; s++)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          s <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 22,
                        ),
                        onPressed: () => setStateDialog(() => rating = s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Commentaire (optionnel)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                await store.addFeedback(
                  targetType: targetType,
                  targetId: targetId,
                  rating: rating,
                  comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color c = Colors.amber;
    if (status == 'CONFIRMED') c = Colors.blueAccent;
    if (status == 'RESCHEDULED') c = Colors.deepOrangeAccent;
    if (status == 'DONE') c = Colors.teal;
    if (status == 'CANCELLED') c = Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

