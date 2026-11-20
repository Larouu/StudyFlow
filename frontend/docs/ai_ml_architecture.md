# AI and ML architecture

AI capabilities are server-mediated and opt-in. The Flutter client calls typed
use cases rather than a model provider directly. The shared result contract is
`AiRecommendation` in `lib/core/domain/studyflow_contracts.dart`; it carries
the explanation, confidence, provenance, timestamp, and whether the result is a
prediction.

## Capability matrix

Every module exposes a deterministic local capability first. These capabilities
are useful without credentials and define the input/output contract that a
future statistical or generative provider must preserve.

| Module | Local capability | Evidence used |
| --- | --- | --- |
| Authentication & teams | unusual sign-in/team activity signal | authenticated activity timestamps and membership changes |
| Projects & Kanban | bottleneck and project-template suggestions | column WIP limits, task counts, and project metadata |
| Tasks & assignments | priority, assignee, and overdue-risk suggestions | priority, due dates, status, subtasks, and assignment load |
| Calendar & reports | deadline risk and schedule-conflict suggestions | due dates, milestones, event intervals, and completion rates |
| Chat & notifications | action-item extraction and thread summary | message text in the selected channel only |
| Files & sharing | metadata classification and duplicate-name warnings | file names, MIME types, versions, and project membership |
| Training & coaching | competency gaps and next-learning suggestions | declared skills, progress, goals, and completed training |

## Execution boundary

The backend owns capability discovery, authorization, feature flags, and
inference. A future endpoint can use:

```text
GET  /api/mobile/ai/capabilities
POST /api/mobile/ai/{module}/{capability}
```

The request includes the authenticated user and a small, module-specific
input DTO. The response is either an `AiRecommendation` list or an explicit
degraded/error result; it never silently returns an empty success response.
Local heuristics remain the fallback when a provider is disabled or
unavailable.

## Local heuristic rules

Local inference must be deterministic, bounded, and explainable:

- derive scores only from fields already authorized for the current team;
- clamp confidence to `[0, 1]` and include the evidence in `explanation`;
- do not inspect private notes, unrelated channels, or unshared files;
- never mutate tasks, dates, assignments, or learning records automatically;
- return `source: local-heuristic` and `isPrediction: true` for risk estimates;
- include a generated timestamp so stale recommendations can be refreshed.

Provider-backed models can later implement the same capability DTOs. Provider
credentials, prompt/model versions, redaction, rate limits, and audit records
stay on the server. No provider dependency is required for local development.

## Rollout

1. Implement the shared capability DTOs and local calendar heuristics.
2. Add the calendar recommendation card with evidence and refresh state.
3. Reuse the same adapter for task, Kanban, coaching, chat/files, teams, and
   authentication capabilities.
4. Add provider adapters only after local behavior and authorization tests are
   stable.
