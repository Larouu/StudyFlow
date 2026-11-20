# Scénario 1 — Owner : Pilotage d'équipe, Génération IA Kanban & Rapports

**Persona :** Léa Martin (`OWNER`)  
**Identifiants :** `lea.martin@univ-etudiant.fr` / `Owner2026!`  
**Objectif :** Démontrer l'administration d'équipe, la création complète d'un tableau Kanban par l'IA, l'équilibrage de charge et le suivi KPI.

---

## Étapes de démonstration

1. **Connexion & Tableau d'équipe (`Équipes`)**
   - Se connecter avec le compte `OWNER` de Léa Martin.
   - Vérifier l'affichage du code d'invitation (`STUDY-S5-2026`), la liste des membres et la nouvelle carte **Charge de travail par membre** (tâches actives et retards par personne).
   - Ouvrir **Assistant IA équipe** (`AiInsightsPanel`), générer les insights et cliquer sur le bouton d'action d'une recommandation pour ouvrir le chatbot contextuel avec un prompt pré-rempli.

2. **Génération d'un Kanban complet par l'IA (`Kanban`)**
   - Dans la barre d'outils Kanban, cliquer sur **IA Générer → Générer un Kanban complet IA**.
   - Saisir un objectif, par exemple : `Application mobile de covoiturage étudiant avec authentification, carte et paiement`.
   - Cocher **Créer un nouveau projet dédié** (réservé au rôle `OWNER`) et valider.
   - Observer la création automatique en base SQLite des colonnes (avec limites WIP et colonne `isDone`), des tâches priorisées avec échéances et de leurs sous-tâches, ainsi que la mise à jour de la **barre d'avancement & santé WIP**.

3. **Ajout de colonnes IA & Création de tâche IA**
   - Cliquer sur **IA Générer → Générer des colonnes IA** avec le workflow `Revue de code et QA`.
   - Cliquer sur **IA Générer → Créer tâche + sous-tâches IA** pour générer une carte prête à l'emploi dans la colonne cible.

4. **Agenda & Rapports (`Agenda / Rapports`)**
   - Consulter le panneau **Assistant IA calendrier** et la carte **Échéances des 7 prochains jours**.
   - Générer un rapport de projet, copier ou ouvrir son URL (`/api/mobile/reports/:id`) et tester l'export CSV.

## Critères de réussite
- Le projet, les colonnes, les tâches et les sous-tâches générés par l'IA persistent après rechargement (`GET /api/mobile/bootstrap`).
- Les métriques de charge et de WIP se mettent à jour immédiatement.
