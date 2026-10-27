import 'dart:math';
import '../models/brain_gym_models.dart';

class BrainGymGenerator {
  static final Random _defaultRng = Random();

  /// Generates rapid-fire mental math problems adapted to difficulty level (1 to 5)
  static BrainQuestion generateMathQuestion({int difficulty = 1, Random? rng}) {
    final r = rng ?? _defaultRng;
    final level = difficulty.clamp(1, 5);

    switch (level) {
      case 1:
        // Basic single-digit +/-
        final isAdd = r.nextBool();
        final a = r.nextInt(15) + 3;
        final b = r.nextInt(12) + 2;
        if (isAdd) {
          return BrainQuestion(
            prompt: '$a + $b = ?',
            answer: '${a + b}',
            difficulty: 1,
          );
        } else {
          final maxVal = max(a, b);
          final minVal = min(a, b);
          return BrainQuestion(
            prompt: '$maxVal - $minVal = ?',
            answer: '${maxVal - minVal}',
            difficulty: 1,
          );
        }

      case 2:
        // 2-digit +/- or simple multiplication
        final op = r.nextInt(3);
        if (op == 0) {
          final a = r.nextInt(50) + 12;
          final b = r.nextInt(40) + 9;
          return BrainQuestion(prompt: '$a + $b = ?', answer: '${a + b}', difficulty: 2);
        } else if (op == 1) {
          final a = r.nextInt(60) + 25;
          final b = r.nextInt(a - 5) + 3;
          return BrainQuestion(prompt: '$a - $b = ?', answer: '${a - b}', difficulty: 2);
        } else {
          final a = r.nextInt(8) + 2;
          final b = r.nextInt(8) + 2;
          return BrainQuestion(prompt: '$a × $b = ?', answer: '${a * b}', difficulty: 2);
        }

      case 3:
        // Clean division or multiplication with double-digit
        final isDiv = r.nextBool();
        if (isDiv) {
          final divisor = r.nextInt(8) + 2;
          final quotient = r.nextInt(12) + 3;
          final dividend = divisor * quotient;
          return BrainQuestion(prompt: '$dividend ÷ $divisor = ?', answer: '$quotient', difficulty: 3);
        } else {
          final a = r.nextInt(11) + 4;
          final b = r.nextInt(8) + 4;
          return BrainQuestion(prompt: '$a × $b = ?', answer: '${a * b}', difficulty: 3);
        }

      case 4:
        // Missing operands or two-step operations
        final type = r.nextInt(3);
        if (type == 0) {
          final a = r.nextInt(9) + 3;
          final b = r.nextInt(8) + 3;
          final c = a * b;
          return BrainQuestion(prompt: '? × $b = $c', answer: '$a', difficulty: 4);
        } else if (type == 1) {
          final a = r.nextInt(8) + 3;
          final b = r.nextInt(6) + 2;
          final c = r.nextInt(15) + 2;
          final ans = (a * b) + c;
          return BrainQuestion(prompt: '$a × $b + $c = ?', answer: '$ans', difficulty: 4);
        } else {
          final a = r.nextInt(80) + 30;
          final b = r.nextInt(25) + 5;
          return BrainQuestion(prompt: '$a - ? = ${a - b}', answer: '$b', difficulty: 4);
        }

      case 5:
      default:
        // Complex chaining
        final a = r.nextInt(9) + 4;
        final b = r.nextInt(7) + 3;
        final c = r.nextInt(20) + 5;
        final ans = (a * b) - c;
        return BrainQuestion(prompt: '$a × $b - $c = ?', answer: '$ans', difficulty: 5);
    }
  }

  /// Generates number pattern recognition with 4 multiple-choice options
  static BrainQuestion generateSequenceQuestion({int difficulty = 1, Random? rng}) {
    final r = rng ?? _defaultRng;
    final type = r.nextInt(5);

    late List<int> seq;
    late int answer;
    late String hint;

    switch (type) {
      case 0:
        // Arithmetic Progression (+d)
        final d = r.nextInt(7) + 2;
        final start = r.nextInt(20) + 1;
        seq = [start, start + d, start + 2 * d, start + 3 * d];
        answer = start + 4 * d;
        hint = 'Add $d each time';
        break;

      case 1:
        // Geometric (*2 or *3)
        final mult = r.nextBool() ? 2 : 3;
        final start = r.nextInt(4) + 1;
        seq = [start, start * mult, start * mult * mult, start * mult * mult * mult];
        answer = seq.last * mult;
        hint = 'Multiply by $mult each time';
        break;

      case 2:
        // Alternating (+a, -b)
        final a = r.nextInt(5) + 4;
        final b = r.nextInt(3) + 1;
        final start = r.nextInt(15) + 10;
        seq = [start, start + a, start + a - b, start + 2 * a - b];
        answer = seq.last - b;
        hint = 'Alternate +$a then -$b';
        break;

      case 3:
        // Squares sequence
        final startN = r.nextInt(4) + 1;
        seq = [startN * startN, (startN + 1) * (startN + 1), (startN + 2) * (startN + 2), (startN + 3) * (startN + 3)];
        answer = (startN + 4) * (startN + 4);
        hint = 'Consecutive square numbers';
        break;

      case 4:
      default:
        // Fibonacci-style additive
        final a = r.nextInt(4) + 1;
        final b = r.nextInt(4) + a;
        final c = a + b;
        final d = b + c;
        seq = [a, b, c, d];
        answer = c + d;
        hint = 'Each number is the sum of previous two';
        break;
    }

    final prompt = '${seq.join(", ")}, ?';
    final options = _generateDistractors(answer, r);

    return BrainQuestion(
      prompt: prompt,
      answer: '$answer',
      options: options,
      hint: hint,
      difficulty: difficulty,
    );
  }

