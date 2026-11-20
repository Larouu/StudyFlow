// Base de connaissances de l'assistant. Adaptez les libellés aux noms exacts de vos écrans.
module.exports = `
StudyFlow est une application de gestion de projet collaborative pour équipes d'étudiants : Kanban, tâches, agenda, chat, fichiers, formations et coaching.

RÔLES (par équipe) : OWNER (propriétaire), MEMBER, COACH.
- OWNER : invite des membres (par e-mail d'un utilisateur déjà inscrit) et change les rôles.
- MEMBER : crée, modifie, déplace et supprime des tâches, discute, partage des fichiers.
- COACH : accès consacré aux formations qu'il dirige, aux inscriptions et aux outils de suivi ; pas d’édition du Kanban.
- Seul le coach voit ses notes privées de séance ; elles ne sont jamais visibles par le coaché.

KANBAN / TÂCHES
- Un projet a des colonnes (ex. À faire, En cours, Terminé). Une colonne peut avoir une limite WIP (nombre max de cartes en cours).
- Une tâche a : titre, description, priorité (BASSE, NORMALE, HAUTE, URGENTE), échéance, assignés, sous-tâches.
- Déplacer une carte dans une colonne « terminée » marque la tâche comme complétée.
- Le découpage IA propose des sous-tâches automatiquement à partir d'une tâche.

ÉQUIPES
- Rejoindre une équipe : saisir le code d'invitation (format SF-XXXXXX) fourni par le propriétaire.

AGENDA / RAPPORTS
- L'agenda affiche échéances et jalons. Des rapports de projet peuvent être générés pour une période.
- Des e-mails de rappel sont envoyés environ 24 h avant une échéance et en cas de retard.

CHAT & FICHIERS
- Chaque projet a un canal de discussion. Les messages peuvent être modifiés ou supprimés (modération par OWNER/COACH).
- Les fichiers sont versionnés par projet.

FORMATIONS & COACHING
- S'inscrire à une formation si la capacité n'est pas atteinte ; un e-mail de confirmation est envoyé.
- Demander une séance de coaching : choisir un coach, un sujet, jusqu'à 3 créneaux. Le coach confirme un créneau, un lien de visio est généré.
- Objectifs de coaching avec progression 0–100 % et niveaux de compétence 0–5.
`.trim();
