import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/main.dart';

void main() {
  testWidgets('renders the StudyFlow dashboard', (tester) async {
    await tester.pumpWidget(const StudyFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('StudyFlow'), findsOneWidget);
    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Active projects'), findsOneWidget);
  });

  testWidgets('opens a module from the navigation rail', (tester) async {
    await tester.pumpWidget(const StudyFlowApp());

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks workspace'), findsOneWidget);
    expect(
      find.text('Manage tasks in one collaborative workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('creates a project from the dashboard', (tester) async {
    await tester.pumpWidget(const StudyFlowApp());

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Research planner');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Research planner'), findsOneWidget);
  });
}
