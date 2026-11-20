// Rappels d'échéance : e-mail ~24 h avant et en cas de retard.
// Utilise la table Reminder existante (kind H24 / OVERDUE) pour ne jamais envoyer deux fois.
const mailer = require('./index');

const HOUR = 3600 * 1000;

async function claim(prisma, taskId, userId, kind, now) {
  const existing = await prisma.reminder.findFirst({ where: { taskId, userId, kind } });
  if (existing) return false;
  await prisma.reminder.create({ data: { taskId, userId, kind, remindAt: now, sentAt: now } });
  return true;
}

async function runOnce(prisma) {
  const now = new Date();
  const tasks = await prisma.task.findMany({
    where: {
      completedAt: null,
      archivedAt: null,
      dueDate: { not: null, lte: new Date(now.getTime() + 24 * HOUR) },
      column: { isDone: false },
    },
    include: { assignees: true },
  });

  let sent = 0;
  for (const task of tasks) {
    const overdue = new Date(task.dueDate) < now;
    const kind = overdue ? 'OVERDUE' : 'H24';
    for (const { userId } of task.assignees) {
      if (await claim(prisma, task.id, userId, kind, now)) {
        mailer.queue(prisma, userId, overdue ? 'taskOverdue' : 'taskDueSoon', {
          taskTitle: task.title,
          dueDate: task.dueDate,
        });
        sent++;
      }
    }
  }
  if (sent) console.log(`[scheduler] ${sent} rappel(s) envoyé(s)`);
}

function start(prisma) {
  const minutes = Number(process.env.SCHEDULER_INTERVAL_MIN || 15);
  const tick = () => runOnce(prisma).catch((e) => console.error('[scheduler]', e.message));
  setTimeout(tick, 10 * 1000);
  const deadlineInterval = setInterval(tick, minutes * 60 * 1000);
  const sentWeeks = new Set();
  const weeklyTick = () => {
    const now = new Date();
    if (now.getDay() !== 1) return;
    const key = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
    if (sentWeeks.has(key)) return;
    runWeekly(prisma).then((count) => {
      if (count > 0) sentWeeks.add(key);
    }).catch((error) => console.error('[scheduler] résumé hebdomadaire:', error.message));
  };
  setTimeout(weeklyTick, 15 * 1000);
  const weeklyInterval = setInterval(weeklyTick, 60 * 60 * 1000);
  return { deadlineInterval, weeklyInterval };
}

async function runWeekly(prisma) {
  const now = new Date();
  const end = new Date(now.getTime() + 7 * 86400000);
  const memberships = await prisma.teamMember.findMany({
    include: { user: true, team: { include: { projects: true } } },
  });
  let sent = 0;
  for (const membership of memberships) {
    for (const project of membership.team.projects) {
      const [tasks, milestones, doneColumns] = await Promise.all([
        prisma.task.findMany({ where: { projectId: project.id, dueDate: { gte: now, lte: end } } }),
        prisma.milestone.findMany({ where: { projectId: project.id, date: { gte: now, lte: end } } }),
        prisma.column.findMany({ where: { projectId: project.id, isDone: true }, select: { id: true } }),
      ]);
      const doneIds = new Set(doneColumns.map((column) => column.id));
      const overdueCount = await prisma.task.count({
        where: { projectId: project.id, dueDate: { lt: now }, completedAt: null, columnId: { notIn: [...doneIds] } },
      });
      const upcoming = [
        ...tasks.map((task) => `- ${new Date(task.dueDate).toLocaleDateString('fr-FR')} : ${task.title}`),
        ...milestones.map((milestone) => `- ${new Date(milestone.date).toLocaleDateString('fr-FR')} : ${milestone.title}`),
      ].join('\n');
      mailer.queue(prisma, membership.userId, 'weeklySummary', {
        projectName: project.name,
        period: `${now.toLocaleDateString('fr-FR')} - ${end.toLocaleDateString('fr-FR')}`,
        taskCount: tasks.length,
        overdueCount,
        milestoneCount: milestones.length,
        upcoming,
      });
      sent++;
    }
  }
  if (sent) console.log(`[scheduler] ${sent} résumé(s) hebdomadaire(s) envoyé(s)`);
  return sent;
}

module.exports = { start, runOnce, runWeekly };
