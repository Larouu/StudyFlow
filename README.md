# StudyFlow — Projet Autonome (Front-End Flutter & Back-End Node.js / Prisma)
## Matière : Développement Mobile (Flutter / Dart, Express REST API & Prisma SQLite)

Application collaborative de gestion de projets étudiants intégrant Kanban, tâches/sous-tâches, équipes, agenda & rapports, chat, stockage de fichiers versionné, formations/coaching et assistants IA.

---

## 📁 Structure du Projet

```text
StudyFlow/
├── backend/                     <- Serveur Back-End REST API (Node.js Express + Prisma SQLite)
│   ├── ai/
│   │   ├── index.js             <- Moteur d'insights IA hybride (heuristiques locales + Groq LLM)
│   │   └── generator.js         <- Génération IA (Kanban complet, colonnes, tâches, sous-tâches)
│   ├── assistant/
│   │   ├── index.js             <- Chatbot d'aide contextuel Groq + repli FAQ local
│   │   └── knowledge.js         <- Base de connaissances StudyFlow
│   ├── mailer/                  <- Templates e-mails SMTP & planificateur de rappels (H-24 / retard)
│   ├── prisma/
│   │   ├── schema.prisma        <- Schéma relationnel Prisma (SQLite)
│   │   ├── seed.ts              <- Jeu de données initial (équipes, projets, tâches, formations…)
│   │   └── dev.db               <- Base SQLite générée localement
│   ├── uploads/                 <- Stockage disque des fichiers téléversés et versionnés
│   ├── server.js                <- API REST (/api/mobile/*)
│   ├── package.json             <- Dépendances (express, cors, @prisma/client, nodemailer, dotenv)
│   └── .env                     <- Configuration locale (PORT, DATABASE_URL, GROQ_API_KEY, SMTP_*)
│
├── frontend/                    <- Application Front-End (Flutter & Dart)
│   ├── lib/
│   │   ├── core/                <- Modèles de domaine & contrats
│   │   ├── models/              <- Modèles typés (auth, kanban, calendar, communication, coaching)
│   │   ├── providers/           <- Stores réactifs par domaine (ChangeNotifier)
│   │   ├── repositories/        <- Couche d'accès aux données
│   │   ├── services/            <- Clients HTTP REST API (ai, assistant, auth, sync, etc.)
│   │   ├── screens/             <- Écrans (Connexion, Équipes, Kanban, Tâches, Agenda/Rapports, Chat/Fichiers, Coaching)
│   │   ├── widgets/             <- Composants réutilisables (AiInsightsPanel, AssistantSheet, logo)
│   │   └── main.dart            <- Point d'entrée Flutter
│   ├── test/                    <- Tests unitaires & widgets Flutter
│   └── pubspec.yaml             <- Dépendances Flutter (http, file_picker, url_launcher, cupertino_icons)
│
├── scenarios/                   <- Scénarios de démonstration et de soutenance
│   ├── scenario_1_owner_kanban_ai.md
│   ├── scenario_2_member_tasks_files.md
│   └── scenario_3_coach_training_security.md
├── reflection.md                <- Dossier de réflexion technique & justification des choix
└── README.md
```

---

## 🚀 Démarrage Rapide

### 1. Initialiser & démarrer le Back-End (Terminal 1)
```powershell
cd backend
npm install
npx prisma db push
npx tsx prisma/seed.ts
npm start
```
> Le serveur démarre sur **http://localhost:3000** avec la base SQLite `backend/prisma/dev.db`.

### 2. Démarrer le Front-End Flutter (Terminal 2)
```powershell
cd frontend
flutter pub get
flutter run -d chrome
```
> Sur Chrome (`kIsWeb`), l'application pointe automatiquement vers `http://localhost:3000` (et `http://10.0.2.2:3000` sur émulateur Android).

---

## 🔌 Principaux Endpoints REST

- `POST /api/mobile/auth` — Connexion, inscription et gestion de session.
- `GET /api/mobile/bootstrap` — Hydratation complète multi-modules en une requête.
- `POST /api/mobile/sync` — Synchronisation CRUD (projets, colonnes, tâches, sous-tâches, chat, fichiers `UPLOAD_FILE` / `UPLOAD_FILE_VERSION` / `RENAME_FILE` / `DELETE_FILE`, jalons, rapports, formations, coaching).
- `GET /api/mobile/files/:id` — Téléchargement ou prévisualisation inline des fichiers stockés.
- `GET /api/mobile/reports/:id` — Rendu HTML partageable d'un rapport de projet.
- `POST /api/mobile/ai` — Insights IA contextuels pour les 7 modules (`teams`, `kanban`, `tasks`, `calendar`, `chat`, `files`, `coaching`).
- `POST /api/mobile/ai/generate` — Génération et persistance IA (`AI_GENERATE_KANBAN`, `AI_GENERATE_TASK`, `AI_ADD_SUBTASKS`, `AI_GENERATE_COLUMNS`).
- `POST /api/mobile/assistant` & `GET /api/mobile/assistant/status` — Chatbot d'aide contextuel (Groq LLM + repli FAQ).

---

## 👥 Comptes de démonstration (Seed)

| Rôle | Nom | Email | Mot de passe |
| :--- | :--- | :--- | :--- |
| `OWNER` | Léa Martin | `lea.martin@univ-etudiant.fr` | `Owner2026!` |
| `OWNER` | Karim Belkacem | `karim.belkacem@univ-etudiant.fr` | `Owner2026!` |
| `MEMBER` | Sami Youssef | `sami.youssef@univ-etudiant.fr` | `Member2026!` |
| `MEMBER` | Chloé Dubois | `chloe.dubois@univ-etudiant.fr` | `Member2026!` |
| `COACH` | Mme Dupont | `helene.dupont@univ-prof.fr` | `Coach2026!` |

Code d'invitation équipe : `STUDY-S5-2026`

---

## 🎯 Scénarios de soutenance & évaluation

1. [Scénario 1 — Owner : Pilotage d'équipe & Génération IA Kanban](scenarios/scenario_1_owner_kanban_ai.md)
2. [Scénario 2 — Member : Exécution des tâches, Découpage IA & Stockage de fichiers](scenarios/scenario_2_member_tasks_files.md)
3. [Scénario 3 — Coach : Formations, Coaching Jitsi, Notes privées & Sécurité](scenarios/scenario_3_coach_training_security.md)
