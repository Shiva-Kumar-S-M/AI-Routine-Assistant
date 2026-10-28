import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/domain/services/brain_gym_generator.dart';

void main() {
  group('BrainGymGenerator Tests', () {
    test('Math generator produces valid non-negative questions across difficulties without division by zero', () {
      for (int diff = 1; diff <= 5; diff++) {
        for (int i = 0; i < 50; i++) {
          final q = BrainGymGenerator.generateMathQuestion(difficulty: diff);
          expect(q.prompt, isNotEmpty);
          expect(q.prompt, contains('='));
          expect(q.answer, isNotEmpty);

          // Verify answer is a valid integer
          final intVal = int.tryParse(q.answer);
          expect(intVal, isNotNull, reason: 'Answer must be a valid integer: ${q.answer}');
          // Must not be negative because numpad only has digits 0-9
          expect(intVal! >= 0, isTrue, reason: 'Answer must not be negative on numpad: ${q.answer} for prompt: ${q.prompt}');

          // Verify no division by zero in prompt
          if (q.prompt.contains('÷')) {
            expect(q.prompt, isNot(contains('÷ 0')));
          }
        }
      }
    });

    test('Number Sequence generator produces 4 valid options including the correct answer', () {
      for (int i = 0; i < 100; i++) {
        final q = BrainGymGenerator.generateSequenceQuestion(difficulty: (i % 5) + 1);
        expect(q.prompt, isNotEmpty);
        expect(q.prompt, contains('?'));
        expect(q.options.length, 4, reason: 'Must have exactly 4 multiple-choice options');
        expect(q.options, contains(q.answer), reason: 'Options must include the correct answer');

        for (final opt in q.options) {
          final intVal = int.tryParse(opt);
          expect(intVal, isNotNull, reason: 'Option must be an integer: $opt');
        }
      }
    });

    test('Odd One Out & Logic generator produces valid options with answer included', () {
      for (int i = 0; i < 100; i++) {
        final q = BrainGymGenerator.generateLogicQuestion(difficulty: (i % 3) + 1);
        expect(q.prompt, isNotEmpty);
        expect(q.answer, isNotEmpty);
        expect(q.options.length, greaterThanOrEqualTo(4));
        expect(q.options, contains(q.answer), reason: 'Options must contain the correct answer');
      }
    });

    test('Memory sequence produces correct length and valid tile indices (0-8)', () {
      for (int len = 3; len <= 8; len++) {
        final seq = BrainGymGenerator.generateMemorySequence(length: len);
        expect(seq.length, len);
        for (int i = 0; i < seq.length; i++) {
          expect(seq[i], inInclusiveRange(0, 8), reason: 'Tiles must be within 3x3 grid (0..8)');
          if (i > 0 && len > 1) {
            expect(seq[i] != seq[i - 1], isTrue, reason: 'No adjacent identical tiles in sequence');
          }
        }
      }
    });

    test('Daily challenge round produces 10 questions with valid prompts and answers', () {
      final round = BrainGymGenerator.generateDailyChallengeQuestions();
      expect(round.length, 10);
      for (final q in round) {
        expect(q.prompt, isNotEmpty);
        expect(q.answer, isNotEmpty);
      }
    });
  });
}

