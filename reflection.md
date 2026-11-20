# StudyFlow - Technical Reflection

## 1. Project overview

StudyFlow is a mobile-first collaborative application for managing student projects,
tasks, deadlines, communication, files, coaching, and learning. The project combines
a Flutter frontend with a Node.js/Express and Prisma/SQLite backend. The application
is organized as seven functional modules, but it also includes cross-cutting services
for authentication, artificial intelligence, email notifications, and real-time-style
workspace synchronization.

The main objective was not only to reproduce an academic project-management interface,
but also to deliver a usable system in which permissions, project activity, deadlines,
team communication, and coaching are connected. The application can run locally while
keeping sensitive provider credentials on the backend.

## 2. Team contribution

### Mehdi - Authentication

Mehdi worked on authentication and account access. This part includes sign-up,
sign-in, password management, session loading, user profiles, logout, and protection
of authenticated actions. New accounts can join an existing team with an invitation
code or create a project and become its owner. Authentication was made independent
of the demo login interface, which now requires a real email and password.

### Oumaima - Projects, Kanban, columns, and teams

Oumaima worked on project and workspace organization. The application supports
multiple projects, project selection, project names and descriptions, project colors,
Kanban boards, configurable columns, column positions, and Kanban view navigation.
Team support includes team membership, invitation codes, owner management, and
workspace-level separation.

### Iheb - Tasks and subtasks

Iheb implemented the task experience. A task has a title, description, priority,
deadline, project, column, creator, assignees, labels, and subtasks. Tasks can be
created, edited, assigned, and deleted. Subtasks provide a smaller breakdown
of each task and contribute to completion indicators. Assignment changes and overdue
tasks are also connected to the notification system.

### Achref - Calendar, milestones, statistics, and reports

Achref created the calendar and reporting area. The agenda combines task deadlines,
milestones, formations, and coaching sessions into a single multi-source calendar.
Users can filter events by day and navigate between months.

The reports tab contains project-level KPIs: global progress, completed tasks,
overdue tasks, deadlines within seven days, subtasks completed, and active milestones.
It also presents task distribution by Kanban column and priority. The report period
can be limited to the complete project, the last seven days, or the last thirty days.
Generated reports are stored and listed in the application, and project metrics can
be exported as CSV text.

### Soulaima - Chat

Soulaima developed the team chat and notification experience. Chat channels are
associated with projects and teams. Users can send messages, edit their own messages,
and moderate or delete messages according to their role. The channel interface also
supports moderation and project-context filtering. Chat content is used locally by
the assistant to extract potential action items and summarize recent conversation,
without exposing private coaching information.

### Rihab - File storage, permissions, and sharing

Rihab handled file storage and access control. Files are uploaded to the backend,
associated with a project, and stored with file metadata and versions. The interface
supports upload, preview, download, sharing context, and deletion for authorized users.
Coach users are not allowed to modify project files or team work. Role checks are also
applied to team membership and invitation actions.

### Maysa - Coaching

Maysa worked on formations and coaching. The module includes training catalog entries,
skills, levels, capacity limits, online or on-site mode, and enrollment. Users can
request coaching sessions, propose dates, and receive confirmed appointments.
Coaches manage sessions, confirm slots, provide shared reports, and write private
coach-only notes. Coach accounts open directly in the coaching and formations workspace
without project navigation unrelated to their role.

### The whole team - Mail, chatbot, and AI

The complete team contributed to the cross-cutting AI and communication features.
The backend is responsible for credentials and context, while Flutter presents the
results and chat interface.

The application includes:

- A Groq-powered help assistant with a local FAQ fallback.
- An explainable local AI engine for every module.
- Automatic SMTP mail notifications.
- Scheduled deadline reminders.
- Automatic Jitsi meeting-room links for online formations and coaching.

## 3. Module reflection

### Authentication and teams

The authentication module establishes the identity and permissions used throughout the
app. A new user can create a project and become the owner, or join a team with an
invitation code and receive the member role.

The owner has team administration privileges: inviting users, removing members,
changing roles, creating projects, editing projects, and deleting projects. Members
work on projects but cannot invite users or change roles. Coaches access the formations
and coaching environment without project editing rights.

The role model was deliberately kept to three roles:

- `OWNER`: team and project administrator.
- `MEMBER`: full participation in projects within granted permissions.
- `COACH`: training and coaching access.

This removes ambiguous administration roles and makes permission checks easier to
validate on both frontend and backend.

### Projects and Kanban

The project module defines the workspace and links users, tasks, columns, channels,
files, milestones, reports, and coaching context. An owner can create and maintain
projects while members work inside their assigned projects.

