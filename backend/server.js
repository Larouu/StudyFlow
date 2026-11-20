require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const ai = require('./ai');
const aiGenerator = require('./ai/generator');
const mailer = require('./mailer');
const scheduler = require('./mailer/scheduler');
const assistant = require('./assistant');

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const app = express();
const UPLOADS_DIR = path.resolve(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}
const dbPath = path.resolve(__dirname, 'prisma/dev.db');
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: `file:${dbPath}`,
    },
  },
});
const PORT = process.env.PORT || 3000;

function hashPassword(password) {
  return crypto.createHash('sha256').update(String(password)).digest('hex');
}

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '25mb' }));

// Helper : e-mail asynchrone (n'échoue jamais, ne bloque pas la réponse)
const notifyUser = (userId, template, data) => mailer.queue(prisma, userId, template, data);

// Helper : récupérer le rôle d'un membre
async function getUserRole(userId) {
  const member = await prisma.teamMember.findFirst({ where: { userId } });
  return member ? member.role : 'MEMBER';
}

// Helper : récupérer l'équipe principale d'un membre
async function getUserTeamId(userId) {
  const member = await prisma.teamMember.findFirst({ where: { userId } });
  return member ? member.teamId : null;
}

// -------------------------------------------------------------
// 1. AUTHENTIFICATION MOBILE (POST /api/mobile/auth)
// -------------------------------------------------------------
app.post('/api/mobile/auth', async (req, res) => {
  try {
    const { mode, email, password, name, inviteToken } = req.body;
    const normalizedEmail = (email || '').trim().toLowerCase();

    if (mode === 'register') {
      if (!name || !normalizedEmail || !password || password.length < 8) {
        return res.status(400).json({ ok: false, error: 'Nom, e-mail valide et mot de passe (min 8 car.) requis.' });
      }

      const existing = await prisma.user.findUnique({ where: { email: normalizedEmail } });
      if (existing) {
        return res.status(409).json({ ok: false, error: 'Un compte existe déjà avec cet e-mail.' });
      }

      const user = await prisma.user.create({
        data: {
          name: name.trim(),
          email: normalizedEmail,
          passwordHash: hashPassword(password),
          image: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        },
      });

      const normalizedInviteToken = (inviteToken || '').trim();
      let team;
      let role = 'MEMBER';
      if (normalizedInviteToken) {
        team = await prisma.team.findUnique({ where: { inviteToken: normalizedInviteToken } });
        if (!team) {
          await prisma.user.delete({ where: { id: user.id } });
          return res.status(404).json({ ok: false, error: 'Code d’invitation invalide.' });
        }
      } else {
        const projectName = (req.body.projectName || '').trim();
        if (!projectName) {
          await prisma.user.delete({ where: { id: user.id } });
          return res.status(400).json({ ok: false, error: 'Nom du projet requis pour créer une équipe.' });
        }
        const suffix = `${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
        const inviteCode = `SF-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
        team = await prisma.team.create({
          data: {
            name: `Équipe ${projectName}`,
            slug: `team-${suffix}`,
            ownerId: user.id,
            inviteToken: inviteCode,
          },
        });
        role = 'OWNER';
        const project = await prisma.project.create({
          data: {
            teamId: team.id,
            name: projectName,
            description: (req.body.projectDescription || '').trim() || null,
            color: (req.body.projectColor || '#4f46e5').slice(0, 7),
          },
        });
        await prisma.column.createMany({
          data: [
            { projectId: project.id, name: 'À faire', position: 1000, isDone: false },
            { projectId: project.id, name: 'En cours', position: 2000, wipLimit: 3, isDone: false },
            { projectId: project.id, name: 'Terminé', position: 3000, isDone: true },
          ],
        });
        await prisma.channel.create({
          data: { teamId: team.id, projectId: project.id, name: 'Général', type: 'PROJECT' },
        });
      }

      await prisma.teamMember.create({
        data: { teamId: team.id, userId: user.id, role },
      });

      notifyUser(user.id, 'welcome', {});

      return res.json({
        ok: true,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          avatar: user.image,
          role,
        },
      });
    }

    // Mode Connexion
    if (!normalizedEmail || !password) {
      return res.status(400).json({ ok: false, error: 'E-mail et mot de passe requis.' });
    }

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      include: { teamMembers: true },
    });

    if (!user) {
      return res.status(401).json({ ok: false, error: 'Identifiants incorrects. Aucun compte trouvé.' });
    }

    if (user.passwordHash && user.passwordHash !== hashPassword(password)) {
      return res.status(401).json({ ok: false, error: 'Mot de passe incorrect.' });
    }

    return res.json({
      ok: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        avatar: user.image || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        role: user.teamMembers[0]?.role || 'MEMBER',
      },
    });
  } catch (error) {
    console.error('Erreur Auth:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

// -------------------------------------------------------------
// 2. BOOTSTRAP DE CONSULTATION (GET /api/mobile/bootstrap)
// -------------------------------------------------------------
app.get('/api/mobile/bootstrap', async (req, res) => {
  try {
    const activeUserId = req.query.userId || null;

    // Filtrer strictement les données sur les équipes dont l'utilisateur est membre
    let teamIds = [];
    if (activeUserId) {
      const memberships = await prisma.teamMember.findMany({
        where: { userId: activeUserId },
      });
      teamIds = memberships.map((m) => m.teamId);
    }

    const teamFilter = activeUserId ? { in: teamIds } : undefined;
    const teams = await prisma.team.findMany(
      teamFilter ? { where: { id: teamFilter } } : undefined
    );
    const members = await prisma.teamMember.findMany(
      teamFilter ? { where: { teamId: teamFilter } } : undefined
    );
    const memberUserIds = [...new Set(members.map((m) => m.userId))];
    if (activeUserId && !memberUserIds.includes(activeUserId)) {
      memberUserIds.push(activeUserId);
    }

    const projects = await prisma.project.findMany(
      teamFilter ? { where: { teamId: teamFilter } } : undefined
    );
    const projectIds = projects.map((p) => p.id);
    const projectFilter = activeUserId ? { in: projectIds } : undefined;

    const channels = await prisma.channel.findMany(
      teamFilter ? { where: { teamId: teamFilter } } : undefined
    );
    const channelIds = channels.map((c) => c.id);
    const channelFilter = activeUserId ? { in: channelIds } : undefined;

    const trainings = await prisma.training.findMany({
      where: teamFilter ? { teamId: teamFilter } : undefined,
      orderBy: { startsAt: 'asc' },
    });
    const trainingIds = trainings.map((t) => t.id);
    const trainingFilter = activeUserId ? { in: trainingIds } : undefined;

    const tasks = await prisma.task.findMany({
      where: projectFilter ? { projectId: projectFilter } : undefined,
      include: { assignees: true, labels: true },
      orderBy: { position: 'asc' },
    });
    const taskIds = tasks.map((t) => t.id);
    const taskFilter = activeUserId ? { in: taskIds } : undefined;

    const [
      users,
      columns,
      subtasks,
      labels,
      milestones,
      messages,
      files,
      activities,
      reports,
      enrollments,
      coachingSessions,
      coachingGoals,
      skillLevels,
    ] = await Promise.all([
      prisma.user.findMany(
        activeUserId ? { where: { id: { in: memberUserIds } } } : undefined
      ),
      prisma.column.findMany({
        where: projectFilter ? { projectId: projectFilter } : undefined,
        orderBy: { position: 'asc' },
      }),
      prisma.subtask.findMany({
        where: taskFilter ? { taskId: taskFilter } : undefined,
        orderBy: { position: 'asc' },
      }),
      prisma.label.findMany(
        projectFilter ? { where: { projectId: projectFilter } } : undefined
      ),
      prisma.milestone.findMany({
        where: projectFilter ? { projectId: projectFilter } : undefined,
        orderBy: { date: 'asc' },
      }),
      prisma.message.findMany({
        where: channelFilter ? { channelId: channelFilter } : undefined,
        orderBy: { createdAt: 'asc' },
      }),
      prisma.file.findMany({
        where: projectFilter ? { projectId: projectFilter } : undefined,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.activity.findMany({
        where: projectFilter ? { projectId: projectFilter } : undefined,
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.report.findMany({
        where: projectFilter ? { projectId: projectFilter } : undefined,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.trainingEnrollment.findMany(
        trainingFilter ? { where: { trainingId: trainingFilter } } : undefined
      ),
      prisma.coachingSession.findMany({
        where: teamFilter ? { teamId: teamFilter } : undefined,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.coachingGoal.findMany({
        where: teamFilter ? { teamId: teamFilter } : undefined,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.skillLevel.findMany(
        teamFilter ? { where: { teamId: teamFilter } } : undefined
      ),
    ]);

    // Formatage des utilisateurs avec rôle
    const enrichedUsers = users.map((u) => {
      const member = members.find((m) => m.userId === u.id);
      return {
        id: u.id,
        name: u.name,
        email: u.email,
        avatar: u.image || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        role: member ? member.role : 'MEMBER',
        joinedAt: member ? member.joinedAt.toISOString() : u.createdAt.toISOString(),
      };
    });

    // Formatage des tâches
    const normalizedTasks = tasks.map((t) => ({
      id: t.id,
      projectId: t.projectId,
      columnId: t.columnId,
      title: t.title,
      description: t.description || '',
      position: t.position,
      priority: t.priority,
      dueDate: t.dueDate ? t.dueDate.toISOString() : null,
      createdById: t.createdById,
      createdAt: t.createdAt.toISOString(),
      completedAt: t.completedAt ? t.completedAt.toISOString() : null,
      assigneeIds: t.assignees.map((a) => a.userId),
      labelIds: t.labels.map((l) => l.labelId),
    }));

    // Sécurité & Confidentialité des séances de coaching (§7.3)
    const safeCoachingSessions = coachingSessions.map((s) => {
      let slots = [];
      try {
        slots = JSON.parse(s.proposedSlots);
      } catch (e) {
        slots = [];
      }

      return {
        id: s.id,
        teamId: s.teamId,
        projectId: s.projectId,
        coachId: s.coachId,
        coacheeId: s.coacheeId,
        topic: s.topic,
        proposedSlots: slots,
        scheduledAt: s.scheduledAt ? s.scheduledAt.toISOString() : null,
        durationMin: s.durationMin,
        mode: s.mode,
        meetingUrl: s.meetingUrl,
        status: s.status,
        sharedReport: s.sharedReport,
        // Notes privées verrouillées sauf pour l'auteur coach
        privateNotes: activeUserId && activeUserId === s.coachId ? s.privateNotes : null,
        createdAt: s.createdAt.toISOString(),
      };
    });

    return res.json({
      ok: true,
      data: {
        users: enrichedUsers,
        teams,
        members,
        projects,
        columns,
        tasks: normalizedTasks,
        subtasks,
        labels,
        milestones,
        channels,
        messages,
        files,
        activities,
        reports,
        trainings,
        enrollments,
        coachingSessions: safeCoachingSessions,
        coachingGoals,
        skillLevels,
      },
    });
  } catch (error) {
    console.error('Erreur Bootstrap:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

// -------------------------------------------------------------
// 3. SYNCHRONISATION CRUD (POST /api/mobile/sync)
// -------------------------------------------------------------
app.post('/api/mobile/sync', async (req, res) => {
  try {
    const { action, userId, payload } = req.body;

    if (!action || !userId) {
      return res.status(400).json({ ok: false, error: 'action et userId requis' });
    }

    const role = await getUserRole(userId);
    const isCoachOrViewer = role === 'COACH';

    switch (action) {
      // --- CRÉATION DE TÂCHE ---
      case 'CREATE_TASK': {
        if (isCoachOrViewer) {
          return res.status(403).json({
            ok: false,
            error: 'Permission refusée : rôle Coach / Observateur en consultation seule (§4.2)',
          });
        }
        const { projectId, columnId, title, description, priority, dueDate, assigneeIds, subtasks } = payload;
        const task = await prisma.task.create({
          data: {
            projectId,
            columnId,
            title,
            description: description || '',
            position: Date.now() % 100000,
            priority: priority || 'NORMALE',
            dueDate: dueDate ? new Date(dueDate) : null,
            createdById: userId,
            subtasks: subtasks && subtasks.length
              ? {
                  create: subtasks.map((st, idx) => ({
                    title: st.title,
                    done: Boolean(st.done),
                    position: idx + 1,
                  })),
                }
              : undefined,
            assignees: assigneeIds && assigneeIds.length
              ? {
                  create: assigneeIds.map((uid) => ({ userId: uid })),
                }
              : undefined,
          },
          include: { subtasks: true, assignees: true, labels: true },
        });

        await prisma.activity.create({
          data: {
            projectId,
            taskId: task.id,
            userId,
            type: 'TASK_CREATED',
            payload: JSON.stringify({ taskTitle: task.title }),
          },
        });

        {
          const [actor, project] = await Promise.all([
            prisma.user.findUnique({ where: { id: userId } }),
            prisma.project.findUnique({ where: { id: projectId } }),
          ]);
          for (const a of task.assignees) {
            if (a.userId === userId) continue; // pas d'e-mail pour soi-même
            notifyUser(a.userId, 'taskAssigned', {
              taskTitle: task.title,
              projectName: project ? project.name : '',
              assignedBy: actor ? actor.name : 'Un membre',
              dueDate: task.dueDate,
              priority: task.priority,
            });
          }
        }

        return res.json({ ok: true, data: task });
      }

      // --- DÉPLACEMENT DE CARTE ---
      case 'MOVE_TASK': {
        if (isCoachOrViewer) {
          return res.status(403).json({
            ok: false,
            error: 'Permission refusée : le rôle Coach ne peut pas déplacer de cartes (§4.2)',
          });
        }
        const { taskId, targetColumnId } = payload;
        const targetCol = await prisma.column.findUnique({ where: { id: targetColumnId } });
        const task = await prisma.task.update({
          where: { id: taskId },
          data: {
            columnId: targetColumnId,
            completedAt: targetCol && targetCol.isDone ? new Date() : null,
          },
        });

        await prisma.activity.create({
          data: {
            projectId: task.projectId,
            taskId: task.id,
            userId,
            type: targetCol && targetCol.isDone ? 'TASK_COMPLETED' : 'TASK_MOVED',
            payload: JSON.stringify({ taskTitle: task.title, targetColumn: targetCol ? targetCol.name : '' }),
          },
        });

        return res.json({ ok: true, data: task });
      }

      // --- MODIFICATION COMPLÈTE DE TÂCHE ---
      case 'UPDATE_TASK': {
        if (isCoachOrViewer) {
          return res.status(403).json({
            ok: false,
            error: 'Permission refusée : modification désactivée pour le rôle Coach (§4.2)',
          });
        }
        const { taskId, title, description, priority, columnId, dueDate, assigneeIds } = payload;
        const targetCol = columnId ? await prisma.column.findUnique({ where: { id: columnId } }) : null;

        let newlyAssigned = [];
        if (Array.isArray(assigneeIds)) {
          const before = await prisma.taskAssignee.findMany({ where: { taskId } });
          const beforeIds = new Set(before.map((a) => a.userId));
          newlyAssigned = assigneeIds.filter((uid) => !beforeIds.has(uid) && uid !== userId);
          await prisma.taskAssignee.deleteMany({ where: { taskId } });
          if (assigneeIds.length > 0) {
            await prisma.taskAssignee.createMany({
              data: assigneeIds.map((uid) => ({ taskId, userId: uid })),
            });
          }
        }

        const updatedTask = await prisma.task.update({
          where: { id: taskId },
          data: {
            ...(title !== undefined ? { title } : {}),
            ...(description !== undefined ? { description } : {}),
            ...(priority !== undefined ? { priority } : {}),
            ...(dueDate !== undefined ? { dueDate: dueDate ? new Date(dueDate) : null } : {}),
            ...(columnId !== undefined
              ? { columnId, completedAt: targetCol && targetCol.isDone ? new Date() : null }
              : {}),
          },
        });

        if (newlyAssigned.length) {
          const [actor, project] = await Promise.all([
            prisma.user.findUnique({ where: { id: userId } }),
            prisma.project.findUnique({ where: { id: updatedTask.projectId } }),
          ]);
          for (const uid of newlyAssigned) {
            notifyUser(uid, 'taskAssigned', {
              taskTitle: updatedTask.title,
              projectName: project ? project.name : '',
              assignedBy: actor ? actor.name : 'Un membre',
              dueDate: updatedTask.dueDate,
              priority: updatedTask.priority,
            });
          }
        }

        return res.json({ ok: true, data: updatedTask });
      }

      // --- SUPPRESSION DE TÂCHE ---
      case 'DELETE_TASK': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        await prisma.task.delete({ where: { id: payload.taskId } });
        return res.json({ ok: true });
      }

      // --- COCHER SOUS-TÂCHE ---
      case 'TOGGLE_SUBTASK': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const sub = await prisma.subtask.findUnique({ where: { id: payload.subtaskId } });
        if (!sub) return res.status(404).json({ ok: false, error: 'Sous-tâche introuvable' });

        const updated = await prisma.subtask.update({
          where: { id: sub.id },
          data: { done: !sub.done },
        });
        return res.json({ ok: true, data: updated });
      }

      // --- ENVOYER UN MESSAGE DE CHAT ---
      case 'SEND_MESSAGE': {
        const { projectId, content } = payload;
        let channel = await prisma.channel.findFirst({ where: { projectId } });
        if (!channel) {
          const project = await prisma.project.findUnique({ where: { id: projectId } });
          channel = await prisma.channel.create({
            data: {
              teamId: project ? project.teamId : 'team-1',
              projectId,
              name: 'Général',
              type: 'PROJECT',
            },
          });
        }
        const msg = await prisma.message.create({
          data: {
            channelId: channel.id,
            authorId: userId,
            content,
          },
        });
        return res.json({ ok: true, data: msg });
      }

      // --- INSCRIPTION FORMATION AVEC CAPACITÉ MAX (§7.3) ---
      case 'ENROLL_TRAINING': {
        const { trainingId } = payload;
        const training = await prisma.training.findUnique({
          where: { id: trainingId },
          include: { enrollments: { where: { status: 'ENROLLED' } } },
        });
        if (!training) return res.status(404).json({ ok: false, error: 'Formation introuvable' });

        if (training.enrollments.length >= training.capacity) {
          return res.status(400).json({
            ok: false,
            error: 'Formation complète : capacité maximale atteinte (§7.3)',
          });
        }

        const existing = await prisma.trainingEnrollment.findUnique({
          where: { trainingId_userId: { trainingId, userId } },
        });
        if (existing) return res.json({ ok: true, data: existing });

        const enrollment = await prisma.trainingEnrollment.create({
          data: { trainingId, userId, status: 'ENROLLED' },
        });
        notifyUser(userId, 'trainingEnrolled', {
          title: training.title,
          startsAt: training.startsAt,
          mode: training.mode,
          location: training.location,
          meetingUrl: training.meetingUrl,
        });
        return res.json({ ok: true, data: enrollment });
      }

      case 'UNENROLL_TRAINING': {
        const { trainingId } = payload;
        await prisma.trainingEnrollment.deleteMany({
          where: { trainingId, userId },
        });
        return res.json({ ok: true });
      }

      // --- DEMANDER UN COACHING ---
      case 'REQUEST_COACHING': {
        const { coachId, topic, proposedSlots, durationMin, mode, projectId } = payload;
        const userTeamId = (await getUserTeamId(userId)) || 'team-1';
        const session = await prisma.coachingSession.create({
          data: {
            teamId: userTeamId,
            projectId: projectId || null,
            coachId,
            coacheeId: userId,
            topic,
            proposedSlots: JSON.stringify(proposedSlots || []),
            durationMin: durationMin || 45,
            mode: mode || 'ONLINE',
            status: 'REQUESTED',
          },
        });
        {
          const coachee = await prisma.user.findUnique({ where: { id: userId } });
          notifyUser(coachId, 'coachingRequested', {
            coacheeName: coachee ? coachee.name : 'Un membre',
            topic,
          });
        }
        return res.json({ ok: true, data: session });
      }

      // --- CONFIRMER CRÉNEAU (COACH) ---
      case 'CONFIRM_COACHING': {
        const { sessionId, scheduledAt } = payload;
        const safeRoom = String(sessionId).replace(/[^a-zA-Z0-9]/g, '').slice(-10);
        const session = await prisma.coachingSession.update({
          where: { id: sessionId },
          data: {
            status: 'CONFIRMED',
            scheduledAt: new Date(scheduledAt),
            meetingUrl: `https://meet.jit.si/studyflow-coaching-${safeRoom}`,
          },
        });
        {
          const coach = await prisma.user.findUnique({ where: { id: session.coachId } });
          notifyUser(session.coacheeId, 'coachingConfirmed', {
            coachName: coach ? coach.name : 'Votre coach',
            topic: session.topic,
            scheduledAt: session.scheduledAt,
            meetingUrl: session.meetingUrl,
          });
        }
        return res.json({ ok: true, data: session });
      }

      // --- CLÔTURER SÉANCE ET NOTES PRIVÉES (COACH SEUL) ---
      case 'COMPLETE_COACHING': {
        const { sessionId, sharedReport, privateNotes } = payload;
        const existing = await prisma.coachingSession.findUnique({ where: { id: sessionId } });
        if (!existing || existing.coachId !== userId) {
          return res.status(403).json({
            ok: false,
            error: 'Seul le coach de la séance peut enregistrer les notes privées',
          });
        }
        const updated = await prisma.coachingSession.update({
          where: { id: sessionId },
          data: {
            status: 'DONE',
            sharedReport,
            privateNotes: privateNotes !== undefined ? privateNotes : existing.privateNotes,
          },
        });
        return res.json({ ok: true, data: updated });
      }

      // --- PROGRESSION D'OBJECTIF ---
      case 'UPDATE_GOAL_PROGRESS': {
        const { goalId, progress } = payload;
        const updated = await prisma.coachingGoal.update({
          where: { id: goalId },
          data: {
            progress,
            status: progress >= 100 ? 'ACHIEVED' : 'OPEN',
          },
        });
        return res.json({ ok: true, data: updated });
      }

      // --- GÉNÉRER UN RAPPORT (M4) ---
      case 'GENERATE_REPORT': {
        const { projectId, period = 'ALL' } = payload;
        const tasks = await prisma.task.findMany({ where: { projectId } });
        const doneCol = await prisma.column.findFirst({ where: { projectId, isDone: true } });
        let selectedTasks = tasks;
        if (period !== 'ALL') {
          const days = Number(period) || 30;
          const cutoff = new Date(Date.now() - days * 86400000);
          selectedTasks = tasks.filter((task) => task.dueDate && new Date(task.dueDate) >= cutoff);
        }
        const doneColumnIds = (await prisma.column.findMany({ where: { projectId, isDone: true }, select: { id: true } }))
          .map((column) => column.id);
        const completedCount = selectedTasks.filter((task) => doneColumnIds.includes(task.columnId)).length;
        const overdueCount = selectedTasks.filter((task) =>
          task.dueDate &&
          new Date(task.dueDate) < new Date() &&
          !doneColumnIds.includes(task.columnId)
        ).length;
        const rate = tasks.length > 0 ? Math.round((completedCount / tasks.length) * 100) : 0;
        const periodDays = period === 'ALL' ? null : Number(period) || 30;
        const periodStart = periodDays ? new Date(Date.now() - periodDays * 86400000) : new Date(0);
        const project = await prisma.project.findUnique({ where: { id: projectId } });

        const report = await prisma.report.create({
          data: {
            projectId,
            createdById: userId,
            periodStart,
            periodEnd: new Date(),
            data: JSON.stringify({
              title: `Rapport d'étape - ${project ? project.name : 'Projet'} - ${new Date().toLocaleDateString('fr-FR')}`,
              completionRate: rate,
              totalTasks: selectedTasks.length,
              completedTasks: completedCount,
              overdueTasks: overdueCount,
              period,
            }),
          },
        });
        return res.json({ ok: true, data: report });
      }

      case 'DELETE_REPORT': {
        const { reportId } = payload;
        await prisma.report.delete({ where: { id: reportId } }).catch(() => null);
        return res.json({ ok: true });
      }

      // --- GESTION DES COLONNES KANBAN (M2) ---
      case 'CREATE_COLUMN': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { id, projectId, name, position, wipLimit, isDone } = payload;
        if (!projectId || !name) {
          return res.status(400).json({ ok: false, error: 'projectId et name requis' });
        }
        const col = await prisma.column.create({
          data: {
            ...(id ? { id } : {}),
            projectId,
            name: name.trim(),
            position: typeof position === 'number' ? position : 1000,
            wipLimit: wipLimit ?? null,
            isDone: Boolean(isDone),
          },
        });
        return res.json({ ok: true, data: col });
      }

      case 'UPDATE_COLUMN': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { columnId, name, position, wipLimit, isDone } = payload;
        const updated = await prisma.column.update({
          where: { id: columnId },
          data: {
            ...(name !== undefined ? { name: name.trim() } : {}),
            ...(position !== undefined ? { position } : {}),
            ...(wipLimit !== undefined ? { wipLimit } : {}),
            ...(isDone !== undefined ? { isDone: Boolean(isDone) } : {}),
          },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'REORDER_COLUMNS': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { columns: cols } = payload;
        if (Array.isArray(cols)) {
          for (const c of cols) {
            await prisma.column
              .update({ where: { id: c.id }, data: { position: c.position } })
              .catch(() => null);
          }
        }
        return res.json({ ok: true });
      }

      case 'DELETE_COLUMN': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { columnId, fallbackColumnId, ensureDoneColumnId } = payload;
        if (fallbackColumnId) {
          await prisma.task
            .updateMany({ where: { columnId }, data: { columnId: fallbackColumnId } })
            .catch(() => null);
        }
        if (ensureDoneColumnId) {
          await prisma.column
            .update({ where: { id: ensureDoneColumnId }, data: { isDone: true } })
            .catch(() => null);
        }
        await prisma.column.delete({ where: { id: columnId } }).catch(() => null);
        return res.json({ ok: true });
      }

      // --- PROJETS (M2) ---
      case 'CREATE_PROJECT': {
        if (isCoachOrViewer || role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { name, description, color, teamId } = payload;
        const resolvedTeamId = teamId || (await getUserTeamId(userId)) || 'team-1';
        const project = await prisma.project.create({
          data: {
            teamId: resolvedTeamId,
            name: (name || 'Nouveau projet').trim(),
            description: description || '',
            color: color || '#4f46e5',
          },
        });
        await prisma.column.createMany({
          data: [
            { projectId: project.id, name: 'À faire', position: 1000, isDone: false },
            { projectId: project.id, name: 'En cours', position: 2000, wipLimit: 3, isDone: false },
            { projectId: project.id, name: 'Terminé', position: 3000, isDone: true },
          ],
        });
        return res.json({ ok: true, data: project });
      }

      case 'UPDATE_PROJECT': {
        if (isCoachOrViewer || role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { projectId, name, description, color } = payload;
        const updated = await prisma.project.update({
          where: { id: projectId },
          data: {
            ...(name !== undefined ? { name: name.trim() } : {}),
            ...(description !== undefined ? { description } : {}),
            ...(color !== undefined ? { color } : {}),
          },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'DELETE_PROJECT': {
        if (isCoachOrViewer || role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Seul le propriétaire ou l’administrateur peut supprimer un projet.' });
        }
        const { projectId } = payload;
        if (!projectId) {
          return res.status(400).json({ ok: false, error: 'Projet requis.' });
        }
        const project = await prisma.project.findUnique({
          where: { id: projectId },
        });
        if (!project) {
          return res.status(404).json({ ok: false, error: 'Projet introuvable.' });
        }
        const teamId = await getUserTeamId(userId);
        if (!teamId || project.teamId !== teamId) {
          return res.status(403).json({ ok: false, error: 'Ce projet appartient à une autre équipe.' });
        }
        await prisma.project.delete({ where: { id: projectId } });
        return res.json({ ok: true });
      }

      // --- ÉDITION / SUPPRESSION MESSAGES CHAT (M5) ---
      case 'EDIT_MESSAGE': {
        const { messageId, content } = payload;
        const existing = await prisma.message.findUnique({ where: { id: messageId } });
        if (!existing || existing.authorId !== userId) {
          return res.status(403).json({ ok: false, error: 'Seul l\'auteur peut modifier ce message.' });
        }
        const updated = await prisma.message.update({
          where: { id: messageId },
          data: { content: content.trim() },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'DELETE_MESSAGE': {
        const { messageId } = payload;
        const existing = await prisma.message.findUnique({ where: { id: messageId } });
        const canModerate = role === 'OWNER' || role === 'COACH';
        if (!existing || (existing.authorId !== userId && !canModerate)) {
          return res.status(403).json({ ok: false, error: 'Permission refusée pour supprimer ce message.' });
        }
        await prisma.message.delete({ where: { id: messageId } });
        return res.json({ ok: true });
      }

      // --- JALONS (M4) ---
      case 'CREATE_MILESTONE': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { projectId, title, date, description } = payload;
        const milestone = await prisma.milestone.create({
          data: {
            projectId,
            title: title.trim(),
            date: new Date(date),
            description: description || null,
          },
        });
        return res.json({ ok: true, data: milestone });
      }

      case 'UPDATE_MILESTONE': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée (§4.2)' });
        }
        const { milestoneId, title, date, description } = payload;
        const updated = await prisma.milestone.update({
          where: { id: milestoneId },
          data: {
            ...(title !== undefined ? { title: title.trim() } : {}),
            ...(date !== undefined ? { date: new Date(date) } : {}),
            ...(description !== undefined ? { description } : {}),
          },
        });
        return res.json({ ok: true, data: updated });
      }

      // --- FORMATIONS, COACHING, OBJECTIFS & COMPÉTENCES (M7) ---
      case 'CREATE_TRAINING': {
        const canManage = role === 'COACH' || role === 'OWNER';
        if (!canManage) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const { title, description, skill, level, capacity, mode, location, startsAt, endsAt } = payload;
        const resolvedTeamId = (await getUserTeamId(userId)) || 'team-1';
        const trainingId = `training-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
        const meetingUrl = mode === 'ONLINE'
          ? `https://meet.jit.si/studyflow-${trainingId.replace(/[^a-zA-Z0-9]/g, '').slice(-12)}`
          : null;
        const training = await prisma.training.create({
          data: {
            id: trainingId,
            teamId: resolvedTeamId,
            trainerId: userId,
            title: title.trim(),
            description: description || '',
            skill: skill || 'Général',
            level: level || 'INTERMEDIATE',
            capacity: Number(capacity) || 10,
            mode: mode || 'ONLINE',
            location: location || null,
            meetingUrl,
            startsAt: startsAt ? new Date(startsAt) : new Date(Date.now() + 86400000),
            endsAt: endsAt ? new Date(endsAt) : new Date(Date.now() + 90000000),
          },
        });
        return res.json({ ok: true, data: training });
      }

      case 'UPDATE_TRAINING': {
        const canManage = role === 'COACH' || role === 'OWNER';
        if (!canManage) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const { trainingId, title, description, skill, level, capacity, mode, location, startsAt, endsAt } = payload;
        const updated = await prisma.training.update({
          where: { id: trainingId },
          data: {
            ...(title !== undefined ? { title: title.trim() } : {}),
            ...(description !== undefined ? { description } : {}),
            ...(skill !== undefined ? { skill } : {}),
            ...(level !== undefined ? { level } : {}),
            ...(capacity !== undefined ? { capacity: Number(capacity) } : {}),
            ...(mode !== undefined ? { mode } : {}),
            ...(location !== undefined ? { location } : {}),
            ...(startsAt !== undefined ? { startsAt: new Date(startsAt) } : {}),
            ...(endsAt !== undefined ? { endsAt: new Date(endsAt) } : {}),
          },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'DELETE_TRAINING': {
        const canManage = role === 'COACH' || role === 'OWNER';
        if (!canManage) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        await prisma.training.delete({ where: { id: payload.trainingId } }).catch(() => null);
        return res.json({ ok: true });
      }

      case 'DELETE_COACHING': {
        const existing = await prisma.coachingSession.findUnique({ where: { id: payload.sessionId } });
        if (!existing || (existing.coachId !== userId && existing.coacheeId !== userId && role !== 'OWNER')) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        await prisma.coachingSession.delete({ where: { id: payload.sessionId } });
        return res.json({ ok: true });
      }

      case 'DELETE_GOAL': {
        await prisma.coachingGoal.delete({ where: { id: payload.goalId } }).catch(() => null);
        return res.json({ ok: true });
      }

      case 'ASSESS_SKILL': {
        const { targetUserId, skill, level, selfAssessed } = payload;
        const uid = targetUserId || userId;
        const existing = await prisma.skillLevel.findFirst({
          where: { userId: uid, skill },
        });
        if (existing) {
          const updated = await prisma.skillLevel.update({
            where: { id: existing.id },
            data: { level: Number(level), selfAssessed: Boolean(selfAssessed) },
          });
          return res.json({ ok: true, data: updated });
        }
        const resolvedTeamId = (await getUserTeamId(userId)) || 'team-1';
        const created = await prisma.skillLevel.create({
          data: {
            teamId: resolvedTeamId,
            userId: uid,
            skill: skill.trim(),
            level: Number(level),
            selfAssessed: Boolean(selfAssessed),
          },
        });
        return res.json({ ok: true, data: created });
      }

      // --- ÉQUIPES : REJOINDRE PAR CODE OU AJOUTER PAR E-MAIL ---
      case 'JOIN_TEAM': {
        const { inviteToken } = payload;
        const team = await prisma.team.findUnique({ where: { inviteToken: (inviteToken || '').trim() } });
        if (!team) {
          return res.status(404).json({ ok: false, error: 'Code d\'invitation invalide.' });
        }
        const existing = await prisma.teamMember.findUnique({
          where: { teamId_userId: { teamId: team.id, userId } },
        });
        if (!existing) {
          await prisma.teamMember.create({
            data: { teamId: team.id, userId, role: 'MEMBER' },
          });
          const joiner = await prisma.user.findUnique({ where: { id: userId } });
          notifyUser(team.ownerId, 'memberJoined', {
            memberName: joiner ? joiner.name : 'Un membre',
            teamName: team.name,
          });
        }
        return res.json({ ok: true, data: team });
      }

      case 'INVITE_MEMBER': {
        if (role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Seul le propriétaire peut inviter des membres.' });
        }
        const targetEmail = (payload.email || '').trim().toLowerCase();
        const targetRole = payload.role || 'MEMBER';
        const targetUser = await prisma.user.findUnique({ where: { email: targetEmail } });
        if (!targetUser) {
          return res.status(404).json({ ok: false, error: 'Aucun utilisateur inscrit avec cet e-mail.' });
        }
        const teamId = await getUserTeamId(userId);
        if (!teamId) {
          return res.status(400).json({ ok: false, error: 'Aucune équipe active.' });
        }
        const existing = await prisma.teamMember.findUnique({
          where: { teamId_userId: { teamId, userId: targetUser.id } },
        });
        if (existing) {
          return res.status(409).json({ ok: false, error: 'Cet utilisateur est déjà dans l\'équipe.' });
        }
        const member = await prisma.teamMember.create({
          data: { teamId, userId: targetUser.id, role: targetRole },
        });
        {
          const [team, inviter] = await Promise.all([
            prisma.team.findUnique({ where: { id: teamId } }),
            prisma.user.findUnique({ where: { id: userId } }),
          ]);
          notifyUser(targetUser.id, 'addedToTeam', {
            teamName: team ? team.name : 'votre équipe',
            role: targetRole,
            invitedBy: inviter ? inviter.name : null,
          });
        }
        return res.json({ ok: true, data: member });
      }

      case 'UPDATE_MEMBER_ROLE': {
        if (role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Seul le propriétaire peut modifier les rôles.' });
        }
        const { targetUserId, newRole } = payload;
        if (!targetUserId || !newRole) {
          return res.status(400).json({ ok: false, error: 'Paramètres manquants.' });
        }
        const allowedRoles = ['OWNER', 'MEMBER', 'COACH'];
        if (!allowedRoles.includes(newRole)) {
          return res.status(400).json({ ok: false, error: 'Rôle invalide.' });
        }
        if (targetUserId === userId) {
          return res.status(400).json({ ok: false, error: 'Vous ne pouvez pas modifier votre propre rôle.' });
        }
        const teamId = await getUserTeamId(userId);
        if (!teamId) {
          return res.status(400).json({ ok: false, error: 'Aucune équipe active.' });
        }
        const targetMember = await prisma.teamMember.findUnique({
          where: { teamId_userId: { teamId, userId: targetUserId } },
        });
        if (!targetMember) {
          return res.status(404).json({ ok: false, error: 'Membre introuvable dans cette équipe.' });
        }
        if (targetMember.role === 'OWNER' && role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Un administrateur ne peut pas modifier le rôle du propriétaire.' });
        }
        const updated = await prisma.teamMember.update({
          where: { teamId_userId: { teamId, userId: targetUserId } },
          data: { role: newRole },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'REMOVE_MEMBER': {
        if (role !== 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Seul le propriétaire peut retirer un membre.' });
        }
        const { targetUserId } = payload;
        if (!targetUserId || targetUserId === userId) {
          return res.status(400).json({ ok: false, error: 'Impossible de vous retirer vous-même.' });
        }
        const teamId = await getUserTeamId(userId);
        if (!teamId) {
          return res.status(400).json({ ok: false, error: 'Aucune équipe active.' });
        }
        const targetMember = await prisma.teamMember.findUnique({
          where: { teamId_userId: { teamId, userId: targetUserId } },
        });
        if (!targetMember) {
          return res.status(404).json({ ok: false, error: 'Membre introuvable.' });
        }
        if (targetMember.role === 'OWNER') {
          return res.status(403).json({ ok: false, error: 'Le propriétaire ne peut pas être retiré de l\'équipe.' });
        }
        await prisma.teamMember.delete({
          where: { teamId_userId: { teamId, userId: targetUserId } },
        });
        return res.json({ ok: true });
      }

      // --- FICHIERS (M6) ---
      case 'UPLOAD_FILE': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const { projectId, name, mimeType, size, contentBase64 } = payload;
        const safeName = (name || 'fichier').replace(/[^a-zA-Z0-9._-]/g, '_');
        const storageKey = `${Date.now()}-${safeName}`;
        const buf = contentBase64 ? Buffer.from(contentBase64, 'base64') : Buffer.alloc(0);
        const actualSize = contentBase64 ? buf.length : (Number(size) || 0);
        fs.writeFileSync(path.join(UPLOADS_DIR, storageKey), buf);
        const file = await prisma.file.create({
          data: {
            projectId,
            uploaderId: userId,
            name: (name || 'fichier').trim(),
            mimeType: mimeType || 'application/octet-stream',
            size: actualSize,
            currentVersion: 1,
            versions: {
              create: {
                version: 1,
                storageKey,
                size: actualSize,
                uploaderId: userId,
              },
            },
          },
          include: { versions: true },
        });
        return res.json({ ok: true, data: file });
      }

      case 'UPLOAD_FILE_VERSION': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const { fileId, mimeType, size, contentBase64 } = payload;
        const existing = await prisma.file.findUnique({ where: { id: fileId } });
        if (!existing) {
          return res.status(404).json({ ok: false, error: 'Fichier introuvable' });
        }
        const nextVersion = (existing.currentVersion || 1) + 1;
        const safeName = existing.name.replace(/[^a-zA-Z0-9._-]/g, '_');
        const storageKey = `${Date.now()}-v${nextVersion}-${safeName}`;
        const buf = contentBase64 ? Buffer.from(contentBase64, 'base64') : Buffer.alloc(0);
        const actualSize = contentBase64 ? buf.length : (Number(size) || 0);
        fs.writeFileSync(path.join(UPLOADS_DIR, storageKey), buf);
        const updated = await prisma.file.update({
          where: { id: fileId },
          data: {
            currentVersion: nextVersion,
            size: actualSize,
            ...(mimeType ? { mimeType } : {}),
            versions: {
              create: {
                version: nextVersion,
                storageKey,
                size: actualSize,
                uploaderId: userId,
              },
            },
          },
          include: { versions: { orderBy: { version: 'desc' } } },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'RENAME_FILE': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const { fileId, name } = payload;
        const trimmed = String(name || '').trim();
        if (!fileId || !trimmed) {
          return res.status(400).json({ ok: false, error: 'Nom de fichier requis' });
        }
        const updated = await prisma.file.update({
          where: { id: fileId },
          data: { name: trimmed },
        });
        return res.json({ ok: true, data: updated });
      }

      case 'DELETE_FILE': {
        if (isCoachOrViewer) {
          return res.status(403).json({ ok: false, error: 'Permission refusée' });
        }
        const existing = await prisma.file.findUnique({
          where: { id: payload.fileId },
          include: { versions: true },
        });
        if (existing && existing.versions) {
          for (const v of existing.versions) {
            const filePath = path.join(UPLOADS_DIR, path.basename(v.storageKey));
            if (fs.existsSync(filePath)) {
              fs.unlinkSync(filePath);
            }
          }
        }
        await prisma.file.delete({ where: { id: payload.fileId } }).catch(() => null);
        return res.json({ ok: true });
      }

      default:
        return res.status(400).json({ ok: false, error: `Action inconnue: ${action}` });
    }
  } catch (error) {
    console.error('Erreur Sync:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

// Téléchargement de fichier réel
app.get('/api/mobile/files/:id', async (req, res) => {
  try {
    const file = await prisma.file.findUnique({
      where: { id: req.params.id },
      include: { versions: { orderBy: { version: 'desc' } } },
    });
    if (!file || !file.versions.length) {
      return res.status(404).json({ ok: false, error: 'Fichier introuvable' });
    }
    const latest = file.versions[0];
    const filePath = path.join(UPLOADS_DIR, path.basename(latest.storageKey));
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ ok: false, error: 'Contenu du fichier introuvable sur le serveur' });
    }
    res.setHeader('Content-Type', file.mimeType || 'application/octet-stream');
    const disposition = req.query.inline === '1' ? 'inline' : 'attachment';
    res.setHeader('Content-Disposition', `${disposition}; filename="${encodeURIComponent(file.name)}"`);
    return res.sendFile(filePath);
  } catch (error) {
    return res.status(500).json({ ok: false, error: error.message });
  }
});

app.get('/api/mobile/reports/:id', async (req, res) => {
  try {
    const report = await prisma.report.findUnique({
      where: { id: req.params.id },
      include: { project: true },
    });
    if (!report) {
      return res.status(404).json({ ok: false, error: 'Rapport introuvable.' });
    }

    let data = {};
    try {
      data = JSON.parse(report.data);
    } catch (_) {}
    const title = data.title || `Rapport ${report.project?.name || 'StudyFlow'}`;
    const completionRate = Number(data.completionRate || 0);
    const totalTasks = Number(data.totalTasks || 0);
    const completedTasks = Number(data.completedTasks || 0);
    const overdueTasks = Number(data.overdueTasks || 0);
    const period = data.period || 'ALL';
    const periodLabel = period === 'ALL'
      ? 'Projet complet'
      : `Derniers ${period} jours`;
    const createdAt = report.createdAt.toLocaleString('fr-FR');

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Content-Disposition', `inline; filename="rapport-${report.id}.html"`);
    return res.send(`<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title.replace(/[&<>]/g, '')}</title>
  <style>
    body { margin:0; background:#f1f5f9; color:#0f172a; font-family:Arial,sans-serif; }
    main { max-width:820px; margin:32px auto; background:white; border-radius:18px; box-shadow:0 12px 40px #0f172a18; overflow:hidden; }
    header { padding:28px 32px; background:#4f46e5; color:white; }
    h1 { margin:0 0 8px; font-size:26px; }
    section { padding:24px 32px; }
    .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:12px; }
    .kpi { border:1px solid #e2e8f0; border-radius:14px; padding:16px; background:#f8fafc; }
    .kpi strong { display:block; margin-top:6px; font-size:24px; color:#4f46e5; }
    .bar { height:12px; border-radius:999px; background:#e2e8f0; overflow:hidden; }
    .bar div { height:100%; border-radius:999px; background:#10b981; }
    table { width:100%; border-collapse:collapse; margin-top:16px; }
    th,td { text-align:left; border-bottom:1px solid #e2e8f0; padding:10px; }
    @media print { body{background:white} main{box-shadow:none;margin:0} }
  </style>
</head>
<body>
  <main>
    <header>
      <h1>${String(title).replace(/[&<>]/g, '')}</h1>
      <div>${report.project?.name || 'StudyFlow'} · ${periodLabel} · Généré le ${createdAt}</div>
    </header>
    <section>
      <div class="grid">
        <div class="kpi">Avancement<strong>${completionRate}%</strong></div>
        <div class="kpi">Tâches totales<strong>${totalTasks}</strong></div>
        <div class="kpi">Terminées<strong>${completedTasks}</strong></div>
        <div class="kpi">En retard<strong>${overdueTasks}</strong></div>
      </div>
      <h2>Progression du projet</h2>
      <div class="bar"><div style="width:${Math.max(0, Math.min(100, completionRate))}%"></div></div>
      <table>
        <tbody>
          <tr><th>Période</th><td>${periodLabel}</td></tr>
          <tr><th>Projet</th><td>${String(report.project?.name || 'Projet').replace(/[&<>]/g, '')}</td></tr>
          <tr><th>Rapport</th><td>${report.id}</td></tr>
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>`);
  } catch (error) {
    return res.status(500).json({ ok: false, error: error.message });
  }
});

// -------------------------------------------------------------
// IA / ML locale déterministe par module
// -------------------------------------------------------------
app.get('/api/mobile/ai', (req, res) => {
  res.json({ ok: true, data: { capabilities: ai.listCapabilities() } });
});

app.post('/api/mobile/ai', async (req, res) => {
  try {
    const { action, module, userId, payload = {} } = req.body || {};
    const result = await ai.handle({
      prisma,
      action: action || module,
      userId,
      payload: payload || {},
    });
    return res.json({ ok: true, data: result });
  } catch (error) {
    const status = error.status && error.status >= 400 && error.status < 600 ? error.status : 500;
    return res.status(status).json({ ok: false, error: error.message });
  }
});

app.post('/api/mobile/ai/generate', async (req, res) => {
  try {
    const { type, userId, payload = {} } = req.body || {};
    if (!userId || !type) {
      return res.status(400).json({ ok: false, error: 'userId et type requis' });
    }
    const role = await getUserRole(userId);
    const result = await aiGenerator.generate({
      prisma,
      type,
      userId,
      role,
      payload: payload || {},
    });
    return res.json({ ok: true, data: result });
  } catch (error) {
    const status = error.status && error.status >= 400 && error.status < 600 ? error.status : 500;
    return res.status(status).json({ ok: false, error: error.message });
  }
});

// -------------------------------------------------------------
// ASSISTANT D'AIDE (chatbot) : POST /api/mobile/assistant
// -------------------------------------------------------------
app.post('/api/mobile/assistant', async (req, res) => {
  try {
    const { userId, message, history, module } = req.body || {};
    const result = await assistant.ask({ prisma, userId, message, history, module });
    return res.json({ ok: true, data: result });
  } catch (error) {
    const status = error.status && error.status >= 400 && error.status < 600 ? error.status : 500;
    return res.status(status).json({ ok: false, error: error.message });
  }
});

app.get('/api/mobile/assistant/status', (req, res) => {
  res.json({
    ok: true,
    data: {
      provider: process.env.GROQ_API_KEY ? 'groq' : 'faq',
      mailEnabled: process.env.MAIL_ENABLED !== 'false',
      smtpConfigured: Boolean(process.env.SMTP_HOST),
    },
  });
});

// Statut racine
app.get('/', (req, res) => {
  res.json({
    status: 'StudyFlow Mobile REST API is running',
    version: '2.1.0',
    orm: 'Prisma SQLite',
    endpoints: ['/api/mobile/auth', '/api/mobile/bootstrap', '/api/mobile/sync', '/api/mobile/ai', '/api/mobile/assistant'],
  });
});

app.listen(PORT, () => {
  console.log(`[StudyFlow Mobile Backend] REST API démarrée sur http://localhost:${PORT}`);
  scheduler.start(prisma);
});

