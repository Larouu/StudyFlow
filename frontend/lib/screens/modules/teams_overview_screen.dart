import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/studyflow_models.dart';
import '../../providers/studyflow_provider.dart';
import '../../widgets/ai_insights_panel.dart';

class TeamsOverviewScreen extends StatelessWidget {
  const TeamsOverviewScreen({super.key, required this.store});
  final StudyFlowStore store;

  @override
  Widget build(BuildContext context) {
    final activeUser = store.currentUser!;
    final canInvite = activeUser.role == UserRole.owner;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AiInsightsPanel(
          store: store,
          module: 'teams',
          title: 'Assistant IA équipe',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    activeUser.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(activeUser.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        'Rôle : ${roleToString(activeUser.role)} · ${store.isPrismaConnected ? "Connecté au serveur" : "Mode hors ligne"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: store.isPrismaConnected ? Colors.teal : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (store.teamName != null || store.teamInviteToken != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.group_work_outlined, color: Color(0xFF4F46E5)),
              title: Text(store.teamName ?? 'Mon équipe', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: store.teamInviteToken != null
                  ? Text('Code d\'invitation : ${store.teamInviteToken}', style: const TextStyle(fontSize: 12))
                  : null,
              trailing: store.teamInviteToken != null
                  ? IconButton(
                      tooltip: 'Copier le code',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: store.teamInviteToken!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code d\'invitation copié !')),
                        );
                      },
                    )
                  : null,
            ),
          ),
        ],
        if (activeUser.role == UserRole.owner) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Console administrateur',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openProjectDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Projet'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gérez les projets, les membres et leurs rôles.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ...store.projects.map((project) {
                    final isActive = project.id == store.activeProjectId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: Icon(
                          isActive ? Icons.folder_special : Icons.folder_outlined,
                          color: const Color(0xFF818CF8),
                        ),
                        title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isActive ? 'Projet actif · ${project.description}' : project.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sélectionner',
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              onPressed: () => store.selectProject(project.id),
                            ),
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _openProjectDialog(context, project),
                            ),
                            if (store.projects.length > 1)
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => _confirmDeleteProject(context, project),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'Membres de l\'équipe (${store.users.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openJoinTeamDialog(context),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Rejoindre'),
                ),
                if (canInvite) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openInviteDialog(context),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Inviter'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...store.users.map((u) {
          final isCurrent = u.id == activeUser.id;
          final canEditThisMember = canInvite &&
              !isCurrent &&
              !(u.role == UserRole.owner && activeUser.role != UserRole.owner);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: u.isCoach ? Colors.purple : const Color(0xFF4F46E5),
                child: Text(u.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(
                isCurrent ? '${u.name} (Vous)' : u.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEditThisMember)
                    PopupMenuButton<UserRole>(
                      tooltip: 'Changer le rôle',
                      onSelected: (newRole) async {
                        final ok = await store.updateMemberRole(u.id, newRole);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Rôle de ${u.name} mis à jour (${roleToString(newRole)}).'
                                  : 'Impossible de modifier ce rôle.',
                            ),
                          ),
                        );
                      },
                      itemBuilder: (_) => [
                        if (activeUser.role == UserRole.owner)
                          const PopupMenuItem(value: UserRole.owner, child: Text('OWNER')),
                        const PopupMenuItem(value: UserRole.member, child: Text('MEMBER')),
                        const PopupMenuItem(value: UserRole.coach, child: Text('COACH')),
                      ],
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(roleToString(u.role), style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, size: 15),
                          ],
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    Chip(
                      label: Text(roleToString(u.role), style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (canEditThisMember && u.role != UserRole.owner)
                    IconButton(
                      tooltip: 'Retirer de l\'équipe',
                      icon: const Icon(Icons.person_remove_outlined, size: 18, color: Colors.redAccent),
                      onPressed: () => _confirmRemoveMember(context, u),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _confirmRemoveMember(BuildContext context, AppUser member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer un membre'),
        content: Text('Voulez-vous vraiment retirer ${member.name} de l\'équipe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await store.removeMember(member.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? '${member.name} retiré de l\'équipe.' : 'Action impossible.'),
                ),
              );
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  void _openProjectDialog(BuildContext context, [ProjectItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    var color = existing?.color ?? '#4f46e5';
    const colors = [
      '#4f46e5',
      '#0ea5e9',
      '#10b981',
      '#f59e0b',
      '#ec4899',
      '#8b5cf6',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(existing == null ? 'Créer un projet' : 'Modifier le projet'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du projet'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in colors)
                      GestureDetector(
                        onTap: () => setStateDialog(() => color = value),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: _parseColor(value),
                          child: color == value
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                if (existing == null) {
                  await store.createProject(
                    name: nameCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    color: color,
                  );
                } else {
                  await store.updateProject(
                    existing.id,
                    name: nameCtrl.text.trim(),
                    description: descriptionCtrl.text.trim(),
                    color: color,
                  );
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, ProjectItem project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: Text(
          'Supprimer « ${project.name} » ? Ses tâches, colonnes, fichiers et jalons associés seront supprimés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await store.deleteProject(project.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Projet supprimé.' : 'Impossible de supprimer ce projet.'),
                ),
              );
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String value) {
    final parsed = int.tryParse(value.replaceFirst('#', 'FF'), radix: 16);
    return parsed == null ? const Color(0xFF4F46E5) : Color(parsed);
  }

  void _openJoinTeamDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoindre une équipe'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Code d\'invitation (ex: SF-XXXXXX)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final ok = await store.joinTeam(ctrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Équipe rejointe !' : 'Code d\'invitation invalide.')),
              );
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  void _openInviteDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    var role = 'MEMBER';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Inviter un membre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail du membre inscrit'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: const [
                  DropdownMenuItem(value: 'MEMBER', child: Text('Membre')),
                  DropdownMenuItem(value: 'COACH', child: Text('Coach')),
                ],
                onChanged: (v) => setStateDialog(() => role = v ?? 'MEMBER'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final ok = await store.inviteMember(emailCtrl.text, role: role);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Membre ajouté à l\'équipe !' : 'Utilisateur introuvable ou déjà membre.',
                    ),
                  ),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

