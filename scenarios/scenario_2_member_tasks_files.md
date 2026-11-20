# Scénario 2 — Member : Exécution des tâches, Découpage IA & Stockage de fichiers

**Persona :** Sami Youssef (`MEMBER`)  
**Identifiants :** `sami.youssef@univ-etudiant.fr` / `Member2026!`  
**Objectif :** Démontrer le travail quotidien d'un membre : filtrage et découpage IA des tâches, déplacement Kanban, chat d'équipe et cycle complet de stockage de fichiers.

---

## Étapes de démonstration

1. **Gestion avancée des tâches (`Tâches`)**
   - Se connecter avec le compte `MEMBER` de Sami Youssef.
   - Utiliser les compteurs (**Total / En retard / Terminées**), la barre de recherche, le filtre par priorité (`URGENTE`, `HAUTE`, etc.) et le tri (**Échéance / Priorité / Titre**).
   - Cliquer sur **Tâche IA** dans la barre d'outils pour créer une tâche structurée avec sous-tâches à partir d'une phrase.
   - Déplier une tâche existante et cliquer sur **Découper avec IA** : vérifier que 3 à 5 sous-tâches concrètes sont générées et enregistrées dans SQLite, puis en cocher une.

2. **Collaboration dans le Chat (`Chat`)**
   - Envoyer un message contenant un verbe d'action (ex. `Vérifier les maquettes avant demain soir`).
   - Ouvrir **Assistant IA du chat** pour obtenir le résumé du canal et l'extraction des actions potentielles.

3. **Cycle complet du Stockage de fichiers (`Fichiers`)**
   - Créer une note stockée via le bouton **Note** (ex. `compte-rendu.md`) et/ou téléverser un fichier local via **Téléverser**.
   - Filtrer la liste avec la recherche et les puces (**Tous / Documents / Images / Tableurs / Autres**), et vérifier l'indicateur d'espace utilisé.
   - Ouvrir l'aperçu d'un fichier (image zoomable ou texte/Markdown), copier son lien et cliquer sur **Télécharger** (`GET /api/mobile/files/:id`).
   - Utiliser le menu du fichier (`⋮`) pour **Renommer**, téléverser une **Nouvelle version** (`UPLOAD_FILE_VERSION`) ou **Supprimer**.
   - Ouvrir **Assistant IA des fichiers** pour vérifier la répartition des types et la détection des doublons.

4. **Restriction de rôle `MEMBER`**
   - Dans l'onglet **Équipes**, vérifier qu'un `MEMBER` ne peut pas inviter de nouveaux membres ni supprimer de projet (`OWNER` uniquement).

## Critères de réussite
- Les fichiers téléversés et versionnés sont bien servis par `/api/mobile/files/:id` et supprimés proprement du disque (`backend/uploads/`) lors de `DELETE_FILE`.
- Les sous-tâches IA persistent et mettent à jour la progression de la tâche.
