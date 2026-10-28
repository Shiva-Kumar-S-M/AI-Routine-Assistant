import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/presentation/screens/brain_gym/brain_gym_hub_screen.dart';

void main() {
  testWidgets('BrainGymHubScreen renders complete UI immediately and is never blank', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BrainGymHubScreen(),
    ));

    // The screen must NOT be blank on frame 1 - AppBar is visible
    expect(find.text('BRAIN GYM'), findsOneWidget);

    // Rating card
    expect(find.text('1000 ELO'), findsOneWidget);
    expect(find.text('NOVICE MIND'), findsOneWidget);

    // Daily Challenge card
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);
    expect(find.text('Mixed Workout Blitz'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    // All 4 Training modes
    expect(find.text('Math Sprint'), findsOneWidget);
    expect(find.text('Number Sequence'), findsOneWidget);
    expect(find.text('Memory Flash'), findsOneWidget);
    expect(find.text('Odd One Out'), findsOneWidget);

    // Scroll down to verify the leaderboard section
    final leaderboardFinder = find.text('LOCAL LEADERBOARD & RECENT SESSIONS');
    await tester.scrollUntilVisible(leaderboardFinder, 200.0);
    expect(leaderboardFinder, findsOneWidget);

    // No CircularProgressIndicator blocking the screen
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
