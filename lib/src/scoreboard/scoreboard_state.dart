import 'package:flutter/material.dart';

@immutable
class ScoreboardHistoryEntry {
  const ScoreboardHistoryEntry({
    required this.action,
    required this.occurredAt,
    required this.stopwatchAt,
    required this.color,
  });

  final String action;
  final DateTime occurredAt;
  final Duration stopwatchAt;
  final Color? color;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'action': action,
        'occurredAtMillis': occurredAt.millisecondsSinceEpoch,
        'stopwatchAtMillis': stopwatchAt.inMilliseconds,
        'color': color?.toARGB32(),
      };

  static ScoreboardHistoryEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    final data = Map<String, dynamic>.from(raw);
    final action = data['action'];
    final occurredAtMillis = data['occurredAtMillis'];
    if (action is! String || occurredAtMillis is! num) return null;

    final stopwatchAtMillis = data['stopwatchAtMillis'];
    final colorValue = data['color'];

    return ScoreboardHistoryEntry(
      action: action,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAtMillis.toInt()),
      stopwatchAt: Duration(
        milliseconds: stopwatchAtMillis is num ? stopwatchAtMillis.toInt() : 0,
      ),
      color: colorValue is num ? Color(colorValue.toInt()) : null,
    );
  }
}

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
class ScoreboardSnapshot {
  const ScoreboardSnapshot({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.state,
  });

  final String id;
  final String name;
  final DateTime savedAt;
  final ScoreboardState state;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'savedAtMillis': savedAt.millisecondsSinceEpoch,
        'state': state.toJson(),
      };

  static ScoreboardSnapshot? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final id = data['id'];
    final name = data['name'];
    final savedAtMillis = data['savedAtMillis'];
    final state = data['state'];
    if (id is! String || name is! String || savedAtMillis is! num) {
      return null;
    }
    if (state is! Map) return null;

    return ScoreboardSnapshot(
      id: id,
      name: name,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis.toInt()),
      state: ScoreboardState.fromJson(Map<String, dynamic>.from(state)),
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
    required this.leftTimeouts,
    required this.rightTimeouts,
    required this.leftColor,
    required this.rightColor,
    required this.stopwatchElapsed,
    required this.stopwatchRunning,
    required this.stopwatchStartedAt,
    required this.timeoutSide,
    required this.timeoutStartedAt,
    required this.completedSets,
    required this.historyEntries,
  });

  static const Color defaultLeftColor = Color(0xff1976d2);
  static const Color defaultRightColor = Color(0xffe53935);

  static const ScoreboardState initial = ScoreboardState(
    leftPoints: 0,
    rightPoints: 0,
    leftSets: 0,
    rightSets: 0,
    leftTimeouts: 2,
    rightTimeouts: 2,
    leftColor: defaultLeftColor,
    rightColor: defaultRightColor,
    stopwatchElapsed: Duration.zero,
    stopwatchRunning: false,
    stopwatchStartedAt: null,
    timeoutSide: null,
    timeoutStartedAt: null,
    completedSets: <SetResult>[],
    historyEntries: <ScoreboardHistoryEntry>[],
  );

  final int leftPoints;
  final int rightPoints;
  final int leftSets;
  final int rightSets;
  final int leftTimeouts;
  final int rightTimeouts;
  final Color leftColor;
  final Color rightColor;
  final Duration stopwatchElapsed;
  final bool stopwatchRunning;
  final DateTime? stopwatchStartedAt;
  final int? timeoutSide;
  final DateTime? timeoutStartedAt;
  final List<SetResult> completedSets;
  final List<ScoreboardHistoryEntry> historyEntries;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'leftPoints': leftPoints,
        'rightPoints': rightPoints,
        'leftSets': leftSets,
        'rightSets': rightSets,
        'leftTimeouts': leftTimeouts,
        'rightTimeouts': rightTimeouts,
        'leftColor': leftColor.toARGB32(),
        'rightColor': rightColor.toARGB32(),
        'stopwatchElapsedMillis': stopwatchElapsed.inMilliseconds,
        'stopwatchRunning': stopwatchRunning,
        'stopwatchStartedAtMillis': stopwatchStartedAt?.millisecondsSinceEpoch,
        'timeoutSide': timeoutSide,
        'timeoutStartedAtMillis': timeoutStartedAt?.millisecondsSinceEpoch,
        'completedSets': completedSets.map((set) => set.toJson()).toList(),
        'historyEntries':
            historyEntries.map((entry) => entry.toJson()).toList(),
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
    final rawHistoryEntries = data['historyEntries'];
    final historyEntries = rawHistoryEntries is List
        ? rawHistoryEntries
            .map(ScoreboardHistoryEntry.fromJson)
            .whereType<ScoreboardHistoryEntry>()
            .toList()
        : <ScoreboardHistoryEntry>[];

    return ScoreboardState(
      leftPoints: readInt('leftPoints', 0),
      rightPoints: readInt('rightPoints', 0),
      leftSets: readInt('leftSets', 0),
      rightSets: readInt('rightSets', 0),
      leftTimeouts: readInt('leftTimeouts', 2),
      rightTimeouts: readInt('rightTimeouts', 2),
      leftColor: readColor('leftColor', defaultLeftColor),
      rightColor: readColor('rightColor', defaultRightColor),
      stopwatchElapsed: Duration(
        milliseconds: readInt('stopwatchElapsedMillis', 0),
      ),
      stopwatchRunning: data['stopwatchRunning'] == true,
      stopwatchStartedAt: startedAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(startedAtMillis.toInt())
          : null,
      timeoutSide: data['timeoutSide'] is num
          ? (data['timeoutSide'] as num).toInt()
          : null,
      timeoutStartedAt: data['timeoutStartedAtMillis'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['timeoutStartedAtMillis'] as num).toInt(),
            )
          : null,
      completedSets: completedSets,
      historyEntries: historyEntries,
    );
  }
}
