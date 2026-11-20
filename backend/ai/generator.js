const GROQ_MODEL = process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
const VALID_PRIORITIES = new Set(['BASSE', 'NORMALE', 'HAUTE', 'URGENTE']);

async function callGroqJson(systemPrompt, userPrompt) {
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
        max_completion_tokens: 1200,
        temperature: 0.3,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const raw = data.choices?.[0]?.message?.content;
    return raw ? JSON.parse(raw) : null;
  } catch (_) {
    return null;
  }
}

function normalizePriority(p) {
  const up = String(p || 'NORMALE').toUpperCase();
  return VALID_PRIORITIES.has(up) ? up : 'NORMALE';
}

function fallbackKanban(prompt) {
  const topic = String(prompt || 'Projet StudyFlow').trim().slice(0, 60);
  return {
    columns: [
      { name: 'Backlog', wipLimit: null, isDone: false },
      { name: 'À faire', wipLimit: 5, isDone: false },
      { name: 'En cours', wipLimit: 3, isDone: false },
      { name: 'Terminé', wipLimit: null, isDone: true },
    ],
    tasks: [
      {
        title: `Cadrage : ${topic}`,
        description: `Définir le périmètre, les objectifs et les critères de réussite pour ${topic}.`,
        priority: 'HAUTE',
        columnIndex: 1,
        dueInDays: 2,
        subtasks: ['Lister les besoins clés', 'Valider les livrables', 'Répartir les rôles'],
      },
      {
        title: `Architecture & maquettes`,
        description: 'Concevoir la structure technique et les écrans principaux.',
        priority: 'URGENTE',
        columnIndex: 2,
        dueInDays: 4,
        subtasks: ['Modéliser les données', 'Créer les maquettes UI', 'Revue d’équipe'],
      },
      {
        title: `Implémentation cœur`,
        description: `Développer les fonctionnalités principales de ${topic}.`,
        priority: 'HAUTE',
        columnIndex: 1,
        dueInDays: 7,
        subtasks: ['Développer le module principal', 'Connecter l’API REST', 'Gérer les cas limites'],
      },
      {
        title: 'Tests & validation finale',
        description: 'Vérifier la qualité, corriger les anomalies et préparer la démo.',
        priority: 'NORMALE',
        columnIndex: 0,
        dueInDays: 10,
        subtasks: ['Écrire les tests unitaires', 'Tester le parcours utilisateur', 'Rédiger la documentation'],
      },
    ],
  };
}

function fallbackTask(prompt) {
  const clean = String(prompt || 'Nouvelle tâche').trim();
  return {
    title: clean.slice(0, 80),
    description: `Tâche générée par l’assistant IA pour : ${clean}.`,
    priority: /urgent|critique|bloquant/i.test(clean)
      ? 'URGENTE'
      : /important|priorit|rapide/i.test(clean)
        ? 'HAUTE'
        : 'NORMALE',
    dueInDays: 3,
    subtasks: [
      `Analyser les prérequis de « ${clean.slice(0, 35)} »`,
      'Réaliser l’implémentation principale',
      'Vérifier et valider le résultat',
    ],
  };
}

function fallbackSubtasks(title) {
  return [
    `Préparer et clarifier « ${title.slice(0, 35)} »`,
    'Exécuter l’étape principale',
    'Relire, tester et valider',
  ];
}

function fallbackColumns(prompt) {
  const p = String(prompt || '').toLowerCase();
  if (p.includes('scrum') || p.includes('qa') || p.includes('dev')) {
    return [
      { name: 'Backlog', wipLimit: null, isDone: false },
      { name: 'À faire', wipLimit: 5, isDone: false },
      { name: 'En cours', wipLimit: 3, isDone: false },
      { name: 'Tests / QA', wipLimit: 3, isDone: false },
      { name: 'Terminé', wipLimit: null, isDone: true },
    ];
  }
  return [
    { name: 'Idées', wipLimit: null, isDone: false },
    { name: 'Prioritaire', wipLimit: 4, isDone: false },
    { name: 'En revue', wipLimit: 3, isDone: false },
  ];
}

