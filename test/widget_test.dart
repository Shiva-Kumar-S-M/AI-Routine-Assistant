import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AIRoutineAssistantApp());
    expect(find.byType(AIRoutineAssistantApp), findsOneWidget);
  });
}
