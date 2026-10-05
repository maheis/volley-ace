import 'package:flutter/foundation.dart';

const List<String> volleyballLeagueOptions = <String>[
  'U12',
  'U13',
  'U14',
  'U15',
  'U16',
  'U18',
  'U20',
  'Damen',
  'Herren',
  'Mixed',
  'Freizeit',
];

int rotationPlayerCount(String league) {
  if (league == 'U12' || league == 'U13') return 3;
  if (league == 'U14' || league == 'U15') return 4;
  return 6;
}

bool usesTwoServeRotation(String league) =>
    league == 'U12' || league == 'U13' || league == 'U14' || league == 'U15';

@immutable
class RotationPlayer {
  const RotationPlayer({
    required this.id,
    required this.name,
    this.number,
  });

  final String id;
  final String name;
  final int? number;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'number': number,
      };

  static RotationPlayer? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    if (data['id'] is! String || data['name'] is! String) return null;
    return RotationPlayer(
      id: data['id'] as String,
      name: data['name'] as String,
      number: data['number'] is num ? (data['number'] as num).toInt() : null,
    );
  }
}

@immutable
class RotationTeamState {
  const RotationTeamState({
    this.name = '',
    this.sourceTeamId,
    this.players = const <RotationPlayer>[],
    this.positions = const <String?>[],
  });

  final String name;
  final int? sourceTeamId;
  final List<RotationPlayer> players;
  final List<String?> positions;

  RotationTeamState copyWith({
    String? name,
    int? sourceTeamId,
    bool clearSourceTeamId = false,
    List<RotationPlayer>? players,
    List<String?>? positions,
  }) =>
      RotationTeamState(
        name: name ?? this.name,
        sourceTeamId:
            clearSourceTeamId ? null : (sourceTeamId ?? this.sourceTeamId),
        players: players ?? this.players,
        positions: positions ?? this.positions,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'sourceTeamId': sourceTeamId,
        'players': players.map((player) => player.toJson()).toList(),
        'positions': positions,
      };

  static RotationTeamState fromJson(dynamic raw) {
    if (raw is! Map) return const RotationTeamState();
    final data = Map<String, dynamic>.from(raw);
    final rawPlayers = data['players'];
    final rawPositions = data['positions'];
    return RotationTeamState(
      name: data['name'] is String ? data['name'] as String : '',
      sourceTeamId: data['sourceTeamId'] is num
          ? (data['sourceTeamId'] as num).toInt()
          : null,
      players: rawPlayers is List
          ? rawPlayers
              .map(RotationPlayer.fromJson)
              .whereType<RotationPlayer>()
              .toList()
          : const <RotationPlayer>[],
      positions: rawPositions is List
          ? rawPositions.map((value) => value is String ? value : null).toList()
          : const <String?>[],
    );
  }
}

@immutable
class ScoreboardRotationState {
  const ScoreboardRotationState({
    required this.league,
    required this.left,
    required this.right,
    required this.servingSide,
    this.consecutiveServePoints = 0,
  });

  final String league;
  final RotationTeamState left;
  final RotationTeamState right;
  final int servingSide;
  final int consecutiveServePoints;

  RotationTeamState teamAt(int side) => side == 0 ? left : right;

  bool get isPlayable {
    final requiredCount = rotationPlayerCount(league);
    return <RotationTeamState>[left, right].every(
      (team) =>
          team.positions.length >= requiredCount &&
          team.positions.take(requiredCount).every((id) => id != null) &&
          team.positions.take(requiredCount).toSet().length == requiredCount,
    );
  }

  ScoreboardRotationState copyWith({
    String? league,
    RotationTeamState? left,
    RotationTeamState? right,
    int? servingSide,
    int? consecutiveServePoints,
  }) =>
      ScoreboardRotationState(
        league: league ?? this.league,
        left: left ?? this.left,
        right: right ?? this.right,
        servingSide: servingSide ?? this.servingSide,
        consecutiveServePoints:
            consecutiveServePoints ?? this.consecutiveServePoints,
      );

  ScoreboardRotationState afterPoint(int scoringSide) {
    if (scoringSide != servingSide) {
      return copyWith(
        left: scoringSide == 0 && isPlayable ? _rotate(left) : left,
        right: scoringSide == 1 && isPlayable ? _rotate(right) : right,
        servingSide: scoringSide,
        consecutiveServePoints: 0,
      );
    }
    if (!usesTwoServeRotation(league)) return this;

    final servePoints = consecutiveServePoints + 1;
    final shouldRotate = servePoints >= 2;
    return copyWith(
      left:
          scoringSide == 0 && shouldRotate && isPlayable ? _rotate(left) : left,
      right: scoringSide == 1 && shouldRotate && isPlayable
          ? _rotate(right)
          : right,
      consecutiveServePoints: shouldRotate ? 0 : servePoints,
    );
  }

  ScoreboardRotationState rotate(int side) => copyWith(
        left: side == 0 ? _rotate(left) : left,
        right: side == 1 ? _rotate(right) : right,
      );

  ScoreboardRotationState substitute({
    required int side,
    required int position,
    required String playerId,
  }) {
    final team = teamAt(side);
    if (position < 0 || position >= team.positions.length) return this;
    if (!team.players.any((player) => player.id == playerId)) return this;
    if (team.positions.contains(playerId)) return this;
    final positions = List<String?>.from(team.positions)..[position] = playerId;
    final updated = team.copyWith(positions: positions);
    return copyWith(
        left: side == 0 ? updated : left, right: side == 1 ? updated : right);
  }

  ScoreboardRotationState swapSides() => copyWith(
        left: right,
        right: left,
        servingSide: servingSide == 0 ? 1 : 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'league': league,
        'left': left.toJson(),
        'right': right.toJson(),
        'servingSide': servingSide,
        'consecutiveServePoints': consecutiveServePoints,
      };

  static ScoreboardRotationState? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final league = data['league'];
    if (league is! String || !volleyballLeagueOptions.contains(league)) {
      return null;
    }
    final servingSide = data['servingSide'];
    return ScoreboardRotationState(
      league: league,
      left: RotationTeamState.fromJson(data['left']),
      right: RotationTeamState.fromJson(data['right']),
      servingSide: servingSide == 1 ? 1 : 0,
      consecutiveServePoints: data['consecutiveServePoints'] is num
          ? (data['consecutiveServePoints'] as num).toInt().clamp(0, 1)
          : 0,
    );
  }

  static RotationTeamState _rotate(RotationTeamState team) {
    if (team.positions.length < 2) return team;
    return team.copyWith(
      positions: <String?>[
        ...team.positions.skip(1),
        team.positions.first,
      ],
    );
  }
}
