import 'package:flutter/material.dart';

@immutable
class SetResult {
  const SetResult({
    required this.leftPoints,
    required this.rightPoints,
    required this.winnerColor,
    required this.wonAt,
    required this.stopwatchAt,
  });

  final int leftPoints;
  final int rightPoints;
  final Color winnerColor;
  final DateTime wonAt;
  final Duration stopwatchAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'leftPoints': leftPoints,
        'rightPoints': rightPoints,
        'winnerColor': winnerColor.toARGB32(),
        'wonAtMillis': wonAt.millisecondsSinceEpoch,
        'stopwatchAtMillis': stopwatchAt.inMilliseconds,
      };

  static SetResult? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);

    final leftPoints = data['leftPoints'];
    final rightPoints = data['rightPoints'];
    final winnerColor = data['winnerColor'];
    final wonAtMillis = data['wonAtMillis'];
    if (leftPoints is! num ||
        rightPoints is! num ||
        winnerColor is! num ||
        wonAtMillis is! num) {
      return null;
    }

    final stopwatchAtMillis = data['stopwatchAtMillis'];

    return SetResult(
      leftPoints: leftPoints.toInt(),
      rightPoints: rightPoints.toInt(),
      winnerColor: Color(winnerColor.toInt()),
      wonAt: DateTime.fromMillisecondsSinceEpoch(wonAtMillis.toInt()),
      stopwatchAt: Duration(
        milliseconds: stopwatchAtMillis is num ? stopwatchAtMillis.toInt() : 0,
      ),
    );
  }
}

@immutable
class ScoreboardState {
  const ScoreboardState({
    required this.leftPoints,
    required this.rightPoints,
    required this.leftSets,
    required this.rightSets,
    required this.leftColor,
    required this.rightColor,
    required this.stopwatchElapsed,
    required this.stopwatchRunning,
    required this.stopwatchStartedAt,
    required this.completedSets,
  });

  static const Color defaultLeftColor = Color(0xff1976d2);
  static const Color defaultRightColor = Color(0xffe53935);

  static const ScoreboardState initial = ScoreboardState(
    leftPoints: 0,
    rightPoints: 0,
    leftSets: 0,
    rightSets: 0,
    leftColor: defaultLeftColor,
    rightColor: defaultRightColor,
    stopwatchElapsed: Duration.zero,
    stopwatchRunning: false,
    stopwatchStartedAt: null,
    completedSets: <SetResult>[],
  );

  final int leftPoints;
  final int rightPoints;
  final int leftSets;
  final int rightSets;
  final Color leftColor;
  final Color rightColor;
  final Duration stopwatchElapsed;
  final bool stopwatchRunning;
  final DateTime? stopwatchStartedAt;
  final List<SetResult> completedSets;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'leftPoints': leftPoints,
        'rightPoints': rightPoints,
        'leftSets': leftSets,
        'rightSets': rightSets,
        'leftColor': leftColor.toARGB32(),
        'rightColor': rightColor.toARGB32(),
        'stopwatchElapsedMillis': stopwatchElapsed.inMilliseconds,
        'stopwatchRunning': stopwatchRunning,
        'stopwatchStartedAtMillis': stopwatchStartedAt?.millisecondsSinceEpoch,
        'completedSets': completedSets.map((set) => set.toJson()).toList(),
      };

  static ScoreboardState fromJson(Map<String, dynamic>? data) {
    if (data == null) return initial;

    int readInt(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    Color readColor(String key, Color fallback) {
      final value = data[key];
      return value is num ? Color(value.toInt()) : fallback;
    }

    final startedAtMillis = data['stopwatchStartedAtMillis'];
    final rawCompletedSets = data['completedSets'];
    final completedSets = rawCompletedSets is List
        ? rawCompletedSets
            .map(SetResult.fromJson)
            .whereType<SetResult>()
            .toList()
        : <SetResult>[];

    return ScoreboardState(
      leftPoints: readInt('leftPoints', 0),
      rightPoints: readInt('rightPoints', 0),
      leftSets: readInt('leftSets', 0),
      rightSets: readInt('rightSets', 0),
      leftColor: readColor('leftColor', defaultLeftColor),
      rightColor: readColor('rightColor', defaultRightColor),
      stopwatchElapsed: Duration(
        milliseconds: readInt('stopwatchElapsedMillis', 0),
      ),
      stopwatchRunning: data['stopwatchRunning'] == true,
      stopwatchStartedAt: startedAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(startedAtMillis.toInt())
          : null,
      completedSets: completedSets,
    );
  }
}
