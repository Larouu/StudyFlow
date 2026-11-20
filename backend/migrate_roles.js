const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  const admins = await prisma.teamMember.updateMany({
    where: { role: 'ADMIN' },
    data: { role: 'OWNER' },
  });
  const viewers = await prisma.teamMember.updateMany({
    where: { role: 'VIEWER' },
    data: { role: 'MEMBER' },
  });
  console.log(JSON.stringify({
    adminsMigratedToOwner: admins.count,
    viewersMigratedToMember: viewers.count,
  }));
  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