The Kanban module is based on ordered columns with optional WIP limits. Members can
create cards, edit them, move them, and mark subtasks. Coaches remain in read-only
mode for project tasks. The AI bottleneck feature identifies columns that exceed their
WIP limit and explains why it considers a column overloaded.

### Tasks and subtasks

Tasks represent the operational unit of the project. They include priority, due date,
description, assigned members, and subtasks. Assignment is important because mail
notifications are sent to newly assigned users rather than the current actor.

Subtasks make large tasks easier to understand and allow progress to be measured in
detail. The task AI feature calculates overdue risk, active priorities, and whether
active tasks lack a proper breakdown.

### Calendar, milestones, and reports

The calendar consolidates deadlines and milestone dates and gives the team a useful
agenda. It supports event selection and includes formations and coaching sessions,
so a user can see more than project tasks alone.

The report module translates raw project data into progress indicators. The KPIs help
the team identify delays and measure completion. The priority chart reveals whether
urgent work is accumulating, while column distribution shows whether work is blocked
or concentrated in one stage.

CSV export allows the team to copy or use the same metrics outside the app. Reports
are snapshots with completion rate, task totals, completed totals, and creation date.

### Chat

The chat module gives project users a shared communication channel. Message editing
is limited to the author, while deletion moderation is controlled according to role.
This is important because chat is both a collaboration tool and a source of potentially
private user content.

The assistant inspects only recent conversation in the selected channel. It identifies
possible action phrases and produces a local summary. It does not execute changes or
invent tasks.

### Files and sharing

Files are uploaded through the backend (`UPLOAD_FILE`) and stored on disk in `backend/uploads/`
with relational metadata and `FileVersion` history in SQLite. The module supports uploading
real files, creating Markdown/text notes directly, uploading new versions (`UPLOAD_FILE_VERSION`),
renaming (`RENAME_FILE`), searching and filtering by category (Documents, Images, Spreadsheets,
Other), inline image/text preview, direct download (`GET /api/mobile/files/:id`), and deletion
for authorized users.

The file AI reports storage totals, MIME/type distribution, and duplicate-name warnings,
augmented by Groq strategic recommendations when an API key is configured. Uploading,
versioning, renaming, and deleting remain restricted to `OWNER` and `MEMBER` roles.

### Training and coaching

The training module supports multiple levels and participation capacity. Members can
enroll or leave formations. Coaches can create and edit sessions, manage attendance,
and view the coaching schedule.

The coaching module maintains sessions, proposed slots, confirmation state, scheduled
time, private coach notes, shared reports, goals, skill levels, and Jitsi meeting links.
Online meetings receive generated room URLs, which are stored in the backend and can be
copied or opened from the interface.

Coach accounts enter a dedicated experience focused on formations and coaching. They do
not see project management and team administration navigation.

## 4. Artificial intelligence

The project combines three complementary AI layers:

### Hybrid module insights (Local heuristics + Groq LLM)

Every module (`teams`, `kanban`, `tasks`, `calendar`, `chat`, `files`, `coaching`) exposes
real-time analytics via `POST /api/mobile/ai`:

- Kanban WIP bottlenecks and stalled cards (> 3 days without updates).
- Task overdue risk, priority load, and "Top 3" daily focus.
- Calendar deadline forecasts (72 h) and < 24 h milestone/deadline collisions.
- Chat summaries and action-item candidates.
- File storage totals, classifications, and duplicate-name warnings.
- Team workload imbalance and idle member detection.
- Coaching competency gaps, goal progress, and training recommendations.

Each insight carries a source (`local-heuristic` or `groq-llm`), confidence score, severity
badge, metric chips, and an interactive action button that opens the contextual assistant
with a pre-populated prompt. When `GROQ_API_KEY` is configured on the backend, Groq
synthesizes an additional module-specific strategic recommendation from the live metrics.

### Generative AI for Kanban, columns, tasks, and subtasks

Via `POST /api/mobile/ai/generate` (`backend/ai/generator.js`), authorized users (`OWNER`
and `MEMBER`, while `COACH` / `VIEWER` are blocked with HTTP 403) can generate and persist
structured workspace artifacts directly into SQLite:

- `AI_GENERATE_KANBAN`: creates a full Kanban board (columns with WIP limits, tasks,
  priorities, due dates, and subtasks) in the current or a new project.
- `AI_GENERATE_TASK`: creates a structured task with 3–5 subtasks from a natural-language prompt.
- `AI_ADD_SUBTASKS`: breaks down an existing task into 3–5 actionable subtasks.
- `AI_GENERATE_COLUMNS`: suggests and adds non-duplicate workflow columns to a project.

