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
  return setInterval(tick, minutes * 60 * 1000);
}

module.exports = { start, runOnce };
