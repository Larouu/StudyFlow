const CAPABILITY_NAMES = [
  'teams-workload',
  'teams-ai-coach',
  'kanban-bottleneck',
  'kanban-stalled',
  'tasks-breakdown',
  'tasks-assignee',
  'tasks-risk',
  'tasks-focus',
  'calendar-risk',
  'calendar-conflict',
  'chat-summary',
  'chat-actions',
  'files-classify',
  'files-duplicates',
  'files-storage',
  'coaching-learning',
  'coaching-gaps',
];

const GROQ_MODEL = process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';

function recommendation(kind, title, explanation, confidence, isPrediction, action = null, extra = {}) {
  return {
    id: `${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    kind,
    title,
    explanation,
    confidence: clamp(confidence),
    isPrediction,
    source: extra.source || 'local-heuristic',
    severity: extra.severity || 'info',
    metrics: Array.isArray(extra.metrics) ? extra.metrics : [],
    generatedAt: new Date().toISOString(),
    action,
  };
}

function clamp(value) {
  return Math.max(0, Math.min(1, Number(value) || 0));
}

function listCapabilities() {
  const hasGroq = Boolean(process.env.GROQ_API_KEY);
  return CAPABILITY_NAMES.map((id) => ({
    id,
    source: hasGroq ? 'groq-hybrid' : 'local-heuristic',
  }));
}

async function synthesizeWithGroq(moduleName, facts) {
  if (!process.env.GROQ_API_KEY) return null;
  try {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        max_completion_tokens: 220,
        temperature: 0.25,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content:
              'Tu es le moteur IA analytique de StudyFlow. Réponds UNIQUEMENT en JSON valide avec les clés: "title" (max 55 car.), "explanation" (2 phrases concrètes max 220 car.), "action" (verbe d\'action court max 35 car.). Langue: français.',
          },
          {
            role: 'user',
            content: `Module: ${moduleName}\nDonnées observées:\n${facts}`,
          },
        ],
      }),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const raw = data.choices?.[0]?.message?.content;
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed.title || !parsed.explanation) return null;
    return recommendation(
      `${moduleName}-ai-coach`,
      String(parsed.title).slice(0, 70),
      String(parsed.explanation).slice(0, 300),
      0.88,
      true,
      parsed.action ? String(parsed.action).slice(0, 45) : 'Approfondir avec l’assistant',
      { source: 'groq-llm', severity: 'info', metrics: ['Groq LLM'] },
    );
  } catch (_) {
    return null;
  }
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
      return [
        recommendation(
          'teams-workload',
          'Équipe à équilibrer',
          'Aucun membre n’est disponible pour analyser la charge.',
          0.2,
          true,
          'Inviter des membres',
          { severity: 'low' },
        ),
      ];
    }
    const memberIds = members.map((m) => m.userId);
    const activeTasks = await prisma.task.findMany({
      where: {
        archivedAt: null,
        completedAt: null,
        assignees: { some: { userId: { in: memberIds } } },
      },
      include: { assignees: true, column: true },
    });
    const counts = new Map(memberIds.map((id) => [id, 0]));
    const overdueCounts = new Map(memberIds.map((id) => [id, 0]));
    activeTasks.forEach((task) => {
      if (task.column?.isDone) return;
      const isLate = task.dueDate && new Date(task.dueDate) < now;
      task.assignees.forEach((a) => {
        counts.set(a.userId, (counts.get(a.userId) || 0) + 1);
        if (isLate) overdueCounts.set(a.userId, (overdueCounts.get(a.userId) || 0) + 1);
      });
    });

    const ranked = members
      .map((m) => ({
        member: m,
        count: counts.get(m.userId) || 0,
        overdue: overdueCounts.get(m.userId) || 0,
      }))
      .sort((a, b) => b.count - a.count);
    const busiest = ranked[0];
    const lightest = ranked[ranked.length - 1];
    const average = activeTasks.length / members.length;
    const imbalance = busiest.count - lightest.count;

    const results = [
      recommendation(
        'teams-workload',
        imbalance >= 2
          ? `Déséquilibre : ${busiest.member.user.name} surchargé(e)`
          : 'Charge globale équilibrée',
        `${busiest.member.user.name} porte ${busiest.count} tâche(s) (${busiest.overdue} en retard), contre ${lightest.count} pour ${lightest.member.user.name} (moyenne ${average.toFixed(1)}).`,
        clamp(0.45 + imbalance * 0.12),
        true,
        imbalance >= 2 ? `Réaffecter vers ${lightest.member.user.name.split(' ')[0]}` : 'Maintenir la répartition',
        {
          severity: imbalance >= 3 ? 'high' : imbalance >= 2 ? 'medium' : 'low',
          metrics: [`${members.length} membres`, `${activeTasks.length} tâches actives`, `Écart max: ${imbalance}`],
        },
      ),
    ];

    const idleMembers = ranked.filter((r) => r.count === 0 && r.member.role !== 'COACH');
    if (idleMembers.length) {
      results.push(
        recommendation(
          'teams-capacity',
          `${idleMembers.length} membre(s) disponible(s)`,
          `${idleMembers.map((r) => r.member.user.name).join(', ')} n’a aucune tâche active assignée.`,
          0.78,
          false,
          'Assigner des tâches',
          { severity: 'info', metrics: [`${idleMembers.length} disponible(s)`] },
        ),
      );
    }

    const aiCoach = await synthesizeWithGroq(
      'teams',
      ranked.map((r) => `${r.member.user.name} (${r.member.role}): ${r.count} actives, ${r.overdue} en retard`).join('\n'),
    );
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'kanban' || moduleName === 'kanban-bottleneck') {
    const project = projectId
      ? await prisma.project.findUnique({
          where: { id: projectId },
          include: {
            columns: {
              orderBy: { position: 'asc' },
              include: { tasks: { where: { archivedAt: null } } },
            },
            tasks: { where: { archivedAt: null } },
          },
        })
      : null;
    if (!project) {
      return [
        recommendation(
          'kanban-bottleneck',
          'Analyse indisponible',
          'Sélectionnez un projet contenant des colonnes Kanban.',
          0.2,
          true,
          null,
          { severity: 'low' },
        ),
      ];
    }

    const overloaded = project.columns
      .filter((column) => column.wipLimit != null && column.tasks.length > column.wipLimit)
      .sort((a, b) => b.tasks.length - b.wipLimit - (a.tasks.length - a.wipLimit))[0];

    const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 3600000);
    const stalled = project.tasks.filter(
      (t) => !t.completedAt && new Date(t.updatedAt) < threeDaysAgo,
    );
    const total = project.tasks.length;
    const done = project.tasks.filter((t) => t.completedAt).length;
    const rate = total ? Math.round((done / total) * 100) : 0;

    const results = [
      overloaded
        ? recommendation(
            'kanban-bottleneck',
            `Goulot détecté : ${overloaded.name}`,
            `${overloaded.tasks.length} tâches pour une limite WIP de ${overloaded.wipLimit}. Terminez les cartes en cours avant d’en démarrer de nouvelles.`,
            clamp(overloaded.tasks.length / (overloaded.wipLimit * 2)),
            true,
            'Débloquer la colonne',
            {
              severity: 'high',
              metrics: [`WIP ${overloaded.tasks.length}/${overloaded.wipLimit}`, `Avancement ${rate}%`],
            },
          )
        : recommendation(
            'kanban-bottleneck',
            'Flux Kanban fluide',
            `Aucune colonne ne dépasse sa limite WIP sur ${project.columns.length} colonnes (${rate}% terminé).`,
            0.85,
            true,
            'Conserver le rythme',
            { severity: 'low', metrics: [`${total} cartes`, `${rate}% terminé`] },
          ),
      recommendation(
        'kanban-stalled',
        stalled.length ? `${stalled.length} carte(s) inactive(s) > 3j` : 'Aucune carte bloquée',
        stalled.length
          ? `Cartes sans mise à jour récente : ${stalled.slice(0, 3).map((t) => t.title).join(', ')}.`
          : 'Toutes les cartes actives ont progressé récemment.',
        stalled.length ? 0.76 : 0.6,
        true,
        stalled.length ? 'Relancer les cartes bloquées' : 'Vérifier les priorités',
        { severity: stalled.length ? 'medium' : 'info', metrics: [`${stalled.length} bloquée(s)`] },
      ),
    ];

    const colSummary = project.columns
      .map((c) => `${c.name}: ${c.tasks.length} cartes${c.wipLimit ? ` (WIP ${c.wipLimit})` : ''}`)
      .join(', ');
    const aiCoach = await synthesizeWithGroq('kanban', `Projet ${project.name} (${rate}% terminé). Colonnes: ${colSummary}. Cartes inactives >3j: ${stalled.length}.`);
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'tasks' || moduleName.startsWith('tasks-')) {
    const tasks = await prisma.task.findMany({
      where: { ...(projectId ? { projectId } : {}), archivedAt: null },
      include: { subtasks: true, assignees: true, column: true },
    });
    const incomplete = tasks.filter((task) => !task.completedAt && !task.column.isDone);
    const overdue = incomplete.filter((task) => task.dueDate && new Date(task.dueDate) < now);
    const urgent = incomplete.filter((task) => ['URGENTE', 'HAUTE'].includes(task.priority));
    const unassigned = incomplete.filter((task) => task.assignees.length === 0);
    const noSubtasks = incomplete.filter((task) => task.subtasks.length === 0);

    if (!incomplete.length) {
      return [
        recommendation(
          'tasks-risk',
          'Toutes les tâches sont terminées',
          'Aucune tâche active en attente sur ce périmètre.',
          0.92,
          true,
          'Planifier le prochain jalon',
          { severity: 'low', metrics: [`${tasks.length} terminées`] },
        ),
      ];
    }

    const priorityScore = { URGENTE: 4, HAUTE: 3, NORMALE: 2, BASSE: 1 };
    const topFocus = [...incomplete]
      .sort((a, b) => {
        const aLate = a.dueDate && new Date(a.dueDate) < now ? 10 : 0;
        const bLate = b.dueDate && new Date(b.dueDate) < now ? 10 : 0;
        return (bLate + (priorityScore[b.priority] || 1)) - (aLate + (priorityScore[a.priority] || 1));
      })
      .slice(0, 3);

    const risk = clamp((overdue.length * 0.5 + urgent.length * 0.25) / Math.max(incomplete.length, 1));
    const results = [
      recommendation(
        'tasks-risk',
        overdue.length ? `${overdue.length} échéance(s) en retard` : 'Risque d’échéance maîtrisé',
        `${overdue.length} en retard, ${urgent.length} prioritaire(s) et ${unassigned.length} sans assigné sur ${incomplete.length} tâches actives.`,
        clamp(0.45 + risk),
        true,
        overdue.length ? 'Prioriser les retards' : 'Maintenir la cadence',
        {
          severity: overdue.length ? 'high' : urgent.length ? 'medium' : 'low',
          metrics: [`${incomplete.length} actives`, `${overdue.length} retards`, `${urgent.length} urgentes`],
        },
      ),
      recommendation(
        'tasks-focus',
        'Top 3 à traiter maintenant',
        topFocus.map((t, i) => `${i + 1}. ${t.title} (${t.priority})`).join(' · '),
        0.86,
        false,
        'Planifier la journée',
        { severity: 'info', metrics: [`${noSubtasks.length} sans sous-tâches`] },
      ),
    ];

    const aiCoach = await synthesizeWithGroq(
      'tasks',
      `Actives: ${incomplete.length}, En retard: ${overdue.length}, Urgentes/Hautes: ${urgent.length}, Sans assigné: ${unassigned.length}, Sans sous-tâche: ${noSubtasks.length}.\nTop 3: ${topFocus.map((t) => `${t.title} (${t.priority})`).join(', ')}`,
    );
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'calendar' || moduleName.startsWith('calendar-')) {
    const tasks = await prisma.task.findMany({
      where: { ...(projectId ? { projectId } : {}), archivedAt: null },
      include: { column: true },
    });
    const milestones = await prisma.milestone.findMany({
      where: projectId ? { projectId } : {},
      orderBy: { date: 'asc' },
    });
    const overdue = tasks.filter((task) => task.dueDate && new Date(task.dueDate) < now && !task.column.isDone);
    const soon = tasks.filter((task) => {
      if (!task.dueDate || task.column.isDone) return false;
      const hours = (new Date(task.dueDate).getTime() - now.getTime()) / 3600000;
      return hours >= 0 && hours <= 72;
    });
    const events = [
      ...overdue.map((task) => ({ title: task.title, date: new Date(task.dueDate) })),
      ...milestones.map((milestone) => ({ title: milestone.title, date: new Date(milestone.date) })),
    ];
    const conflicts = [];
    const sorted = events.sort((a, b) => a.date - b.date);
    for (let i = 1; i < sorted.length; i += 1) {
      if (Math.abs(sorted[i].date - sorted[i - 1].date) < 24 * 3600000) {
        conflicts.push(sorted[i].title);
      }
    }
    const nextMilestone = milestones.find((m) => new Date(m.date) >= now);

    const results = [
      recommendation(
        'calendar-risk',
        overdue.length ? `${overdue.length} échéance(s) dépassée(s)` : `${soon.length} échéance(s) sous 72 h`,
        overdue.length
          ? `${overdue.length} tâches actives ont dépassé leur date limite. ${soon.length} autre(s) arrivent sous 72 h.`
          : `${soon.length} tâche(s) arrivent à échéance dans les 72 prochaines heures.${nextMilestone ? ` Prochain jalon : ${nextMilestone.title}.` : ''}`,
        clamp(overdue.length ? 0.55 + overdue.length * 0.08 : soon.length ? 0.45 + soon.length * 0.07 : 0.25),
        true,
        overdue.length ? 'Replanifier les retards' : 'Préparer les 72h',
        {
          severity: overdue.length ? 'high' : soon.length ? 'medium' : 'low',
          metrics: [`${overdue.length} retards`, `${soon.length} sous 72h`, `${milestones.length} jalons`],
        },
      ),
      recommendation(
        'calendar-conflict',
        conflicts.length ? `${conflicts.length} concentration(s) < 24 h` : 'Agenda bien espacé',
        conflicts.length
          ? `Événements rapprochés : ${conflicts.slice(0, 3).join(', ')}.`
          : 'Aucun chevauchement critique détecté entre jalons et échéances.',
        conflicts.length ? 0.72 : 0.4,
        true,
        'Examiner les dates',
        { severity: conflicts.length ? 'medium' : 'info' },
      ),
    ];

    const aiCoach = await synthesizeWithGroq(
      'calendar',
      `Retards: ${overdue.length}, Sous 72h: ${soon.length}, Conflits <24h: ${conflicts.length}, Jalons: ${milestones.map((m) => m.title).join(', ') || 'aucun'}.`,
    );
    if (aiCoach) results.push(aiCoach);
    return results;
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
      return [
        recommendation(
          'chat-summary',
          'Canal silencieux',
          'Le canal ne contient pas encore de message à analyser.',
          0.2,
          false,
          'Lancer la discussion',
          { severity: 'info' },
        ),
      ];
    }
    const actionWords = /\b(faire|créer|préparer|envoyer|vérifier|corriger|terminer|planifier|mettre|ajouter|valider|tester)\b/i;
    const actions = messages.filter((message) => actionWords.test(message.body)).slice(0, 5);
    const participants = new Set(messages.map((m) => m.author?.name || m.authorId));
    const recent = messages
      .slice(0, 4)
      .map((m) => `${m.author?.name?.split(' ')[0] || 'Membre'}: ${m.body}`)
      .join(' · ');

    const results = [
      recommendation(
        'chat-summary',
        `Activité : ${messages.length} msg (${participants.size} participants)`,
        recent.slice(0, 260),
        clamp(Math.min(messages.length / 15, 0.92)),
        false,
        'Voir les échanges',
        { severity: 'info', metrics: [`${messages.length} messages`, `${participants.size} actifs`] },
      ),
      recommendation(
        'chat-actions',
        `${actions.length} action(s) détectée(s) dans le chat`,
        actions.length
          ? actions.map((m) => `• ${m.body}`).join(' ').slice(0, 280)
          : 'Aucun verbe d’action explicite détecté dans les messages récents.',
        actions.length ? 0.74 : 0.35,
        false,
        actions.length ? 'Convertir en tâches' : 'Poser une question',
        { severity: actions.length ? 'medium' : 'low', metrics: [`${actions.length} actions`] },
      ),
    ];

    const aiCoach = await synthesizeWithGroq(
      'chat',
      messages
        .slice(0, 10)
        .reverse()
        .map((m) => `${m.author?.name || 'Membre'}: ${m.body}`)
        .join('\n'),
    );
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'files' || moduleName.startsWith('files-')) {
    const files = await prisma.file.findMany({
      where: projectId ? { projectId } : {},
      include: { versions: true },
    });
    if (!files.length) {
      return [
        recommendation(
          'files-classify',
          'Espace de stockage vide',
          'Téléversez un document, une image ou créez une note pour activer l’indexation IA.',
          0.25,
          false,
          'Téléverser un fichier',
          { severity: 'info' },
        ),
      ];
    }
    const baseNames = new Map();
    let totalBytes = 0;
    let totalVersions = 0;
    const categories = new Map();

    files.forEach((file) => {
      const key = file.name.trim().toLowerCase();
      baseNames.set(key, (baseNames.get(key) || 0) + 1);
      totalBytes += Number(file.size) || 0;
      totalVersions += file.versions?.length || 1;
      const name = file.name.toLowerCase();
      const category = /\.(pdf|docx?|txt|md)$/.test(name)
        ? 'Document'
        : /\.(png|jpe?g|gif|webp|svg)$/.test(name)
          ? 'Image'
          : /\.(xlsx?|csv)$/.test(name)
            ? 'Tableur'
            : 'Autre';
      categories.set(category, (categories.get(category) || 0) + 1);
    });
    const duplicates = [...baseNames.entries()].filter(([, count]) => count > 1);
    const totalMb = (totalBytes / (1024 * 1024)).toFixed(2);

    const results = [
      recommendation(
        'files-classify',
        `Stockage : ${files.length} fichier(s) (${totalMb} Mo)`,
        [...categories.entries()].map(([category, count]) => `${category}: ${count}`).join(' · '),
        0.88,
        false,
        'Organiser les fichiers',
        {
          severity: 'info',
          metrics: [`${files.length} fichiers`, `${totalVersions} versions`, `${totalMb} Mo`],
        },
      ),
      recommendation(
        'files-duplicates',
        duplicates.length ? `${duplicates.length} doublon(s) détecté(s)` : 'Aucun doublon de nom',
        duplicates.length
          ? `Fichiers en double : ${duplicates.map(([name]) => name).slice(0, 5).join(', ')}. Utilisez le versionnage plutôt que de dupliquer.`
          : 'Tous les fichiers ont des noms distincts et versionnés proprement.',
        duplicates.length ? 0.78 : 0.55,
        false,
        duplicates.length ? 'Fusionner en versions' : 'Vérifier les versions',
        { severity: duplicates.length ? 'medium' : 'low' },
      ),
    ];

    const aiCoach = await synthesizeWithGroq(
      'files',
      `Fichiers: ${files.length}, Total: ${totalMb} Mo, Doublons: ${duplicates.length}. Noms: ${files.slice(0, 10).map((f) => `${f.name} (v${f.currentVersion})`).join(', ')}`,
    );
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'coaching' || moduleName.startsWith('coaching-')) {
    const skillLevels = await prisma.skillLevel.findMany({
      where: userId ? { userId } : {},
      orderBy: { level: 'asc' },
      take: 10,
    });
    const goals = await prisma.coachingGoal.findMany({
      where: userId ? { userId } : {},
      take: 5,
    });
    const trainings = await prisma.training.findMany({
      where: { ...(teamId ? { teamId } : {}), status: 'PUBLISHED', startsAt: { gte: now } },
      orderBy: { startsAt: 'asc' },
      take: 5,
    });

    if (!skillLevels.length && !goals.length) {
      return [
        recommendation(
          'coaching-gaps',
          'Évaluation initiale recommandée',
          'Ajoutez vos niveaux de compétences et objectifs pour recevoir un parcours personnalisé.',
          0.35,
          true,
          'Évaluer mes compétences',
          { severity: 'info' },
        ),
      ];
    }

    const weak = skillLevels.filter((skill) => skill.level < 3);
    const best = skillLevels.filter((skill) => skill.level >= 3);
    const avgGoal = goals.length
      ? Math.round(goals.reduce((acc, g) => acc + (g.progress || 0), 0) / goals.length)
      : 0;

    const results = [
      recommendation(
        'coaching-gaps',
        weak.length ? `${weak.length} compétence(s) à renforcer` : 'Socle de compétences solide',
        weak.length
          ? `Priorité sur : ${weak.map((skill) => `${skill.skill} (${skill.level}/5)`).slice(0, 4).join(', ')}.`
          : 'Toutes les compétences évaluées atteignent au moins le niveau 3/5.',
        weak.length ? 0.84 : 0.7,
        true,
        'Créer un objectif ciblé',
        {
          severity: weak.length >= 2 ? 'medium' : 'low',
          metrics: [`${skillLevels.length} compétences`, `Objectifs: ${avgGoal}%`],
        },
      ),
      recommendation(
        'coaching-learning',
        trainings.length ? `${trainings.length} formation(s) disponible(s)` : 'Parcours recommandé',
        trainings.length
          ? `Prochaines sessions : ${trainings.slice(0, 2).map((t) => t.title).join(' · ')}.`
          : best.length
            ? `Approfondir avec des exercices avancés sur ${best.map((s) => s.skill).slice(0, 3).join(', ')}.`
            : 'Planifier une séance de coaching pour définir vos jalons.',
        0.75,
        false,
        'Explorer les formations',
        { severity: 'info' },
      ),
    ];

    const aiCoach = await synthesizeWithGroq(
      'coaching',
      `Compétences faibles (<3): ${weak.map((s) => `${s.skill}=${s.level}`).join(', ') || 'aucune'}. Objectifs (${goals.length}): moyenne ${avgGoal}%. Formations dispo: ${trainings.map((t) => t.title).join(', ') || 'aucune'}.`,
    );
    if (aiCoach) results.push(aiCoach);
    return results;
  }

  if (moduleName === 'auth') {
    return [
      recommendation(
        'auth-signal',
        'Session sécurisée active',
        'Authentification locale active avec contrôle strict des rôles (OWNER / MEMBER / COACH).',
        0.8,
        false,
        null,
        { severity: 'low' },
      ),
    ];
  }

  throw Object.assign(new Error(`Capacité IA inconnue: ${moduleName}`), { status: 400 });
}

module.exports = { listCapabilities, handle };
