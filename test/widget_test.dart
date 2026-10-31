import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/main.dart';

void main() {
  testWidgets('renders the StudyFlow dashboard', (tester) async {
    await tester.pumpWidget(const StudyFlowApp());

    expect(find.text('StudyFlow'), findsOneWidget);
    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Active projects'), findsOneWidget);
    expect(find.text('Upcoming deadlines'), findsOneWidget);
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
}
