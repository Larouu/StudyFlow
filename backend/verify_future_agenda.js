const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  const team = await prisma.team.findUnique({
    where: { inviteToken: 'STUDY-S5-2026' },
    include: {
      projects: {
        include: {
          tasks: {
            include: {
              assignees: { include: { user: true } },
              subtasks: true,
            },
          },
          milestones: true,
        },
      },
    },
  });
  if (!team) throw new Error('Team not found');

  for (const project of team.projects) {
    const futureTasks = project.tasks.filter(
      (task) => task.dueDate && task.dueDate >= new Date('2026-11-20T00:00:00.000Z'),
    );
    const futureMilestones = project.milestones.filter(
      (milestone) => milestone.date >= new Date('2026-11-20T00:00:00.000Z'),
    );
    console.log(JSON.stringify({
      project: project.name,
      tasks: futureTasks.map((task) => ({
        title: task.title,
        dueDate: task.dueDate,
        assignees: task.assignees.map((assignee) => assignee.user.email),
        subtasks: task.subtasks.length,
      })),
      milestones: futureMilestones.map((milestone) => ({
        title: milestone.title,
        date: milestone.date,
      })),
    }, null, 2));
  }
  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
