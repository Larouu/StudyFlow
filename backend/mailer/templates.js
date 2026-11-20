// Gabarits d'e-mails StudyFlow (FR). Chaque gabarit renvoie { subject, html, text }.
const esc = (v) =>
  String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const fmtDate = (d) =>
  d ? new Date(d).toLocaleString('fr-FR', { dateStyle: 'full', timeStyle: 'short', timeZone: process.env.APP_TIMEZONE || 'Africa/Tunis' }) : '—';

function layout(title, bodyHtml) {
  return `<!doctype html><html><body style="margin:0;background:#f4f4f8;font-family:Arial,Helvetica,sans-serif;color:#1f2937">
  <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 12px">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;background:#fff;border-radius:12px;overflow:hidden">
      <tr><td style="background:#4f46e5;color:#fff;padding:18px 24px;font-size:20px;font-weight:bold">StudyFlow</td></tr>
      <tr><td style="padding:24px"><h2 style="margin:0 0 12px;font-size:18px">${esc(title)}</h2>${bodyHtml}</td></tr>
      <tr><td style="padding:14px 24px;font-size:12px;color:#6b7280;background:#fafafa">
        Vous recevez cet e-mail car vous utilisez StudyFlow. Ne répondez pas à ce message.</td></tr>
    </table></td></tr></table></body></html>`;
}

const p = (s) => `<p style="margin:0 0 12px;line-height:1.5">${s}</p>`;
const button = (url, label) =>
  url ? `<p><a href="${esc(url)}" style="display:inline-block;background:#4f46e5;color:#fff;padding:10px 18px;border-radius:8px;text-decoration:none">${esc(label)}</a></p>` : '';

const templates = {
  welcome: ({ name }) => ({
    subject: 'Bienvenue sur StudyFlow 👋',
    html: layout(`Bienvenue, ${name} !`, p('Votre compte est créé. Un espace « Mon Projet » avec un tableau Kanban vous attend.') + p('Besoin d’aide ? L’assistant intégré à l’application répond à vos questions.')),
    text: `Bienvenue ${name} ! Votre compte StudyFlow est créé.`,
  }),

  taskAssigned: ({ name, taskTitle, projectName, assignedBy, dueDate, priority }) => ({
    subject: `Nouvelle tâche : ${taskTitle}`,
    html: layout('Une tâche vous a été assignée', p(`Bonjour ${esc(name)},`) + p(`<b>${esc(assignedBy)}</b> vous a assigné <b>${esc(taskTitle)}</b>${projectName ? ` dans <i>${esc(projectName)}</i>` : ''}.`) + p(`Priorité : ${esc(priority || 'NORMALE')}<br>Échéance : ${esc(fmtDate(dueDate))}`)),
    text: `${assignedBy} vous a assigné la tâche « ${taskTitle} ». Échéance : ${fmtDate(dueDate)}.`,
  }),

  taskDueSoon: ({ name, taskTitle, dueDate }) => ({
    subject: `Échéance dans moins de 24 h : ${taskTitle}`,
    html: layout('Échéance proche ⏰', p(`Bonjour ${esc(name)},`) + p(`La tâche <b>${esc(taskTitle)}</b> arrive à échéance le <b>${esc(fmtDate(dueDate))}</b>.`)),
    text: `La tâche « ${taskTitle} » arrive à échéance le ${fmtDate(dueDate)}.`,
  }),

  taskOverdue: ({ name, taskTitle, dueDate }) => ({
    subject: `En retard : ${taskTitle}`,
    html: layout('Tâche en retard', p(`Bonjour ${esc(name)},`) + p(`La tâche <b>${esc(taskTitle)}</b> devait être terminée le ${esc(fmtDate(dueDate))}.`)),
    text: `La tâche « ${taskTitle} » est en retard (échéance : ${fmtDate(dueDate)}).`,
  }),

  addedToTeam: ({ name, teamName, role, invitedBy }) => ({
    subject: `Vous avez rejoint l’équipe ${teamName}`,
    html: layout('Nouvelle équipe', p(`Bonjour ${esc(name)},`) + p(`${invitedBy ? `<b>${esc(invitedBy)}</b> vous a ajouté` : 'Vous avez été ajouté'} à l’équipe <b>${esc(teamName)}</b> avec le rôle <b>${esc(role)}</b>.`)),
    text: `Vous avez rejoint l’équipe ${teamName} (rôle : ${role}).`,
  }),

  memberJoined: ({ name, memberName, teamName }) => ({
    subject: `${memberName} a rejoint ${teamName}`,
    html: layout('Nouveau membre', p(`Bonjour ${esc(name)},`) + p(`<b>${esc(memberName)}</b> a rejoint votre équipe <b>${esc(teamName)}</b> avec le code d’invitation.`)),
    text: `${memberName} a rejoint l’équipe ${teamName}.`,
  }),

  trainingEnrolled: ({ name, title, startsAt, mode, location, meetingUrl }) => ({
    subject: `Inscription confirmée : ${title}`,
    html: layout('Inscription confirmée ✅', p(`Bonjour ${esc(name)},`) + p(`Vous êtes inscrit(e) à <b>${esc(title)}</b>.`) + p(`Date : ${esc(fmtDate(startsAt))}<br>${mode === 'ONLINE' ? 'En ligne' : `Lieu : ${esc(location || 'à préciser')}`}`) + button(meetingUrl, 'Rejoindre la session')),
    text: `Inscription confirmée à « ${title} » le ${fmtDate(startsAt)}.${meetingUrl ? ' Lien : ' + meetingUrl : ''}`,
  }),

  coachingRequested: ({ name, coacheeName, topic }) => ({
    subject: `Demande de coaching de ${coacheeName}`,
    html: layout('Nouvelle demande de coaching', p(`Bonjour ${esc(name)},`) + p(`<b>${esc(coacheeName)}</b> demande une séance sur : <i>${esc(topic)}</i>. Confirmez un créneau dans l’application.`)),
    text: `${coacheeName} demande une séance de coaching : ${topic}.`,
  }),

  coachingConfirmed: ({ name, coachName, topic, scheduledAt, meetingUrl }) => ({
    subject: `Séance de coaching confirmée`,
    html: layout('Séance confirmée 📅', p(`Bonjour ${esc(name)},`) + p(`${esc(coachName)} a confirmé votre séance « ${esc(topic)} » le <b>${esc(fmtDate(scheduledAt))}</b>.`) + button(meetingUrl, 'Rejoindre la visio')),
    text: `Séance « ${topic} » confirmée le ${fmtDate(scheduledAt)}. ${meetingUrl || ''}`,
  }),

  weeklySummary: ({ name, projectName, period, taskCount, overdueCount, milestoneCount, upcoming }) => ({
    subject: `Résumé hebdomadaire - ${projectName}`,
    html: layout('Votre résumé hebdomadaire', p(`Bonjour ${esc(name)},`) + p(`Voici l’activité prévue pour <b>${esc(projectName)}</b> du ${esc(period)}.`) + p(`<b>${taskCount}</b> échéance(s) de tâches · <b>${overdueCount}</b> tâche(s) en retard · <b>${milestoneCount}</b> jalon(s).`) + p(upcoming ? `<b>À venir :</b><br>${esc(upcoming).replace(/\n/g, '<br>')}` : 'Aucun événement majeur prévu cette semaine.')),
    text: `Résumé hebdomadaire ${projectName} (${period}) : ${taskCount} tâches, ${overdueCount} en retard, ${milestoneCount} jalons.\n${upcoming || ''}`,
  }),
};

module.exports = templates;
