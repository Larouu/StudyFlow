// Envoi d'e-mails via SMTP (nodemailer). Sans SMTP_HOST : mode "dry-run" (log console).
const nodemailer = require('nodemailer');
const templates = require('./templates');

let transporter;
function getTransporter() {
  if (transporter !== undefined) return transporter;
  if (!process.env.SMTP_HOST) {
    transporter = null;
    return transporter;
  }
  const port = Number(process.env.SMTP_PORT || 587);
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
  });
  return transporter;
}

async function sendMail({ to, subject, html, text }) {
  const from = process.env.MAIL_FROM || 'StudyFlow <no-reply@studyflow.local>';
  const t = getTransporter();
  if (!t) {
    console.log(`[mail:dry-run] → ${to} | ${subject}`);
    return { dryRun: true };
  }
  return t.sendMail({ from, to, subject, html, text });
}

/**
 * Envoie un gabarit à un utilisateur. Ne lève jamais d'exception :
 * un échec d'e-mail ne doit pas casser la requête API.
 * Utilisation : mailer.queue(prisma, userId, 'taskAssigned', { ... })
 */
function queue(prisma, userId, templateName, data = {}) {
  return (async () => {
    try {
      if (process.env.MAIL_ENABLED === 'false') return;
      const build = templates[templateName];
      if (!build) throw new Error(`Gabarit inconnu : ${templateName}`);
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user || !user.email) return;
      const mail = build({ name: user.name, ...data });
      await sendMail({ to: user.email, ...mail });
    } catch (err) {
      console.error(`[mail] échec (${templateName}):`, err.message);
    }
  })();
}

module.exports = { queue, sendMail };
