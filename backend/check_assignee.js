const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  const user = await prisma.user.findUnique({
    where: { email: 'achraflarousse52@gmail.com' },
    include: {
      teamMembers: {
        include: { team: { include: { projects: true } } },
      },
    },
  });
  console.log(JSON.stringify({
    found: Boolean(user),
    user: user ? { id: user.id, name: user.name, email: user.email } : null,
    memberships: user?.teamMembers.map((membership) => ({
      team: membership.team.name,
      inviteToken: membership.team.inviteToken,
      role: membership.role,
      projects: membership.team.projects.map((project) => project.name),
    })) || [],
  }, null, 2));
  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