  /// Generates visual and symbolic pattern logic puzzles
  static BrainQuestion generateLogicQuestion({int difficulty = 1, Random? rng}) {
    final r = rng ?? _defaultRng;
    final variant = r.nextInt(4);

    if (variant == 0) {
      // Numerical Analogy: A : A^2 :: B : ?
      final base = r.nextInt(6) + 3;
      final square = base * base;
      final target = r.nextInt(6) + 3;
      final ans = target * target;
      final options = _generateDistractors(ans, r);
      return BrainQuestion(
        prompt: '$base : $square :: $target : ?',
        answer: '$ans',
        options: options,
        hint: 'Square relation',
        difficulty: difficulty,
      );
    } else if (variant == 1) {
      // Odd one out: Prime vs Composite
      final primes = [11, 13, 17, 19, 23, 29, 31, 37, 41, 43];
      final composites = [15, 21, 25, 27, 33, 35, 39, 49];
      primes.shuffle(r);
      composites.shuffle(r);

      final p1 = primes[0];
      final p2 = primes[1];
      final p3 = primes[2];
      final c1 = composites[0];

      final choices = [p1, p2, p3, c1]..shuffle(r);
      return BrainQuestion(
        prompt: 'Spot the odd one out:',
        answer: '$c1',
        options: choices.map((e) => '$e').toList(),
        hint: '$c1 is composite; others are prime numbers',
        difficulty: difficulty,
      );
    } else if (variant == 2) {
      // Alphabet progression: A, C, F, J, ? (+2, +3, +4, +5)
      const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final startIdx = r.nextInt(3);
      final c1 = alphabet[startIdx];
      final c2 = alphabet[startIdx + 2];
      final c3 = alphabet[startIdx + 5];
      final c4 = alphabet[startIdx + 9];
      final ans = alphabet[startIdx + 14];

      final dist1 = alphabet[(startIdx + 13) % 26];
      final dist2 = alphabet[(startIdx + 15) % 26];
      final dist3 = alphabet[(startIdx + 16) % 26];
      final options = [ans, dist1, dist2, dist3]..shuffle(r);

      return BrainQuestion(
        prompt: '$c1, $c2, $c3, $c4, ?',
        answer: ans,
        options: options,
        hint: 'Step increases: +2, +3, +4, +5 letters',
        difficulty: difficulty,
      );
    } else {
      // Geometric / Word Analogies
      final analogies = [
        {'prompt': 'Circle : Sphere :: Square : ?', 'ans': 'Cube', 'dist': ['Pyramid', 'Cylinder', 'Prism']},
        {'prompt': 'Second : Minute :: Day : ?', 'ans': 'Week', 'dist': ['Hour', 'Month', 'Year']},
        {'prompt': 'Radius : Diameter :: Side : ?', 'ans': 'Perimeter', 'dist': ['Area', 'Volume', 'Angle']},
        {'prompt': 'Focus : Distraction :: Signal : ?', 'ans': 'Noise', 'dist': ['Static', 'Echo', 'Silence']},
      ];
      final chosen = analogies[r.nextInt(analogies.length)];
      final ans = chosen['ans'] as String;
      final dist = List<String>.from(chosen['dist'] as List);
      final options = [ans, ...dist]..shuffle(r);

      return BrainQuestion(
        prompt: chosen['prompt'] as String,
        answer: ans,
        options: options,
        difficulty: difficulty,
      );
    }
  }

  /// Generates spatial memory sequences for the 3x3 grid (indices 0..8)
  static List<int> generateMemorySequence({int length = 4, Random? rng}) {
    final r = rng ?? _defaultRng;
    final sequence = <int>[];
    int last = -1;

    for (int i = 0; i < length; i++) {
      int next;
      do {
        next = r.nextInt(9);
      } while (next == last && length > 1);
      sequence.add(next);
      last = next;
    }
    return sequence;
  }

  /// Generates the fixed daily challenge round (seeded by current calendar day)
  static List<BrainQuestion> generateDailyChallengeQuestions() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(seed);

    final questions = <BrainQuestion>[];
    // 5 mental math
    for (int i = 1; i <= 5; i++) {
      questions.add(generateMathQuestion(difficulty: (i ~/ 2) + 1, rng: rng));
    }
    // 3 number sequences
    for (int i = 0; i < 3; i++) {
      questions.add(generateSequenceQuestion(difficulty: 2, rng: rng));
    }
    // 2 logic analogies
    for (int i = 0; i < 2; i++) {
      questions.add(generateLogicQuestion(difficulty: 2, rng: rng));
    }
    return questions;
  }

  static List<String> _generateDistractors(int answer, Random r) {
    final set = <int>{answer};
    while (set.length < 4) {
      final delta = (r.nextInt(7) + 1) * (r.nextBool() ? 1 : -1);
      final candidate = answer + delta;
      if (candidate >= 0 && candidate != answer) {
        set.add(candidate);
      }
    }
    final list = set.map((e) => '$e').toList()..shuffle(r);
    return list;
  }
}

