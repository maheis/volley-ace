import 'package:flutter/material.dart';

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
    );
  }
}
