# Scénario 3 — Coach : Formations, Coaching Jitsi, Notes privées & Sécurité

**Persona :** Mme Dupont (`COACH`)  
**Identifiants :** `helene.dupont@univ-prof.fr` / `Coach2026!`  
**Objectif :** Démontrer l'espace dédié Coach, la gestion des formations et séances de coaching avec lien Jitsi, la confidentialité des notes privées (§7.3) et les restrictions en lecture seule (§4.2).

---

## Étapes de démonstration

1. **Expérience dédiée & Sécurité en lecture seule (§4.2)**
   - Se connecter avec le compte `COACH` de Mme Dupont (`helene.dupont@univ-prof.fr`).
   - Constater l'accès direct à l'espace Formations & Coaching et le mode consultation seule sur le Kanban / les Tâches / les Fichiers (aucun bouton de création, déplacement ou suppression).
   - Vérifier côté API (`POST /api/mobile/sync` et `POST /api/mobile/ai/generate`) que toute tentative d'écriture par un `COACH` retourne `HTTP 403 Permission refusée`.

2. **Catalogue de Formations (`Formations`)**
   - Créer ou consulter une formation publiée (capacité, places restantes, mode en ligne/présentiel).
   - Vérifier la génération automatique du lien de visioconférence Jitsi pour les sessions en ligne.

3. **Séances de Coaching & Notes privées (§7.3)**
   - Consulter une séance demandée par un étudiant, confirmer l'un des créneaux proposés et vérifier la génération du lien Jitsi + notification e-mail.
   - Rédiger un **compte-rendu partagé** (visible par le coaché) et une **note privée de séance** (réservée au coach).
   - Se reconnecter brièvement en tant que `MEMBER` (Sami ou Léa) pour vérifier que la note privée du coach n'apparaît jamais dans son interface ni dans le contexte du chatbot d'aide (`/api/mobile/assistant`).

4. **Assistant IA formation & coaching**
   - Ouvrir **Assistant IA formation & coaching** pour analyser les écarts de compétences, la progression moyenne des objectifs et les recommandations Groq / locales.

## Critères de réussite
- Le rôle `COACH` ne peut modifier aucune tâche, colonne, projet ou fichier (protégé côté UI et backend).
- Les notes privées restent strictement invisibles aux autres utilisateurs et au chatbot IA.
