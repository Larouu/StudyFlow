const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');

const credentials = [
  ['lea.martin@univ-etudiant.fr', 'Owner2026!'],
  ['karim.belkacem@univ-etudiant.fr', 'Owner2026!'],
  ['sami.youssef@univ-etudiant.fr', 'Member2026!'],
  ['chloe.dubois@univ-etudiant.fr', 'Member2026!'],
  ['helene.dupont@univ-prof.fr', 'Coach2026!'],
];

async function main() {
  const prisma = new PrismaClient();
  for (const [email, password] of credentials) {
    const passwordHash = crypto.createHash('sha256').update(password).digest('hex');
    await prisma.user.updateMany({
      where: { email },
      data: { passwordHash },
    });
  }
  console.log(`${credentials.length} known account credentials configured.`);
  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
