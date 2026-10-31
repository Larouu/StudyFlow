# StudyFlow architecture

StudyFlow is a Flutter application targeting web first and keeping the client
portable to Android and iOS. The UI is feature-oriented and uses an explicit
domain boundary so Firebase repositories can be introduced without coupling
widgets to Firestore.

## Layers

- `lib/app`: application composition, theme, and navigation.
- `lib/core`: cross-cutting errors, services, AI contracts, and shared widgets.
- `lib/features`: one folder per module (M1-M7), each split into `data`,
  `domain`, and `presentation`.
- `functions`: trusted server-side work such as notifications, report
  aggregation, and AI requests.

The current web shell is a usable local preview. It deliberately does not
pretend that Firebase is configured: the generated `firebase_options.dart`
must come from `flutterfire configure` against project `studyflow-c9fba`.

## Module boundaries

1. Authentication and teams
2. Projects and Kanban
3. Tasks and assignments
4. Calendar, deadlines, reports, and statistics
5. Chat and notifications
6. File management and sharing
7. Training, coaching, and skills

Each repository must enforce team/project membership in addition to the
Firestore and Storage rules. The client never makes authorization decisions.