async function generate({ prisma, type, userId, role, payload = {} }) {
  if (role === 'COACH' || role === 'VIEWER') {
    throw Object.assign(new Error('Permission refusée : rôle Coach / Observateur en consultation seule (§4.2)'), {
      status: 403,
    });
  }

  const prompt = String(payload.prompt || '').trim();
  const now = new Date();

  if (type === 'AI_EXTRACT_PROFILE_SKILLS') {
    const bioText = String(payload.bioText || prompt || '').trim();
    if (!bioText) {
      throw Object.assign(new Error('Un texte de présentation ou parcours est requis.'), { status: 400 });
    }

    const llm = await callGroqJson(
      'Tu es l’assistant RH/Pédagogique de StudyFlow. À partir d’une présentation libre d’un étudiant ou coach, rédige une bio professionnelle concise (1 à 2 phrases, max 220 caractères) et extrais 3 à 6 compétences techniques ou transversales avec un niveau estimé de 1 (débutant) à 5 (expert). Réponds UNIQUEMENT en JSON valide : { "bio": string, "skills": [ { "skill": string, "level": number } ] }. Langue: français.',
      `Texte fourni par l’utilisateur :\n${bioText}`,
    );

    const fallback = (() => {
      const catalog = [
        ['Flutter', /flutter/i],
        ['Dart', /\bdart\b/i],
        ['Node.js', /node(\.js)?|express/i],
        ['Prisma / SQL', /prisma|sql|sqlite|postgres/i],
        ['React / Web', /react|next\.js|html|css|typescript|javascript/i],
        ['Python', /python|django|fastapi/i],
        ['Docker / DevOps', /docker|ci\/cd|git|github/i],
        ['UI/UX Design', /figma|ui|ux|design/i],
        ['Gestion de projet', /kanban|agile|scrum|gestion|coordination/i],
      ];
      const detected = [];
      for (const [name, rx] of catalog) {
        if (rx.test(bioText)) {
          const isStrong = /expert|avanc|ma[îi]tris|ans|senior|lead/i.test(bioText);
          detected.push({ skill: name, level: isStrong ? 4 : 3 });
        }
      }
      if (!detected.length) {
        detected.push({ skill: 'Gestion de projet', level: 3 }, { skill: 'Travail en équipe', level: 3 });
      }
      return {
        bio: bioText.replace(/\s+/g, ' ').slice(0, 220),
        skills: detected.slice(0, 6),
      };
    })();

    const cleanBio = String(llm?.bio || fallback.bio).trim().slice(0, 240);
    const rawSkills = Array.isArray(llm?.skills) && llm.skills.length ? llm.skills : fallback.skills;
    const seen = new Set();
    const normalizedSkills = [];
    for (const item of rawSkills.slice(0, 8)) {
      const skillName = String(item?.skill || '').trim().slice(0, 40);
      if (!skillName) continue;
      const key = skillName.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      const lvl = Math.max(1, Math.min(5, Math.round(Number(item?.level) || 3)));
      normalizedSkills.push({ skill: skillName, level: lvl });
    }
    const source = llm && (llm.bio || Array.isArray(llm.skills)) ? 'groq-llm' : 'local-heuristic';

    const apply = payload.apply !== false;
    const savedSkills = [];
    if (apply) {
      await prisma.user.update({
        where: { id: userId },
        data: { bio: cleanBio },
      });

      let resolvedTeamId = payload.teamId || null;
      if (!resolvedTeamId) {
        const membership = await prisma.teamMember.findFirst({ where: { userId } });
        resolvedTeamId = membership?.teamId || 'team-1';
      }

      for (const s of normalizedSkills) {
        const existing = await prisma.skillLevel.findFirst({
          where: { userId, skill: s.skill },
        });
        if (existing) {
          const updated = await prisma.skillLevel.update({
            where: { id: existing.id },
            data: { level: s.level, selfAssessed: true, updatedAt: new Date() },
          });
          savedSkills.push(updated);
        } else {
          const created = await prisma.skillLevel.create({
            data: {
              teamId: resolvedTeamId,
              userId,
              skill: s.skill,
              level: s.level,
              selfAssessed: true,
            },
          });
          savedSkills.push(created);
        }
      }
    }

    return {
      source,
      bio: cleanBio,
      skills: normalizedSkills,
      applied: apply,
      savedCount: savedSkills.length,
    };
  }

  if (type === 'AI_GENERATE_KANBAN') {
    if (!prompt) throw Object.assign(new Error('Un objectif ou sujet est requis.'), { status: 400 });
    const createNewProject = Boolean(payload.createNewProject);
    if (createNewProject && role !== 'OWNER') {
      throw Object.assign(new Error('Seul un OWNER peut créer un nouveau projet.'), { status: 403 });
    }

    const llm = await callGroqJson(
      'Tu es un chef de projet agile StudyFlow. Génère un tableau Kanban complet en JSON valide avec les clés: "projectName" (string court), "columns" (3 à 5 objets { "name": string, "wipLimit": number|null, "isDone": boolean }), "tasks" (4 à 6 objets { "title": string, "description": string, "priority": "BASSE"|"NORMALE"|"HAUTE"|"URGENTE", "columnIndex": number (0-based dans columns), "dueInDays": number, "subtasks": string[] (2 à 4 items) }). Langue: français.',
      `Objectif du tableau Kanban : ${prompt}`,
    );

    const spec = llm && Array.isArray(llm.columns) && llm.columns.length && Array.isArray(llm.tasks)
      ? llm
      : fallbackKanban(prompt);
    const source = llm ? 'groq-llm' : 'local-heuristic';

    let targetProjectId = payload.projectId;
    if (createNewProject || !targetProjectId) {
      const member = await prisma.teamMember.findFirst({ where: { userId } });
      const teamId = member?.teamId || 'team-1';
      const createdProject = await prisma.project.create({
        data: {
          teamId,
          name: String(payload.projectName || llm?.projectName || prompt.slice(0, 40)).trim(),
          description: `Projet généré par IA : ${prompt}`,
          color: '#4f46e5',
        },
      });
      targetProjectId = createdProject.id;
    }

    const existingCols = await prisma.column.findMany({
      where: { projectId: targetProjectId },
      orderBy: { position: 'asc' },
    });

    const createdColumns = [];
    let nextPos = existingCols.length ? existingCols[existingCols.length - 1].position + 1000 : 1000;

    for (const c of spec.columns.slice(0, 6)) {
      const name = String(c.name || 'Colonne').trim();
      const match = existingCols.find((ec) => ec.name.toLowerCase() === name.toLowerCase());
      if (match) {
        createdColumns.push(match);
      } else {
        const col = await prisma.column.create({
          data: {
            projectId: targetProjectId,
            name,
            position: nextPos,
            wipLimit: typeof c.wipLimit === 'number' && c.wipLimit > 0 ? Math.round(c.wipLimit) : null,
            isDone: Boolean(c.isDone),
          },
        });
        nextPos += 1000;
        createdColumns.push(col);
      }
    }

    const createdTasks = [];
    for (let i = 0; i < spec.tasks.slice(0, 8).length; i++) {
      const t = spec.tasks[i];
      const colIdx = Math.max(0, Math.min(createdColumns.length - 1, Number(t.columnIndex) || 0));
      const targetCol = createdColumns[colIdx] || createdColumns[0];
      const dueInDays = Number(t.dueInDays);
      const dueDate = Number.isFinite(dueInDays) && dueInDays > 0
        ? new Date(now.getTime() + dueInDays * 24 * 3600000)
        : null;
      const subtasksList = Array.isArray(t.subtasks) ? t.subtasks.filter(Boolean).slice(0, 5) : [];

      const createdTask = await prisma.task.create({
        data: {
          project: { connect: { id: targetProjectId } },
          column: { connect: { id: targetCol.id } },
          creator: { connect: { id: userId } },
          title: String(t.title || `Tâche ${i + 1}`).trim(),
          description: String(t.description || '').trim(),
          priority: normalizePriority(t.priority),
          position: (i + 1) * 1000,
          dueDate,
          assignees: { create: [{ userId }] },
          ...(subtasksList.length
            ? {
                subtasks: {
                  create: subtasksList.map((st, idx) => ({
                    title: String(st).trim(),
                    position: idx + 1,
                    done: false,
                  })),
                },
              }
            : {}),
        },
        include: { subtasks: true },
      });
      createdTasks.push(createdTask);
    }

    return {
      source,
      projectId: targetProjectId,
      columnsCreated: createdColumns.length,
      tasksCreated: createdTasks.length,
      subtasksCreated: createdTasks.reduce((sum, t) => sum + t.subtasks.length, 0),
    };
  }

  if (type === 'AI_GENERATE_TASK') {
    const { projectId, columnId } = payload;
    if (!projectId || !prompt) {
      throw Object.assign(new Error('projectId et prompt requis.'), { status: 400 });
    }
    let resolvedColId = columnId;
    if (!resolvedColId) {
      const firstCol = await prisma.column.findFirst({
        where: { projectId },
        orderBy: { position: 'asc' },
      });
      if (!firstCol) throw Object.assign(new Error('Aucune colonne dans ce projet.'), { status: 400 });
      resolvedColId = firstCol.id;
    }

    const llm = await callGroqJson(
      'Tu es l’assistant produit StudyFlow. À partir d’une demande utilisateur, génère UNE tâche structurée en JSON valide : { "title": string (max 80 car.), "description": string (2 phrases max), "priority": "BASSE"|"NORMALE"|"HAUTE"|"URGENTE", "dueInDays": number (1 à 14), "subtasks": string[] (3 à 5 sous-tâches concrètes) }. Langue: français.',
      `Demande : ${prompt}`,
    );
    const spec = llm && llm.title ? llm : fallbackTask(prompt);
    const source = llm && llm.title ? 'groq-llm' : 'local-heuristic';
    const dueInDays = Number(spec.dueInDays);
    const dueDate = Number.isFinite(dueInDays) && dueInDays > 0
      ? new Date(now.getTime() + dueInDays * 24 * 3600000)
      : null;
    const subtasksList = Array.isArray(spec.subtasks) ? spec.subtasks.filter(Boolean).slice(0, 6) : [];

    const task = await prisma.task.create({
      data: {
        project: { connect: { id: projectId } },
        column: { connect: { id: resolvedColId } },
        creator: { connect: { id: userId } },
        title: String(spec.title).trim(),
        description: String(spec.description || '').trim(),
        priority: normalizePriority(spec.priority),
        position: Date.now() % 100000,
        dueDate,
        assignees: { create: [{ userId }] },
        ...(subtasksList.length
          ? {
              subtasks: {
                create: subtasksList.map((st, idx) => ({
                  title: String(st).trim(),
                  position: idx + 1,
                  done: false,
                })),
              },
            }
          : {}),
      },
      include: { subtasks: true },
    });

    return { source, task, subtasksCreated: task.subtasks.length };
  }

  if (type === 'AI_ADD_SUBTASKS') {
    const { taskId } = payload;
    if (!taskId) throw Object.assign(new Error('taskId requis.'), { status: 400 });
    const task = await prisma.task.findUnique({
      where: { id: taskId },
      include: { subtasks: true },
    });
    if (!task) throw Object.assign(new Error('Tâche introuvable.'), { status: 404 });

    const llm = await callGroqJson(
      'Tu es l’assistant StudyFlow. Découpe une tâche en 3 à 5 sous-tâches concrètes et actionnables. Réponds UNIQUEMENT en JSON valide : { "subtasks": string[] }. Langue: français.',
      `Tâche : "${task.title}"\nDescription : "${task.description || 'aucune'}"\nSous-tâches déjà existantes : ${task.subtasks.map((s) => s.title).join(', ') || 'aucune'}`,
    );
    const list = llm && Array.isArray(llm.subtasks) && llm.subtasks.length
      ? llm.subtasks.filter(Boolean).slice(0, 5)
      : fallbackSubtasks(task.title);
    const source = llm && Array.isArray(llm.subtasks) ? 'groq-llm' : 'local-heuristic';

    const startPos = task.subtasks.length + 1;
    const created = [];
    for (let i = 0; i < list.length; i++) {
      const sub = await prisma.subtask.create({
        data: {
          taskId: task.id,
          title: String(list[i]).trim(),
          position: startPos + i,
          done: false,
        },
      });
      created.push(sub);
    }

    return { source, taskId: task.id, subtasksCreated: created.length, subtasks: created };
  }

  if (type === 'AI_GENERATE_COLUMNS') {
    const { projectId } = payload;
    if (!projectId) throw Object.assign(new Error('projectId requis.'), { status: 400 });
    const existing = await prisma.column.findMany({
      where: { projectId },
      orderBy: { position: 'asc' },
    });

    const llm = await callGroqJson(
      'Tu es l’assistant Kanban StudyFlow. Propose 2 à 4 colonnes Kanban pertinentes à ajouter au projet selon le workflow demandé. Réponds UNIQUEMENT en JSON valide : { "columns": [ { "name": string, "wipLimit": number|null, "isDone": boolean } ] }. Langue: français.',
      `Workflow souhaité : ${prompt || 'Workflow projet étudiant équilibré'}\nColonnes déjà présentes : ${existing.map((c) => c.name).join(', ') || 'aucune'}`,
    );
    const specCols = llm && Array.isArray(llm.columns) && llm.columns.length
      ? llm.columns
      : fallbackColumns(prompt);
    const source = llm && Array.isArray(llm.columns) ? 'groq-llm' : 'local-heuristic';

    let nextPos = existing.length ? existing[existing.length - 1].position + 1000 : 1000;
    const created = [];
    for (const c of specCols.slice(0, 5)) {
      const name = String(c.name || '').trim();
      if (!name || existing.some((ec) => ec.name.toLowerCase() === name.toLowerCase())) continue;
      const col = await prisma.column.create({
        data: {
          projectId,
          name,
          position: nextPos,
          wipLimit: typeof c.wipLimit === 'number' && c.wipLimit > 0 ? Math.round(c.wipLimit) : null,
          isDone: Boolean(c.isDone),
        },
      });
      nextPos += 1000;
      created.push(col);
    }

    return { source, columnsCreated: created.length, columns: created };
  }

  throw Object.assign(new Error(`Type de génération IA inconnu : ${type}`), { status: 400 });
}

module.exports = { generate };
