const CAPABILITY_NAMES = [
  'teams-workload',
  'kanban-bottleneck',
  'tasks-breakdown',
  'tasks-assignee',
  'tasks-risk',
  'calendar-risk',
  'calendar-conflict',
  'chat-summary',
  'chat-actions',
  'files-classify',
  'files-duplicates',
  'coaching-learning',
  'coaching-gaps',
];

function recommendation(kind, title, explanation, confidence, isPrediction, action = null) {
  return {
    id: `${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    kind,
    title,
    explanation,
    confidence,
    isPrediction,
    source: 'local-heuristic',
    generatedAt: new Date().toISOString(),
    action,
  };
}

function clamp(value) {
  return Math.max(0, Math.min(1, value));
}

function listCapabilities() {
  return CAPABILITY_NAMES.map((id) => ({
    id,
    source: 'local-heuristic',
  }));
}

async function handle({ prisma, action, userId, payload = {} }) {
  const moduleName = action || payload.module || 'tasks';
  const projectId = payload.projectId || null;
  const teamId = payload.teamId || null;
  const now = new Date();

  if (moduleName === 'teams' || moduleName === 'teams-workload') {
    const members = await prisma.teamMember.findMany({
      where: teamId ? { teamId } : {},
      include: { user: true },
    });
    if (!members.length) {
      return [recommendation('teams-workload', 'Équipe à équilibrer', 'Aucun membre n’est disponible pour analyser la charge.', 0.2, true)];
    }
    const memberIds = members.map((m) => m.userId);
    const activeTasks = await prisma.task.findMany({
      where: { assignees: { some: { userId: { in: memberIds } } }, completedAt: null },
      include: { assignees: true },
    });
    const counts = new Map(memberIds.map((id) => [id, 0]));
    activeTasks.forEach((task) => task.assignees.forEach((a) => counts.set(a.userId, (counts.get(a.userId) || 0) + 1)));
    const busiest = members.map((m) => ({ member: m, count: counts.get(m.userId) || 0 })).sort((a, b) => b.count - a.count)[0];
    const average = activeTasks.length / members.length;
    return [
      recommendation(
        'teams-workload',
        busiest.count > average ? `Charge élevée pour ${busiest.member.user.name}` : 'Charge globale équilibrée',
        `${busiest.member.user.name} porte ${busiest.count} tâche(s) active(s), pour une moyenne de ${average.toFixed(1)} par membre.`,
        clamp(busiest.count / Math.max(activeTasks.length, 1)),
        true,
        'Revoir les affectations',
      ),
    ];
  }

  if (moduleName === 'kanban' || moduleName === 'kanban-bottleneck') {
    const project = projectId
      ? await prisma.project.findUnique({ where: { id: projectId }, include: { columns: { include: { tasks: true } }, tasks: true } })
      : null;
    if (!project) return [recommendation('kanban-bottleneck', 'Analyse indisponible', 'Sélectionnez un projet contenant des colonnes Kanban.', 0.2, true)];
    const overloaded = project.columns
      .filter((column) => column.wipLimit != null && column.tasks.length > column.wipLimit)
      .sort((a, b) => (b.tasks.length - b.wipLimit) - (a.tasks.length - a.wipLimit))[0];
    if (!overloaded) {
      return [recommendation('kanban-bottleneck', 'Flux Kanban stable', 'Aucune colonne ne dépasse sa limite WIP.', 0.82, true, 'Conserver le rythme actuel')];
    }
    return [
      recommendation(
        'kanban-bottleneck',
        `Goulot détecté : ${overloaded.name}`,
        `${overloaded.tasks.length} tâches pour une limite WIP de ${overloaded.wipLimit}.`,
        clamp(overloaded.tasks.length / (overloaded.wipLimit * 2)),
        true,
        'Limiter les nouvelles entrées',
      ),
    ];
  }

  if (moduleName === 'tasks' || moduleName.startsWith('tasks-')) {
    const tasks = await prisma.task.findMany({
      where: projectId ? { projectId } : {},
      include: { subtasks: true, assignees: true, column: true },
    });
    const incomplete = tasks.filter((task) => !task.completedAt && !task.column.isDone);
    const overdue = incomplete.filter((task) => task.dueDate && new Date(task.dueDate) < now);
    const urgent = incomplete.filter((task) => ['URGENTE', 'HAUTE'].includes(task.priority));
    if (!incomplete.length) {
      return [recommendation('tasks-risk', 'Toutes les tâches sont stabilisées', 'Aucune tâche active ne nécessite une alerte locale.', 0.9, true, 'Planifier le prochain jalon')];
    }
    const risk = clamp((overdue.length * 0.5 + urgent.length * 0.25) / Math.max(incomplete.length, 1));
    return [
      recommendation(
        'tasks-risk',
        overdue.length ? `${overdue.length} échéance(s) en retard` : 'Risque d’échéance faible',
        `${overdue.length} tâche(s) en retard et ${urgent.length} tâche(s) urgente(s) ou prioritaire(s) sur ${incomplete.length} tâches actives.`,
        clamp(0.45 + risk),
        true,
        overdue.length ? 'Prioriser les retards' : 'Maintenir les priorités',
      ),
      recommendation(
        'tasks-breakdown',
        'Découpage suggéré',
        incomplete.filter((task) => task.subtasks.length === 0).length
          ? `${incomplete.filter((task) => task.subtasks.length === 0).length} tâche(s) active(s) n’ont aucune sous-tâche.`
          : 'Les tâches actives disposent déjà d’un découpage.',
        0.75,
        false,
        'Ajouter des sous-tâches',
      ),
    ];
  }

  if (moduleName === 'calendar' || moduleName.startsWith('calendar-')) {
    const tasks = await prisma.task.findMany({
      where: projectId ? { projectId } : {},
      include: { column: true },
    });
    const milestones = await prisma.milestone.findMany({
      where: projectId ? { projectId } : {},
    });
    const overdue = tasks.filter((task) => task.dueDate && new Date(task.dueDate) < now && !task.column.isDone);
    const soon = tasks.filter((task) => {
      if (!task.dueDate || task.column.isDone) return false;
      const hours = (new Date(task.dueDate).getTime() - now.getTime()) / 3600000;
      return hours >= 0 && hours <= 72;
    });
    const events = [...overdue.map((task) => ({ title: task.title, date: new Date(task.dueDate) })),
      ...milestones.map((milestone) => ({ title: milestone.title, date: new Date(milestone.date) }))];
    const conflicts = [];
    const sorted = events.sort((a, b) => a.date - b.date);
    for (let i = 1; i < sorted.length; i += 1) {
      if (Math.abs(sorted[i].date - sorted[i - 1].date) < 24 * 3600000) {
        conflicts.push(sorted[i].title);
      }
    }
    return [
      recommendation(
        'calendar-risk',
        overdue.length ? `${overdue.length} échéance(s) en retard` : `${soon.length} échéance(s) sous 72 h`,
        overdue.length
          ? `${overdue.length} tâches actives ont déjà dépassé leur date limite.`
          : `${soon.length} tâches arrivent à échéance dans les prochaines 72 heures.`,
        clamp(overdue.length ? 0.55 + overdue.length * 0.08 : soon.length ? 0.45 + soon.length * 0.07 : 0.25),
        true,
        overdue.length ? 'Replanifier les retards' : 'Afficher l’agenda',
      ),
      recommendation(
        'calendar-conflict',
        conflicts.length ? `${conflicts.length} risque(s) de concentration` : 'Aucun conflit proche détecté',
        conflicts.length
          ? `Plusieurs événements se concentrent dans une fenêtre de 24 h : ${conflicts.slice(0, 3).join(', ')}.`
          : 'Les échéances et jalons ne sont pas concentrés dans une même fenêtre de 24 h.',
        conflicts.length ? 0.7 : 0.35,
        true,
        'Examiner les dates',
      ),
    ];
  }

  if (moduleName === 'chat' || moduleName.startsWith('chat-')) {
    const channelIds = payload.channelId
      ? [payload.channelId]
      : (await prisma.channel.findMany({ where: projectId ? { projectId } : {}, select: { id: true } })).map((c) => c.id);
    const messages = await prisma.message.findMany({
      where: { channelId: { in: channelIds } },
      orderBy: { createdAt: 'desc' },
      take: 30,
      include: { author: true },
    });
    if (!messages.length) {
      return [recommendation('chat-summary', 'Aucun contenu analysable', 'Le canal ne contient pas encore de message.', 0.2, false)];
    }
    const actionWords = /\b(faire|créer|préparer|envoyer|vérifier|corriger|terminer|planifier|mettre|ajouter)\b/i;
    const actions = messages.filter((message) => actionWords.test(message.body)).slice(0, 5).map((message) => message.body);
    const recent = messages.slice(0, 5).map((message) => message.body).join(' · ');
    return [
      recommendation('chat-summary', 'Résumé local du canal', recent.slice(0, 240), clamp(Math.min(messages.length / 20, 0.9)), false),
      recommendation(
        'chat-actions',
        `${actions.length} action(s) potentielle(s)`,
        actions.length ? actions.join(' | ').slice(0, 280) : 'Aucun verbe d’action explicite détecté dans les messages récents.',
        actions.length ? 0.68 : 0.35,
        false,
        'Créer des tâches',
      ),
    ];
  }

  if (moduleName === 'files' || moduleName.startsWith('files-')) {
    const files = await prisma.file.findMany({
      where: projectId ? { projectId } : {},
      include: { versions: true },
    });
    if (!files.length) {
      return [recommendation('files-classify', 'Aucun fichier à analyser', 'Téléversez un fichier pour obtenir une classification locale.', 0.2, false)];
    }
    const baseNames = new Map();
    files.forEach((file) => {
      const key = file.name.trim().toLowerCase();
      baseNames.set(key, (baseNames.get(key) || 0) + 1);
    });
    const duplicates = [...baseNames.entries()].filter(([, count]) => count > 1);
    const categories = new Map();
    files.forEach((file) => {
      const name = file.name.toLowerCase();
      const category = /\.(pdf|docx?|txt|md)$/.test(name) ? 'Document'
        : /\.(png|jpe?g|gif|webp|svg)$/.test(name) ? 'Image'
        : /\.(xlsx?|csv)$/.test(name) ? 'Tableur'
        : 'Autre';
      categories.set(category, (categories.get(category) || 0) + 1);
    });
    return [
      recommendation('files-classify', 'Répartition des fichiers', [...categories.entries()].map(([category, count]) => `${category}: ${count}`).join(' · '), 0.85, false),
      recommendation(
        'files-duplicates',
        duplicates.length ? `${duplicates.length} doublon(s) potentiel(s)` : 'Aucun doublon évident',
        duplicates.length ? duplicates.map(([name]) => name).slice(0, 5).join(', ') : 'Les noms de fichiers sont majoritairement distincts.',
        duplicates.length ? 0.72 : 0.45,
        false,
        'Examiner les fichiers',
      ),
    ];
  }

  if (moduleName === 'coaching' || moduleName.startsWith('coaching-')) {
    const skillLevels = await prisma.skillLevel.findMany({
      where: userId ? { userId } : {},
      orderBy: { level: 'asc' },
      take: 10,
    });
    if (!skillLevels.length) {
      return [recommendation('coaching-gaps', 'Évaluation initiale recommandée', 'Aucune compétence n’est encore enregistrée pour proposer un parcours.', 0.3, true, 'Évaluer les compétences')];
    }
    const weak = skillLevels.filter((skill) => skill.level < 3);
    const best = skillLevels.filter((skill) => skill.level >= 3);
    return [
      recommendation(
        'coaching-gaps',
        weak.length ? `${weak.length} compétence(s) à renforcer` : 'Compétences fondamentales acquises',
        weak.length ? weak.map((skill) => skill.skill).slice(0, 5).join(', ') : 'Les compétences enregistrées sont toutes au niveau intermédiaire ou supérieur.',
        weak.length ? 0.8 : 0.65,
        true,
        'Créer un objectif',
      ),
      recommendation(
        'coaching-learning',
        'Parcours recommandé',
        best.length ? `Poursuivre avec des exercices avancés sur ${best.map((skill) => skill.skill).slice(0, 3).join(', ')}.` : 'Commencer par les compétences ayant le niveau le plus faible.',
        0.7,
        false,
        'Voir les formations',
      ),
    ];
  }

  if (moduleName === 'auth') {
    return [recommendation('auth-signal', 'Activité locale normale', 'Aucune anomalie de session n’est déduite sans données d’audit historiques.', 0.25, true)];
  }

  throw Object.assign(new Error(`Capacité IA inconnue: ${moduleName}`), { status: 400 });
}

module.exports = { listCapabilities, handle };
