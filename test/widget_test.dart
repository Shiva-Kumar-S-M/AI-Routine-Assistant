import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AIRoutineAssistantApp());
    expect(find.byType(AIRoutineAssistantApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Screen overflow audit at 360dp width and 1.3x font scale', (WidgetTester tester) async {
    bool hasOverflow = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed')) {
        hasOverflow = true;
        debugPrint('FLUTTER OVERFLOW DETECTED: ${details.toString()}');
      }
    };

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const AIRoutineAssistantApp());
    await tester.pump(const Duration(seconds: 3));
    expect(hasOverflow, isFalse);
  });
}