All four generators use Groq JSON-mode output with deterministic local template fallbacks.

### Contextual Groq help assistant

The help assistant (`POST /api/mobile/assistant`) is a conversational guide running on the
backend. It receives the current user's role, active screen module, projects and Kanban WIP
state, assigned tasks, upcoming milestones, recent files, trainings, coaching sessions,
skills, and goals, alongside the knowledge base (`backend/assistant/knowledge.js`), while
strictly excluding private coach notes and other users' private records. If no Groq key
is configured or the provider fails, it falls back to keyword-based FAQ responses.

## 5. Automatic mail notifications

The mailer runs on the backend using SMTP. It sends templates for:

- Welcome messages.
- New task assignment.
- Tasks approaching their deadline.
- Overdue tasks.
- Team membership changes.
- Training enrollment.
- Coaching requests.
- Confirmed coaching sessions.

A scheduler checks overdue and upcoming deadlines every configured interval. It records
reminder records so the same `H24` or `OVERDUE` reminder is not claimed repeatedly.
Mail failures are logged and do not break task or enrollment API requests.

SMTP and provider credentials remain in `.env` and must not be committed to Git.

## 6. Security and permissions

Sensitive operations are checked on the backend, not only in the interface:

- Coaches cannot modify tasks or files.
- Members cannot invite users or change roles.
- Only owners can assign the owner role and administer project ownership.
- Private coaching notes are returned only to the coach author.
- Assistant context excludes private coach notes and unrelated private records.
- Mail credentials and Groq credentials are never sent to Flutter.

The first owner role of a team is assigned at project creation or transfer. Team
members do not automatically receive owner privileges.

## 7. Technical choices

Flutter was selected for a responsive cross-platform interface. Material 3 cards,
tabs, navigation rails, bottom navigation, progress indicators, and dialogs provide
a consistent desktop and mobile experience.

Express keeps HTTP endpoints easy to understand and separates authentication,
workspace bootstrap, synchronization, AI, mail, and assistant concerns. Prisma with
SQLite provides relational data and local persistence without an external database
installation.

Rule-based AI was prioritized before generative AI because it is fast, explainable,
deterministic, and useful offline. Groq was used for conversational assistance only,
because conversational generation is better suited to language than deterministic
deadline or workload calculations.

Jitsi was used for meeting rooms because it does not require a proprietary account
for a basic public room. The backend generates a persistent room URL from the
training or coaching identifier. Confirmed coaching sessions are sent to participants
by email with the meeting link.

## 8. Challenges and solutions

The first challenge was consistency across multiple modules. A shared store and
backend bootstrap endpoint were used to keep projects, tasks, deadlines, users, files,
trainings, and coaching synchronized.

A second challenge was role security. UI restrictions alone are insufficient. Every
sensitive synchronization action is checked against the current team membership role
on the backend.

A third challenge was keeping AI useful without API credentials. The team implemented
deterministic heuristics before provider integration, giving the app a usable fallback.
The Groq assistant similarly falls back to FAQ responses when unavailable.

A fourth challenge was private coaching data. Private notes are separated from shared
reports and filtered when serialized. A coach can see their own private notes; a member
sees only the shared coaching report.

A fifth challenge was mail delivery reliability. Mail is asynchronous and failures do
not invalidate successful application operations. Deadline reminders use database
records as claims to prevent repeated sends.

## 9. Improvements for future work

Several improvements would be useful for a production release:

- Replace password SHA-256 storage with Argon2 or bcrypt.
- Add refresh tokens and secure session cookies.
- Add real-time WebSocket chat and typing indicators.
- Add OCR and semantic search for uploaded documents.
- Add role-based project member assignments.
- Store report snapshots with richer historical datasets.
- Add chart export as PDF or PNG.
- Add private provider observability and usage limits.
- Add end-to-end encryption for sensitive coach notes.
- Add an administrator audit log.
- Validate Groq responses and track model versions.
- Add server-side tests for every permission branch.
- Add automated Flutter widget tests for each role experience.

## 10. Conclusion

StudyFlow evolved from a set of separate modules into a connected collaboration
platform. Authentication identifies users, projects organize work, Kanban and tasks
track execution, calendar and reports explain progress, chat communicates decisions,
files retain project knowledge, and coaching develops team skills.

The team-based integration of mail, AI, and meeting tools provides useful automation
without replacing human decisions. The owner retains team control, members contribute
to projects, and coaches operate in a dedicated learning environment. This architecture
is designed to remain understandable, testable, and extendable for future development.
