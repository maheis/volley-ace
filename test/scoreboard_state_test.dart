import 'package:flutter_test/flutter_test.dart';
import 'package:volleyace/src/scoreboard/scoreboard_state.dart';

void main() {
  for (final leftWon in [true, false]) {
    test(
        'completing a set resets points, timeouts and stopwatch; '
        'leftWon=$leftWon', () {
      final wonAt = DateTime(2026, 10, 26, 12);
      final stopwatchAt = const Duration(minutes: 8, seconds: 12);
      final initial = ScoreboardState.fromJson({
        ...ScoreboardState.initial.toJson(),
        'leftPoints': 25,
        'rightPoints': 22,
        'leftSets': 1,
        'rightSets': 2,
        'leftTimeouts': 0,
        'rightTimeouts': 1,
        'stopwatchElapsedMillis': 2000,
        'stopwatchRunning': true,
        'stopwatchStartedAtMillis': wonAt.millisecondsSinceEpoch,
        'timeoutSide': 1,
        'timeoutStartedAtMillis': wonAt.millisecondsSinceEpoch,
      });

      final next = initial.completeSet(
        leftWon: leftWon,
        wonAt: wonAt,
        stopwatchAt: stopwatchAt,
      );

      expect(next.leftPoints, 0);
      expect(next.rightPoints, 0);
      expect(next.leftSets, leftWon ? 2 : 1);
      expect(next.rightSets, leftWon ? 2 : 3);
      expect(next.leftTimeouts, 2);
      expect(next.rightTimeouts, 2);
      expect(next.timeoutSide, isNull);
      expect(next.timeoutStartedAt, isNull);
      expect(next.stopwatchRunning, isFalse);
      expect(next.stopwatchElapsed, Duration.zero);
      expect(next.stopwatchStartedAt, isNull);
      expect(next.completedSets, hasLength(1));
      expect(next.completedSets.single.leftPoints, 25);
      expect(next.completedSets.single.rightPoints, 22);
      expect(next.completedSets.single.winnerColor,
          leftWon ? initial.leftColor : initial.rightColor);
      expect(next.completedSets.single.stopwatchAt, stopwatchAt);
    });
  }
}
