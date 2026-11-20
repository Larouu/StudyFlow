const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');

async function main() {
  const prisma = new PrismaClient();
  const team = await prisma.team.findUnique({
    where: { inviteToken: 'STUDY-S5-2026' },
    include: {
      projects: { orderBy: { id: 'asc' } },
      members: { include: { user: true } },
    },
  });
  if (!team) throw new Error('Team STUDY-S5-2026 not found');

  const project = team.projects[0];
  if (!project) throw new Error('No project found for STUDY-S5-2026');

  const assigneeEmail = 'achraflarousse52@gmail.com';
  let assignee = await prisma.user.findUnique({ where: { email: assigneeEmail } });
  if (!assignee) {
    assignee = await prisma.user.create({
      data: {
        name: 'Achref Larousse',
        email: assigneeEmail,
        passwordHash: crypto.createHash('sha256').update('Member2026!').digest('hex'),
      },
    });
  }

  const existingMembership = await prisma.teamMember.findUnique({
    where: {
      teamId_userId: {
        teamId: team.id,
        userId: assignee.id,
      },
    },
  });
  if (!existingMembership) {
    await prisma.teamMember.create({
      data: {
        teamId: team.id,
        userId: assignee.id,
        role: 'MEMBER',
      },
    });
  }

  const ownerMembership = team.members.find((member) => member.role === 'OWNER');
  const creatorId = ownerMembership?.userId || assignee.id;
  const column = await prisma.column.findFirst({
    where: { projectId: project.id },
    orderBy: { position: 'asc' },
  });
  if (!column) throw new Error(`No Kanban column found for project ${project.id}`);

  const taskSpecs = [
    ['Finaliser les tests du calendrier', 'Tester les conflits, la charge quotidienne et l\'export ICS.', '2026-12-01T12:00:00.000Z', 'URGENTE'],
    ['Préparer la démonstration IA', 'Tester les ajouts en langage naturel avec Gemini et les cas limites.', '2026-12-04T12:00:00.000Z', 'HAUTE'],
    ['Rédiger le rapport final', 'Synthétiser les fonctionnalités, les choix techniques et les limites.', '2026-12-08T12:00:00.000Z', 'HAUTE'],
    ['Vérifier les notifications e-mail', 'Valider les rappels d\'échéance, le résumé hebdomadaire et les erreurs SMTP.', '2026-12-12T12:00:00.000Z', 'NORMALE'],
    ['Optimiser l\'interface mobile', 'Corriger les espacements, la navigation et les écrans étroits.', '2026-12-15T12:00:00.000Z', 'NORMALE'],
  ];

  const createdTasks = [];
  for (let i = 0; i < taskSpecs.length; i++) {
    const [title, description, dueAt, priority] = taskSpecs[i];
    const task = await prisma.task.create({
      data: {
        projectId: project.id,
        columnId: column.id,
        title,
        description,
        position: 10000 + i * 1000,
        priority,
        dueDate: new Date(dueAt),
        createdById: creatorId,
        assignees: {
          create: [{ userId: assignee.id }],
        },
        subtasks: {
          create: [
            { title: 'Préparer les données de test', position: 1 },
            { title: 'Effectuer les vérifications', position: 2 },
            { title: 'Documenter le résultat', position: 3 },
          ],
        },
      },
    });
    createdTasks.push(task);
  }

  const milestoneSpecs = [
    ['Fin de la phase IA', '2026-11-27T12:00:00.000Z', 'Finalisation du chatbot, des assistants IA et du langage naturel.'],
    ['Gel des fonctionnalités', '2026-12-10T12:00:00.000Z', 'Toutes les fonctionnalités principales doivent être disponibles.'],
    ['Soutenance du projet', '2026-12-18T12:00:00.000Z', 'Préparation puis présentation finale de StudyFlow.'],
  ];

  const createdMilestones = [];
  for (const [title, date, description] of milestoneSpecs) {
    const milestone = await prisma.milestone.create({
      data: {
        projectId: project.id,
        title,
        date: new Date(date),
        description,
      },
    });
    createdMilestones.push(milestone);
  }

  console.log(JSON.stringify({
    team: team.name,
    inviteToken: team.inviteToken,
    project: project.name,
    assignee: assigneeEmail,
    tasksCreated: createdTasks.length,
    milestonesCreated: createdMilestones.length,
  }, null, 2));
  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
