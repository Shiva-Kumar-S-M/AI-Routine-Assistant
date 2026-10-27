import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/domain/services/productivity_score_calculator.dart';

void main() {
  group('ProductivityScoreCalculator Tests', () {
    test('Calculates score 50 for equal productive and distracting time', () {
      final score = ProductivityScoreCalculator.calculateScore(
        productiveSeconds: 1800,
        distractingSeconds: 1800,
      );
      expect(score, 50);
    });

    test('Clamps score between 0 and 100', () {
      final highDistractScore = ProductivityScoreCalculator.calculateScore(
        productiveSeconds: 0,
        distractingSeconds: 36000,
      );
      expect(highDistractScore, 0);

      final highProdScore = ProductivityScoreCalculator.calculateScore(
        productiveSeconds: 36000,
        distractingSeconds: 0,
      );
      expect(highProdScore, 100);
    });
  });
}
