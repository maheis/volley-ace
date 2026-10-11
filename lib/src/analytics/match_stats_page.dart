import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import '../scoreboard/rotation_state.dart';
import '../teams/teams_page.dart';
import '../scoreboard/rotation_setup_page.dart';
import '../theme/app_palette.dart';

class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.name,
    required this.number,
    this.teamPlayerId,
    this.sourceTeamId,
  });

  final int id;
  final String name;
  final int number;
  final int? teamPlayerId;
  final int? sourceTeamId;

  MatchPlayer copyWith({
    int? id,
    String? name,
    int? number,
    int? teamPlayerId,
    bool clearTeamPlayerId = false,
    int? sourceTeamId,
    bool clearSourceTeamId = false,
  }) {
    return MatchPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      teamPlayerId:
          clearTeamPlayerId ? null : (teamPlayerId ?? this.teamPlayerId),
      sourceTeamId:
          clearSourceTeamId ? null : (sourceTeamId ?? this.sourceTeamId),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'number': number,
        'teamPlayerId': teamPlayerId,
        'sourceTeamId': sourceTeamId,
      };

  static MatchPlayer fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final name = data['name'];
    final number = data['number'];

    return MatchPlayer(
      id: id is num ? id.toInt() : 0,
      name: name is String ? name : '',
      number: number is num ? number.toInt() : 0,
      teamPlayerId: data['teamPlayerId'] is num
          ? (data['teamPlayerId'] as num).toInt()
          : null,
      sourceTeamId: data['sourceTeamId'] is num
          ? (data['sourceTeamId'] as num).toInt()
          : null,
    );
  }
}

class MatchEvent {
  const MatchEvent({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.playerNumber,
    required this.kind,
    required this.category,
    required this.occurredAt,
    this.rotationPosition,
  });

  final int id;
  final int? playerId;
  final String playerName;
  final int playerNumber;
  final String kind;
  final String category;
  final DateTime occurredAt;
  final int? rotationPosition;

  MatchEvent copyWith({
    int? playerId,
    bool clearPlayerId = false,
    String? playerName,
    int? playerNumber,
    String? kind,
    String? category,
  }) =>
      MatchEvent(
        id: id,
        playerId: clearPlayerId ? null : (playerId ?? this.playerId),
        playerName: playerName ?? this.playerName,
        playerNumber: playerNumber ?? this.playerNumber,
        kind: kind ?? this.kind,
        category: category ?? this.category,
        occurredAt: occurredAt,
        rotationPosition: rotationPosition,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'playerNumber': playerNumber,
        'kind': kind,
        'category': category,
        'occurredAtMillis': occurredAt.millisecondsSinceEpoch,
        'rotationPosition': rotationPosition,
      };

  static MatchEvent fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final playerId = data['playerId'];
    final playerName = data['playerName'];
    final playerNumber = data['playerNumber'];
    final kind = data['kind'];
    final category = data['category'];
    final categoryName = category is String ? category : 'Ass';
    final occurredAtMillis = data['occurredAtMillis'];

    return MatchEvent(
      id: id is num ? id.toInt() : 0,
      playerId: playerId is num ? playerId.toInt() : null,
      playerName: playerName is String ? playerName : 'Unbekannt',
      playerNumber: playerNumber is num ? playerNumber.toInt() : 0,
      kind: kind is String ? kind : 'point',
      category: categoryName.startsWith('Annahmefehler')
          ? categoryName.replaceFirst('Annahmefehler', 'Annahme')
          : categoryName,
      occurredAt: occurredAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(occurredAtMillis.toInt())
          : DateTime.now(),
      rotationPosition: data['rotationPosition'] is num
          ? (data['rotationPosition'] as num).toInt()
          : null,
    );
  }
}

class MatchCoach {
  const MatchCoach({required this.id, required this.name});

  final int id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  static MatchCoach fromJson(Map<String, dynamic> data) => MatchCoach(
        id: data['id'] is num ? (data['id'] as num).toInt() : 0,
        name: data['name'] is String ? data['name'] as String : '',
      );
}

class MatchGame {
  const MatchGame({
    required this.id,
    required this.createdAt,
    required this.location,
    required this.opponentTeam,
    required this.matchDateTime,
    required this.matchTag,
    required this.matchType,
    this.league = '',
    this.teamId,
    this.rotationSetup,
    this.rotationIsOnLeft = true,
    this.coaches = const <MatchCoach>[],
    required this.players,
    required this.events,
    this.stopwatchElapsed = Duration.zero,
    this.stopwatchRunning = false,
    this.stopwatchStartedAt,
  });

  final int id;
  final DateTime createdAt;
  final String location;
  final String opponentTeam;
  final DateTime matchDateTime;
  final String matchTag;
  final String matchType;
  final String league;
  final int? teamId;
  final ScoreboardRotationState? rotationSetup;
  final bool rotationIsOnLeft;
  final List<MatchCoach> coaches;
  final List<MatchPlayer> players;
  final List<MatchEvent> events;
  final Duration stopwatchElapsed;
  final bool stopwatchRunning;
  final DateTime? stopwatchStartedAt;

  MatchGame copyWith({
    int? id,
    DateTime? createdAt,
    String? location,
    String? opponentTeam,
    DateTime? matchDateTime,
    String? matchTag,
    String? matchType,
    String? league,
    int? teamId,
    bool clearTeamId = false,
    ScoreboardRotationState? rotationSetup,
    bool clearRotationSetup = false,
    bool? rotationIsOnLeft,
    List<MatchCoach>? coaches,
    List<MatchPlayer>? players,
    List<MatchEvent>? events,
    Duration? stopwatchElapsed,
    bool? stopwatchRunning,
    DateTime? stopwatchStartedAt,
    bool clearStopwatchStartedAt = false,
  }) {
    return MatchGame(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      opponentTeam: opponentTeam ?? this.opponentTeam,
      matchDateTime: matchDateTime ?? this.matchDateTime,
      matchTag: matchTag ?? this.matchTag,
      matchType: matchType ?? this.matchType,
      league: league ?? this.league,
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
      rotationSetup:
          clearRotationSetup ? null : (rotationSetup ?? this.rotationSetup),
      rotationIsOnLeft: rotationIsOnLeft ?? this.rotationIsOnLeft,
      coaches: coaches ?? this.coaches,
      players: players ?? this.players,
      events: events ?? this.events,
      stopwatchElapsed: stopwatchElapsed ?? this.stopwatchElapsed,
      stopwatchRunning: stopwatchRunning ?? this.stopwatchRunning,
      stopwatchStartedAt: clearStopwatchStartedAt
          ? null
          : (stopwatchStartedAt ?? this.stopwatchStartedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAtMillis': createdAt.millisecondsSinceEpoch,
        'location': location,
        'opponentTeam': opponentTeam,
        'matchDateTimeMillis': matchDateTime.millisecondsSinceEpoch,
        'matchTag': matchTag,
        'matchType': matchType,
        'league': league,
        'teamId': teamId,
        'rotationSetup': rotationSetup?.toJson(),
        'rotationIsOnLeft': rotationIsOnLeft,
        'coaches': coaches.map((coach) => coach.toJson()).toList(),
        'players': players.map((player) => player.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
        'stopwatchElapsedMillis': stopwatchElapsed.inMilliseconds,
        'stopwatchRunning': stopwatchRunning,
        'stopwatchStartedAtMillis': stopwatchStartedAt?.millisecondsSinceEpoch,
      };

  static MatchGame fromJson(Map<String, dynamic> data) {
    final playersData = data['players'];
    final eventsData = data['events'];
    final createdAtMillis = data['createdAtMillis'];
    final matchDateTimeMillis = data['matchDateTimeMillis'];
    final fallbackMatchDateTime = matchDateTimeMillis is num
        ? DateTime.fromMillisecondsSinceEpoch(matchDateTimeMillis.toInt())
        : DateTime.now();

    final players = playersData is List
        ? playersData
            .whereType<Map>()
            .map(
                (item) => MatchPlayer.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <MatchPlayer>[];
    final events = eventsData is List
        ? eventsData
            .whereType<Map>()
            .map((item) => MatchEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <MatchEvent>[];
    final coachesData = data['coaches'];
    final coaches = coachesData is List
        ? coachesData
            .whereType<Map>()
            .map((item) => MatchCoach.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : data['coachId'] is num
            ? <MatchCoach>[
                MatchCoach(
                  id: (data['coachId'] as num).toInt(),
                  name: data['coachName'] is String
                      ? data['coachName'] as String
                      : '',
                ),
              ]
            : <MatchCoach>[];

    final stopwatchElapsedMillis = data['stopwatchElapsedMillis'];
    final stopwatchStartedAtMillis = data['stopwatchStartedAtMillis'];

    return MatchGame(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      createdAt: createdAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMillis.toInt())
          : DateTime.now(),
      location: data['location'] is String ? data['location'] as String : '',
      opponentTeam:
          data['opponentTeam'] is String ? data['opponentTeam'] as String : '',
      matchDateTime: fallbackMatchDateTime,
      matchTag: data['matchTag'] is String ? data['matchTag'] as String : '',
      matchType: data['matchType'] is String
          ? data['matchType'] as String
          : 'Freundschaftsspiel',
      league: data['league'] is String ? data['league'] as String : '',
      teamId: data['teamId'] is num ? (data['teamId'] as num).toInt() : null,
      rotationSetup: ScoreboardRotationState.fromJson(data['rotationSetup']),
      rotationIsOnLeft: data['rotationIsOnLeft'] is bool
          ? data['rotationIsOnLeft'] as bool
          : true,
      coaches: coaches,
      players: players,
      events: events,
      stopwatchElapsed: stopwatchElapsedMillis is num
          ? Duration(milliseconds: stopwatchElapsedMillis.toInt())
          : Duration.zero,
      stopwatchRunning: data['stopwatchRunning'] is bool
          ? data['stopwatchRunning'] as bool
          : false,
      stopwatchStartedAt: stopwatchStartedAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(
              stopwatchStartedAtMillis.toInt())
          : null,
    );
  }
}

int compareMatchesByGameTime(MatchGame first, MatchGame second) {
  final gameTimeOrder = second.matchDateTime.compareTo(first.matchDateTime);
  return gameTimeOrder != 0
      ? gameTimeOrder
      : second.createdAt.compareTo(first.createdAt);
}

MatchGame combineMatchesForStatistics(List<MatchGame> matches) {
  if (matches.isEmpty) {
    throw ArgumentError.value(matches, 'matches', 'Must not be empty');
  }

  final playersByKey = <String, MatchPlayer>{};
  final combinedPlayers = <MatchPlayer>[];
  final combinedEvents = <MatchEvent>[];

  for (final match in matches) {
    final playerIds = <int, int>{};
    for (final player in match.players) {
      final identity = player.teamPlayerId != null
          ? 'team:${match.teamId}:${player.teamPlayerId}'
          : 'name:${player.name.trim().toLowerCase()}';
      var combinedPlayer = playersByKey[identity];
      if (combinedPlayer == null) {
        combinedPlayer = MatchPlayer(
          id: combinedPlayers.length + 1,
          name: player.name,
          number: player.number,
          teamPlayerId: player.teamPlayerId,
          sourceTeamId: player.sourceTeamId,
        );
        playersByKey[identity] = combinedPlayer;
        combinedPlayers.add(combinedPlayer);
      }
      playerIds[player.id] = combinedPlayer.id;
    }

    for (final event in match.events) {
      final int? combinedPlayerId;
      if (event.playerId == null) {
        combinedPlayerId = null;
      } else if (event.playerId == _unknownScorerId ||
          event.playerId == _teamScorerId) {
        final specialKey = 'special:${event.playerId}';
        var specialPlayer = playersByKey[specialKey];
        if (specialPlayer == null) {
          specialPlayer = MatchPlayer(
            id: combinedPlayers.length + 1,
            name: event.playerName,
            number: 0,
          );
          playersByKey[specialKey] = specialPlayer;
          combinedPlayers.add(specialPlayer);
        }
        combinedPlayerId = specialPlayer.id;
      } else {
        combinedPlayerId = playerIds[event.playerId];
      }
      combinedEvents.add(
        MatchEvent(
          id: combinedEvents.length + 1,
          playerId: combinedPlayerId,
          playerName: event.playerName,
          playerNumber: event.playerNumber,
          kind: event.kind,
          category: event.category,
          occurredAt: event.occurredAt,
          rotationPosition: event.rotationPosition,
        ),
      );
    }
  }

  final firstMatch = matches.first;
  return MatchGame(
    id: -1,
    createdAt: firstMatch.createdAt,
    location: '',
    opponentTeam: '${matches.length} Spiele',
    matchDateTime: firstMatch.matchDateTime,
    matchTag: '',
    matchType: 'Zusammenfassung',
    players: combinedPlayers,
    events: combinedEvents,
  );
}

ScoreboardRotationState? rotationAfterMatchEvents(MatchGame match) {
  final initialRotation = match.rotationSetup;
  if (initialRotation == null) return null;
  var rotation = initialRotation;
  final events = List<MatchEvent>.from(match.events)
    ..sort((a, b) {
      final timeOrder = a.occurredAt.compareTo(b.occurredAt);
      return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
    });
  var ourScore = 0;
  var opponentScore = 0;
  for (final event in events) {
    if (event.kind == 'manual_set_end') {
      ourScore = 0;
      opponentScore = 0;
      rotation = rotation.copyWith(consecutiveServePoints: 0);
      continue;
    }
    if (event.kind == 'substitution') {
      final position = event.rotationPosition;
      final playerId = event.playerId;
      if (position != null && playerId != null) {
        rotation = rotation.substitute(
          side: 0,
          position: position,
          playerId: 'match-$playerId',
        );
      }
      continue;
    }
    if (event.kind != 'point' && event.kind != 'error') continue;

    final scoringSide = event.kind == 'point' ? 0 : 1;
    rotation = rotation.afterPoint(scoringSide);
    if (scoringSide == 0) {
      ourScore++;
    } else {
      opponentScore++;
    }
    final setFinished = (ourScore >= 25 && ourScore - opponentScore >= 2) ||
        (opponentScore >= 25 && opponentScore - ourScore >= 2);
    if (setFinished) {
      ourScore = 0;
      opponentScore = 0;
      rotation = rotation.copyWith(consecutiveServePoints: 0);
    }
  }
  return rotation;
}

List<MatchPlayer> fieldPlayersForScoring(MatchGame match) {
  final rotation = rotationAfterMatchEvents(match);
  if (rotation == null) return match.players;
  final activeRotationIds = rotation.left.positions
      .take(rotationPlayerCount(rotation.league))
      .whereType<String>()
      .toSet();
  return match.players
      .where((player) => activeRotationIds.contains('match-${player.id}'))
      .toList();
}

MatchGame syncMatchPlayerNumbersFromTeam(MatchGame match, Team team) {
  final numbersByTeamPlayerId = <int, int>{
    for (final player in team.players)
      if (player.number != null) player.id: player.number!,
  };
  final updatedPlayers = match.players.map((player) {
    if (player.sourceTeamId != team.id) return player;
    final number = numbersByTeamPlayerId[player.teamPlayerId];
    return number == null ? player : player.copyWith(number: number);
  }).toList();
  final rotation = match.rotationSetup;
  final syncedRotation = rotation?.copyWith(
    left: rotation.left.copyWith(
      players: rotation.left.players.map((rotationPlayer) {
        final playerId = int.tryParse(
          rotationPlayer.id.replaceFirst('match-', ''),
        );
        final player = playerId == null
            ? null
            : updatedPlayers.cast<MatchPlayer?>().firstWhere(
                  (entry) => entry?.id == playerId,
                  orElse: () => null,
                );
        return player == null
            ? rotationPlayer
            : RotationPlayer(
                id: rotationPlayer.id,
                name: rotationPlayer.name,
                number: player.number,
              );
      }).toList(),
    ),
  );
  return match.copyWith(
    players: updatedPlayers,
    rotationSetup: syncedRotation,
  );
}

MatchEvent? lastMatchActionEvent(MatchGame match) {
  final actions = match.events
      .where((event) =>
          event.kind == 'point' ||
          event.kind == 'error' ||
          event.kind == 'timeout' ||
          event.kind == 'manual_set_end' ||
          event.kind == 'substitution')
      .toList()
    ..sort((first, second) {
      final timeOrder = first.occurredAt.compareTo(second.occurredAt);
      return timeOrder != 0 ? timeOrder : first.id.compareTo(second.id);
    });
  return actions.lastOrNull;
}

MatchGame undoLastMatchAction(MatchGame match) {
  final lastAction = lastMatchActionEvent(match);
  if (lastAction == null) return match;
  return match.copyWith(
    events: match.events.where((event) => event.id != lastAction.id).toList(),
  );
}

class MatchStatsState {
  const MatchStatsState({required this.matches});

  static const MatchStatsState empty = MatchStatsState(matches: <MatchGame>[]);

  final List<MatchGame> matches;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'matches': matches.map((match) => match.toJson()).toList(),
      };

  static MatchStatsState fromJson(Map<String, dynamic>? data) {
    if (data == null) return empty;

    final matchesData = data['matches'];
    final matches = matchesData is List
        ? matchesData
            .whereType<Map>()
            .map((item) => MatchGame.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <MatchGame>[];

    return MatchStatsState(matches: matches);
  }
}

const String _timeoutKind = 'timeout';
const String _manualSetEndKind = 'manual_set_end';
const int _unknownScorerId = -1;
const int _teamScorerId = -2;
const Duration _scoringSelectionTimeout = Duration(seconds: 7);
const String _otherCategoryTimeoutResult = '__scoring_timeout__';

class _UndoScoringIntent extends Intent {
  const _UndoScoringIntent();
}

class _RedoScoringIntent extends Intent {
  const _RedoScoringIntent();
}

class _ScoringCategory {
  const _ScoringCategory(
    this.label, {
    this.children = const <_ScoringCategory>[],
    this.requiresText = false,
  });

  final String label;
  final List<_ScoringCategory> children;
  final bool requiresText;
}

class MatchStatsRepository {
  MatchStatsRepository(Database database) : _database = database;

  static const String _recordKey = 'match_stats';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('analytics');

  final Database _database;

  Future<MatchStatsState> load() async {
    final data = await _store.record(_recordKey).get(_database);
    return MatchStatsState.fromJson(data);
  }

  Future<void> save(MatchStatsState state) async {
    await _store.record(_recordKey).put(_database, state.toJson());
  }
}

class MatchStatsPage extends StatefulWidget {
  const MatchStatsPage({
    super.key,
    required this.database,
    this.initialMatchId,
  });

  final Database database;
  final int? initialMatchId;

  @override
  State<MatchStatsPage> createState() => _MatchStatsPageState();
}

class _MatchStatsPageState extends State<MatchStatsPage> {
  static const List<String> _matchTypes = <String>[
    'Liga',
    'Turnier',
    'Freundschaftsspiel',
    'Trainingsspiel',
  ];
  static const List<String> _leagues = <String>[
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

  static const String _opponentErrorCategory = 'Gegner Fehler';
  static const String _timeoutKind = 'timeout';
  static const List<_ScoringCategory> _pointCategories = <_ScoringCategory>[
    _ScoringCategory('Aufschlag', children: <_ScoringCategory>[
      _ScoringCategory('Ass'),
      _ScoringCategory('Netzroller'),
      _ScoringCategory('Scharf'),
      _ScoringCategory('Gegenfehler'),
    ]),
    _ScoringCategory('Angriff', children: <_ScoringCategory>[
      _ScoringCategory('Auge / Lücke'),
      _ScoringCategory('Angriffsschlag'),
      _ScoringCategory('Gegner Annahmefehler'),
      _ScoringCategory('Zuspieler-Finte'),
      _ScoringCategory('Netzroller'),
    ]),
    _ScoringCategory('Block'),
    _ScoringCategory(_opponentErrorCategory),
    _ScoringCategory('Sonstiges', requiresText: true),
  ];
  static const List<_ScoringCategory> _errorCategories = <_ScoringCategory>[
    _ScoringCategory('Aufschlag', children: <_ScoringCategory>[
      _ScoringCategory('Ball ins seitliche Aus'),
      _ScoringCategory('Ball ins hintere Aus'),
      _ScoringCategory('Ball ins Netz'),
      _ScoringCategory('Ball zu kurz'),
      _ScoringCategory('Übertritt'),
    ]),
    _ScoringCategory('Annahme', children: <_ScoringCategory>[
      _ScoringCategory('Zugeschaut'),
      _ScoringCategory('Tusch'),
      _ScoringCategory('Untere Annahme'),
      _ScoringCategory('Obere Annahme'),
    ]),
    _ScoringCategory('Angriff', children: <_ScoringCategory>[
      _ScoringCategory('Ball ins seitliche Aus'),
      _ScoringCategory('Ball ins hintere Aus'),
      _ScoringCategory('Ball ins Netz'),
      _ScoringCategory('Ball nicht rüber'),
      _ScoringCategory('Hinterfeldangriff'),
    ]),
    _ScoringCategory('Netz', children: <_ScoringCategory>[
      _ScoringCategory('Berührung'),
      _ScoringCategory('Übertritt'),
    ]),
    _ScoringCategory('Sonstiges', requiresText: true),
  ];

  late final MatchStatsRepository _repository = MatchStatsRepository(
    widget.database,
  );
  late final TeamsRepository _teamsRepository =
      TeamsRepository(widget.database);

  final List<MatchGame> _matches = <MatchGame>[];
  final List<Team> _teams = <Team>[];
  final Map<int, List<MatchEvent>> _redoEventsByMatchId =
      <int, List<MatchEvent>>{};
  int? _selectedMatchId;
  String? _activeSection;
  String? _pendingEventKind;
  List<String> _pendingCategoryPath = <String>[];
  int? _pendingScorerId;
  String? _pendingScorerName;
  int _pendingScorerNumber = 0;
  final Set<int> _selectedMatchIds = <int>{};
  bool _isLoaded = false;
  int _nextMatchId = 1;

  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerNumberController = TextEditingController();
  final TextEditingController _coachNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _matchTagController = TextEditingController();
  final Map<String, TextEditingController> _teamNumberControllers =
      <String, TextEditingController>{};
  int? _editingMatchPlayerId;

  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _scoringSelectionTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      _repository.load(),
      _teamsRepository.load(),
    ]);
    final state = results[0] as MatchStatsState;
    final teams = results[1] as List<Team>;
    if (!mounted) return;

    setState(() {
      _matches
        ..clear()
        ..addAll(state.matches)
        ..sort(compareMatchesByGameTime);
      _teams
        ..clear()
        ..addAll(teams);
      _isLoaded = true;
      _nextMatchId = _matches.isEmpty
          ? 1
          : _matches.map((match) => match.id).reduce((a, b) => a > b ? a : b) +
              1;
    });
    if (widget.initialMatchId != null &&
        _matches.any((match) => match.id == widget.initialMatchId)) {
      _showMatchDetail(widget.initialMatchId!);
    }
  }

  Future<void> _persist() async {
    final matches = List<MatchGame>.from(_matches)
      ..sort(compareMatchesByGameTime);
    await _repository.save(MatchStatsState(matches: matches));
  }

  Future<void> _importBackup() async {
    final imported =
        await AppBackupService.importMatchBackup(context, widget.database);
    if (imported && mounted) {
      await _load();
    }
  }

  MatchGame? get _selectedMatch {
    for (final match in _matches) {
      if (match.id == _selectedMatchId) return match;
    }
    return null;
  }

  List<MatchGame> get _selectedMatches =>
      _matches.where((match) => _selectedMatchIds.contains(match.id)).toList();

  void _toggleMatchSelection(int matchId) {
    setState(() {
      if (!_selectedMatchIds.add(matchId)) {
        _selectedMatchIds.remove(matchId);
      }
    });
  }

  void _clearMatchSelection() {
    setState(_selectedMatchIds.clear);
  }

  void _openCombinedStats() {
    if (_selectedMatchIds.isEmpty) return;
    setState(() => _activeSection = 'multi-stats');
  }

  MatchGame _combinedStatsMatch(List<MatchGame> matches) {
    return combineMatchesForStatistics(matches);
  }

  MatchGame _matchWithAggregateScorerRows(MatchGame match) {
    final players = List<MatchPlayer>.from(match.players);
    for (final scorer in [
      (_unknownScorerId, 'Unbekannt'),
      (_teamScorerId, 'Mannschaft'),
    ]) {
      if (!match.events.any((event) => event.playerId == scorer.$1) ||
          players.any((player) => player.id == scorer.$1)) {
        continue;
      }
      players.add(MatchPlayer(id: scorer.$1, name: scorer.$2, number: 0));
    }
    return match.copyWith(players: players);
  }

  String _displayPlayerName(MatchGame match, MatchPlayer player) {
    final teamPlayerId = player.teamPlayerId;
    if (teamPlayerId == null || match.teamId == null) return player.name;
    final team = _teams.cast<Team?>().firstWhere(
          (entry) => entry?.id == match.teamId,
          orElse: () => null,
        );
    final teamPlayer = team?.players.cast<TeamPlayer?>().firstWhere(
          (entry) => entry?.id == teamPlayerId,
          orElse: () => null,
        );
    return teamPlayer?.name ?? player.name;
  }

  Widget _buildMatchIcon(BuildContext context, MatchGame match) {
    final team = match.teamId == null
        ? null
        : _teams.cast<Team?>().firstWhere(
              (entry) => entry?.id == match.teamId,
              orElse: () => null,
            );
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = team?.primaryColorValue == null
        ? colorScheme.primary
        : Color(team!.primaryColorValue!);
    final iconColor = team?.secondaryColorValue == null
        ? colorScheme.surfaceContainerHighest
        : Color(team!.secondaryColorValue!);

    return CircleAvatar(
      backgroundColor: backgroundColor,
      child: Icon(Icons.analytics_outlined, color: iconColor),
    );
  }

  void _showMatchDetail(int matchId, {String? section}) {
    _scoringSelectionTimer?.cancel();
    if (section == 'info') {
      final match = _matches.firstWhere((entry) => entry.id == matchId);
      _locationController.text = match.location;
      _opponentController.text = match.opponentTeam;
      _matchTagController.text = match.matchTag;
    }
    setState(() {
      _selectedMatchIds.clear();
      _selectedMatchId = matchId;
      _activeSection = section;
      _pendingEventKind = null;
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
    });
  }

  void _closeMatchDetail() {
    _scoringSelectionTimer?.cancel();
    setState(() {
      _selectedMatchIds.clear();
      _selectedMatchId = null;
      _activeSection = null;
      _pendingEventKind = null;
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
    });
  }

  void _handleSystemBack() {
    _scoringSelectionTimer?.cancel();
    if (_activeSection == 'multi-stats') {
      setState(() => _activeSection = null);
      return;
    }
    if (_selectedMatchId == null) return;
    setState(() {
      if (_activeSection == 'player-selection') {
        _pendingEventKind = null;
        _pendingCategoryPath = <String>[];
        _pendingScorerId = null;
        _pendingScorerName = null;
        _activeSection = 'scoring';
      } else if (_activeSection == 'category-selection') {
        _pendingEventKind = null;
        _pendingCategoryPath = <String>[];
        _pendingScorerId = null;
        _pendingScorerName = null;
        _activeSection = 'scoring';
      } else if (_activeSection == 'info' ||
          _activeSection == 'scoring' ||
          _activeSection == 'stats') {
        _activeSection = null;
      } else {
        _selectedMatchId = null;
        _activeSection = null;
        _pendingEventKind = null;
      }
    });
  }

  void _openNewMatchForm() {
    final match = MatchGame(
      id: _nextMatchId++,
      createdAt: DateTime.now(),
      location: '',
      opponentTeam: '',
      matchDateTime: DateTime.now(),
      matchTag: '',
      matchType: _matchTypes[2],
      teamId: null,
      coaches: const <MatchCoach>[],
      players: const <MatchPlayer>[],
      events: const <MatchEvent>[],
    );
    _locationController.clear();
    _opponentController.clear();
    _matchTagController.clear();
    setState(() {
      _matches.insert(0, match);
      _selectedMatchId = match.id;
      _activeSection = 'info';
    });
    unawaited(_persist());
  }

  void _updateMatchInfo(
    MatchGame match, {
    String? location,
    String? opponentTeam,
    DateTime? matchDateTime,
    String? matchTag,
    String? matchType,
    String? league,
    int? teamId,
    bool clearTeamId = false,
    bool clearRotationSetup = false,
    List<MatchCoach>? coaches,
  }) {
    _replaceMatch(
      match.copyWith(
        location: location,
        opponentTeam: opponentTeam,
        matchDateTime: matchDateTime,
        matchTag: matchTag,
        matchType: matchType,
        league: league,
        teamId: teamId,
        clearTeamId: clearTeamId,
        clearRotationSetup: clearRotationSetup,
        coaches: coaches,
      ),
    );
  }

  void _addPlayerToMatch(MatchGame match) {
    final name = _playerNameController.text.trim();
    final numberText = _playerNumberController.text.trim();

    if (name.isEmpty || numberText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name und Trikotnummer sind erforderlich.')),
      );
      return;
    }

    final number = int.tryParse(numberText);
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trikotnummer muss eine Zahl sein.')),
      );
      return;
    }

    final editingId = _editingMatchPlayerId;
    final List<MatchPlayer> players;
    if (editingId == null) {
      final nextId = match.players.isEmpty
          ? 1
          : match.players
                  .map((player) => player.id)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      players = List<MatchPlayer>.from(match.players)
        ..add(MatchPlayer(id: nextId, name: name, number: number));
    } else {
      players = match.players
          .map(
            (player) => player.id == editingId
                ? player.copyWith(name: name, number: number)
                : player,
          )
          .toList();
    }

    _replaceMatch(match.copyWith(
      players: players,
      clearRotationSetup: !_matchHasScoredPoints(match),
    ));
    setState(() => _editingMatchPlayerId = null);
    _playerNameController.clear();
    _playerNumberController.clear();
  }

  void _startEditingMatchPlayer(MatchPlayer player) {
    setState(() {
      _editingMatchPlayerId = player.id;
      _playerNameController.text = player.name;
      _playerNumberController.text = player.number.toString();
    });
  }

  void _cancelEditingMatchPlayer() {
    setState(() {
      _editingMatchPlayerId = null;
      _playerNameController.clear();
      _playerNumberController.clear();
    });
  }

  TextEditingController _teamPlayerNumberController(
    MatchGame match,
    MatchPlayer player,
  ) {
    final key = '${match.id}:${player.id}';
    return _teamNumberControllers.putIfAbsent(
      key,
      () => TextEditingController(text: player.number.toString()),
    );
  }

  void _toggleTeamPlayer(MatchGame match, TeamPlayer player, bool selected) {
    final players = List<MatchPlayer>.from(match.players);
    if (selected) {
      final nextId = players.isEmpty
          ? 1
          : players.map((entry) => entry.id).reduce((a, b) => a > b ? a : b) +
              1;
      players.add(MatchPlayer(
        id: nextId,
        name: player.name,
        number: player.number ?? 0,
        teamPlayerId: player.id,
        sourceTeamId: match.teamId,
      ));
    } else {
      _confirmRemoveTeamPlayer(match, player);
      return;
    }
    _replaceMatch(match.copyWith(
      players: players,
      clearRotationSetup: !_matchHasScoredPoints(match),
    ));
  }

  Future<void> _confirmRemoveTeamPlayer(
    MatchGame match,
    TeamPlayer player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spieler entfernen?'),
        content: Text('„${player.name}“ wird aus dieser Wertung entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final players = List<MatchPlayer>.from(match.players)
      ..removeWhere((entry) => entry.teamPlayerId == player.id);
    _replaceMatch(match.copyWith(
      players: players,
      clearRotationSetup: !_matchHasScoredPoints(match),
    ));
  }

  void _selectTeam(MatchGame match, int? teamId) {
    final selectedTeam = teamId == null
        ? null
        : _teams.cast<Team?>().firstWhere(
              (team) => team?.id == teamId,
              orElse: () => null,
            );
    _updateMatchInfo(
      match,
      teamId: teamId,
      clearTeamId: teamId == null,
      clearRotationSetup: !_matchHasScoredPoints(match),
      league: selectedTeam?.league ?? '',
      coaches: const <MatchCoach>[],
    );
  }

  void _toggleCoach(MatchGame match, TeamCoach coach, bool selected) {
    final coaches = List<MatchCoach>.from(match.coaches);
    if (selected) {
      coaches.add(MatchCoach(id: coach.id, name: coach.name));
    } else {
      coaches.removeWhere((entry) => entry.id == coach.id);
    }
    _updateMatchInfo(
      match,
      coaches: coaches,
    );
  }

  void _addCoachToMatch(MatchGame match) {
    final name = _coachNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Trainername ist erforderlich.')),
      );
      return;
    }

    final nextId = match.coaches.isEmpty
        ? -1
        : match.coaches.map((coach) => coach.id).reduce(math.min) - 1;
    final coaches = List<MatchCoach>.from(match.coaches)
      ..add(MatchCoach(id: nextId, name: name));
    _updateMatchInfo(match, coaches: coaches);
    _coachNameController.clear();
  }

  Future<void> _removeCoachFromMatch(
    MatchGame match,
    MatchCoach coach,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trainer entfernen?'),
        content: Text('„${coach.name}“ wird aus dieser Wertung entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final coaches = List<MatchCoach>.from(match.coaches)
      ..removeWhere((entry) => entry.id == coach.id);
    _updateMatchInfo(match, coaches: coaches);
  }

  void _updateTeamPlayerNumber(
      MatchGame match, MatchPlayer player, String value) {
    final number = int.tryParse(value.trim());
    if (number == null) return;
    _replaceMatch(match.copyWith(
      players: match.players
          .map((entry) =>
              entry.id == player.id ? entry.copyWith(number: number) : entry)
          .toList(),
      clearRotationSetup: !_matchHasScoredPoints(match),
    ));
  }

  Future<void> _syncTeamPlayerNumbers(MatchGame match) async {
    final teamId = match.teamId;
    if (teamId == null) return;
    final teams = await _teamsRepository.load();
    if (!mounted) return;
    final team = teams.cast<Team?>().firstWhere(
          (entry) => entry?.id == teamId,
          orElse: () => null,
        );
    if (team == null) return;
    setState(() {
      _teams
        ..clear()
        ..addAll(teams);
    });
    final updated = syncMatchPlayerNumbersFromTeam(match, team);
    for (final player in updated.players) {
      if (player.sourceTeamId == teamId) {
        _teamNumberControllers['${match.id}:${player.id}']?.text =
            player.number.toString();
      }
    }
    _replaceMatch(updated);
  }

  void _removePlayerFromMatch(MatchGame match, MatchPlayer player) {
    _confirmRemovePlayerFromMatch(match, player);
  }

  Future<void> _confirmRemovePlayerFromMatch(
    MatchGame match,
    MatchPlayer player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spieler entfernen?'),
        content: Text('„${player.name}“ und seine Wertungen werden entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final players = List<MatchPlayer>.from(match.players)
      ..removeWhere((entry) => entry.id == player.id);
    final events = List<MatchEvent>.from(match.events)
      ..removeWhere((event) => event.playerId == player.id);
    _replaceMatch(match.copyWith(players: players, events: events));
  }

  void _replaceMatch(MatchGame updated, {bool clearRedo = true}) {
    setState(() {
      if (clearRedo) _redoEventsByMatchId.remove(updated.id);
      final index = _matches.indexWhere((match) => match.id == updated.id);
      if (index >= 0) {
        _matches[index] = updated;
      } else {
        _matches.insert(0, updated);
      }
      _matches.sort(compareMatchesByGameTime);
      _selectedMatchId = updated.id;
    });
    unawaited(_persist());
  }

  Future<void> _deleteMatch(MatchGame match) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spiel löschen?'),
        content: Text(
          'Das Spiel${match.opponentTeam.isEmpty ? '' : ' gegen ${match.opponentTeam}'} wird unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB74D),
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() {
      _matches.removeWhere((entry) => entry.id == match.id);
      _selectedMatchId = null;
      _activeSection = null;
    });
    unawaited(_persist());
  }

  void _startEventSelection(MatchGame match, {required bool isPoint}) {
    _scoringSelectionTimer?.cancel();
    setState(() {
      _pendingEventKind = isPoint ? 'point' : 'error';
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
      _pendingScorerNumber = 0;
      _activeSection = 'category-selection';
    });
  }

  void _undoLastMatchAction(MatchGame match) {
    final action = lastMatchActionEvent(match);
    if (action == null) return;
    final updated = undoLastMatchAction(match);
    _redoEventsByMatchId
        .putIfAbsent(match.id, () => <MatchEvent>[])
        .add(action);
    _replaceMatch(updated, clearRedo: false);
  }

  void _redoLastMatchAction(MatchGame match) {
    final redoEvents = _redoEventsByMatchId[match.id];
    if (redoEvents == null || redoEvents.isEmpty) return;
    final event = redoEvents.removeLast();
    if (redoEvents.isEmpty) _redoEventsByMatchId.remove(match.id);
    _replaceMatch(
      match.copyWith(events: <MatchEvent>[...match.events, event]),
      clearRedo: false,
    );
  }

  void _cancelEventSelection() {
    _scoringSelectionTimer?.cancel();
    setState(() {
      _pendingEventKind = null;
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
      _pendingScorerNumber = 0;
      _activeSection = 'scoring';
    });
  }

  void _endSetManually(MatchGame match) {
    final sets = _computeSets(match);
    final currentSet = sets.lastOrNull;
    if (currentSet == null ||
        currentSet.isFinished ||
        (currentSet.us == 0 && currentSet.opponent == 0)) {
      return;
    }
    final events = List<MatchEvent>.from(match.events)
      ..add(
        MatchEvent(
          id: match.events.length + 1,
          playerId: null,
          playerName: 'Satzende',
          playerNumber: 0,
          kind: _manualSetEndKind,
          category: 'Manuell',
          occurredAt: DateTime.now(),
        ),
      );
    _replaceMatch(match.copyWith(events: events));
  }

  Future<void> _recordTimeout(MatchGame match) async {
    final teamTimeouts = match.events
        .where(
            (event) => event.kind == _timeoutKind && event.category == 'Team')
        .length;
    final opponentTimeouts = match.events
        .where(
            (event) => event.kind == _timeoutKind && event.category == 'Gegner')
        .length;
    final teamAvailable = teamTimeouts < 2;
    final opponentAvailable = opponentTimeouts < 2;
    final side = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auszeit nehmen'),
        content:
            const Text('Für welches Team soll die Auszeit notiert werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: teamAvailable
                ? () => Navigator.of(dialogContext).pop('Team')
                : null,
            style: FilledButton.styleFrom(
              disabledForegroundColor: Colors.red,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Text('Team ($teamTimeouts/2)'),
          ),
          FilledButton(
            onPressed: opponentAvailable
                ? () => Navigator.of(dialogContext).pop('Gegner')
                : null,
            style: FilledButton.styleFrom(
              disabledForegroundColor: Colors.red,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Text('Gegner ($opponentTimeouts/2)'),
          ),
        ],
      ),
    );

    if (side == null || !mounted) return;

    final events = List<MatchEvent>.from(match.events)
      ..add(
        MatchEvent(
          id: match.events.length + 1,
          playerId: null,
          playerName: side,
          playerNumber: 0,
          kind: _timeoutKind,
          category: side,
          occurredAt: DateTime.now(),
        ),
      );
    _replaceMatch(match.copyWith(events: events));
  }

  void _selectPlayerForEvent(MatchGame match, MatchPlayer player) {
    _selectScorerForEvent(
      match,
      scorerId: player.id,
      scorerName: player.name,
      scorerNumber: player.number,
    );
  }

  List<MatchPlayer> _fieldPlayersForScoring(MatchGame match) {
    return fieldPlayersForScoring(match);
  }

  void _selectSpecialScorer(MatchGame match, int scorerId) {
    final playerName =
        scorerId == _unknownScorerId ? 'Unbekannt' : 'Mannschaft';
    _selectScorerForEvent(
      match,
      scorerId: scorerId,
      scorerName: playerName,
      scorerNumber: 0,
    );
  }

  Future<void> _selectScorerForEvent(
    MatchGame match, {
    required int scorerId,
    required String scorerName,
    required int scorerNumber,
  }) async {
    final categories = _categoriesAtPendingPath();
    final mainCategory = (_pendingEventKind == 'point'
            ? _pointCategories
            : _errorCategories)
        .firstWhere((category) => category.label == _pendingCategoryPath.first);
    if (categories.isNotEmpty) {
      setState(() {
        _pendingScorerId = scorerId;
        _pendingScorerName = scorerName;
        _pendingScorerNumber = scorerNumber;
        _activeSection = 'category-selection';
      });
      _scheduleScoringSelectionTimeout(match);
      return;
    }

    var category = _pendingCategoryPath.join(' · ');
    if (mainCategory.requiresText) {
      _scoringSelectionTimer?.cancel();
      final details = await _requestOtherCategoryDetails();
      if (!mounted) return;
      if (details == _otherCategoryTimeoutResult) {
        _createMainCategoryEvent(match, scorerId, scorerName, scorerNumber);
        return;
      }
      if (details == null) {
        _scheduleScoringSelectionTimeout(match);
        return;
      }
      category = '$category: $details';
    }
    _createEvent(
      match,
      playerId: scorerId,
      playerName: scorerName,
      playerNumber: scorerNumber,
      category: category,
    );
  }

  Future<String?> _requestOtherCategoryDetails() async {
    final controller = TextEditingController();
    final navigator = Navigator.of(context);
    final timeout = Timer(_scoringSelectionTimeout, () {
      navigator.maybePop(_otherCategoryTimeoutResult);
    });
    final details = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sonstiges beschreiben'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Beschreibung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
    timeout.cancel();
    controller.dispose();
    if (!mounted || details == null || details.isEmpty) return details;
    return details;
  }

  void _scheduleScoringSelectionTimeout(MatchGame match) {
    _scoringSelectionTimer?.cancel();
    _scoringSelectionTimer = Timer(_scoringSelectionTimeout, () {
      if (!mounted || _pendingCategoryPath.isEmpty) return;
      final scorerId = _pendingScorerId ?? _unknownScorerId;
      final scorerName = _pendingScorerName ?? 'Unbekannt';
      final scorerNumber = _pendingScorerId == null ? 0 : _pendingScorerNumber;
      _createMainCategoryEvent(match, scorerId, scorerName, scorerNumber);
    });
  }

  void _createMainCategoryEvent(
    MatchGame match,
    int scorerId,
    String scorerName,
    int scorerNumber,
  ) {
    if (_pendingCategoryPath.isEmpty) return;
    _createEvent(
      match,
      playerId: scorerId,
      playerName: scorerName,
      playerNumber: scorerNumber,
      category: _pendingCategoryPath.first,
    );
  }

  List<_ScoringCategory> _categoriesAtPendingPath() {
    var categories =
        _pendingEventKind == 'point' ? _pointCategories : _errorCategories;
    for (final label in _pendingCategoryPath) {
      categories =
          categories.firstWhere((category) => category.label == label).children;
    }
    return categories;
  }

  Future<void> _selectCategoryForEvent(
    MatchGame match,
    _ScoringCategory selected,
  ) async {
    final path = <String>[..._pendingCategoryPath, selected.label];
    if (_pendingCategoryPath.isEmpty) {
      if (_pendingEventKind == 'point' &&
          selected.label == _opponentErrorCategory) {
        _createEvent(
          match,
          playerId: null,
          category: selected.label,
          playerName: 'Gegner',
          playerNumber: 0,
        );
        return;
      }
      setState(() {
        _pendingCategoryPath = path;
        _activeSection = 'player-selection';
      });
      _scheduleScoringSelectionTimeout(match);
      return;
    }

    if (selected.children.isNotEmpty) {
      setState(() => _pendingCategoryPath = path);
      _scheduleScoringSelectionTimeout(match);
      return;
    }

    var category = path.join(' · ');
    if (selected.requiresText) {
      _scoringSelectionTimer?.cancel();
      final details = await _requestOtherCategoryDetails();
      if (!mounted) return;
      if (details == _otherCategoryTimeoutResult) {
        _createMainCategoryEvent(
          match,
          _pendingScorerId ?? _unknownScorerId,
          _pendingScorerName ?? 'Unbekannt',
          _pendingScorerNumber,
        );
        return;
      }
      if (details == null) {
        _scheduleScoringSelectionTimeout(match);
        return;
      }
      category = '$category: $details';
    }

    _createEvent(
      match,
      playerId: _pendingScorerId,
      playerName: _pendingScorerName,
      playerNumber: _pendingScorerNumber,
      category: category,
    );
  }

  void _createEvent(
    MatchGame match, {
    required int? playerId,
    required String category,
    String? playerName,
    int? playerNumber,
  }) {
    _scoringSelectionTimer?.cancel();
    final player = match.players.cast<MatchPlayer?>().firstWhere(
          (entry) => entry?.id == playerId,
          orElse: () => null,
        );
    final displayName = playerName ??
        (player != null ? _displayPlayerName(match, player) : 'Unbekannt');
    final displayNumber = playerNumber ?? player?.number ?? 0;

    final events = List<MatchEvent>.from(match.events)
      ..add(
        MatchEvent(
          id: match.events.length + 1,
          playerId: playerId,
          playerName: displayName,
          playerNumber: displayNumber,
          kind: _pendingEventKind ?? 'point',
          category: category,
          occurredAt: DateTime.now(),
        ),
      );
    _replaceMatch(match.copyWith(events: events));
    setState(() {
      _pendingEventKind = null;
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
      _pendingScorerNumber = 0;
      _activeSection = 'scoring';
    });
  }

  void _bookPendingEventAsUnknown(MatchGame match) {
    _selectSpecialScorer(match, _unknownScorerId);
  }

  void _backFromPlayerSelection() {
    _scoringSelectionTimer?.cancel();
    if (_pendingCategoryPath.isEmpty) {
      _cancelEventSelection();
      return;
    }
    setState(() {
      _pendingCategoryPath = <String>[];
      _pendingScorerId = null;
      _pendingScorerName = null;
      _pendingScorerNumber = 0;
      _activeSection = 'category-selection';
    });
  }

  void _backToScorerSelection(MatchGame match) {
    setState(() => _activeSection = 'player-selection');
    _scheduleScoringSelectionTimeout(match);
  }

  Map<String, int> _pointSummary(MatchGame match) {
    final summary = <String, int>{};
    for (final event in match.events.where((entry) => entry.kind == 'point')) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  Map<String, int> _errorSummary(MatchGame match) {
    final summary = <String, int>{};
    for (final event in match.events.where((entry) => entry.kind == 'error')) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  List<String> _categoriesInMatch(MatchGame match, String kind) => match.events
      .where((event) => event.kind == kind)
      .map((event) => event.category)
      .toSet()
      .toList();

  List<DateTime> _timeoutMarkers(MatchGame match) {
    return match.events
        .where((event) => event.kind == _timeoutKind)
        .map((event) => event.occurredAt)
        .toList();
  }

  // Replays events chronologically: 'point' scores for us, 'error' scores for
  // the opponent, sets end at 25 with two points lead (same rule as the
  // scoreboard).
  List<_SetScore> _computeSets(MatchGame match) {
    final sortedEvents = List<MatchEvent>.from(match.events)
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final sets = <_SetScore>[];
    var us = 0;
    var opponent = 0;
    for (final event in sortedEvents) {
      if (event.kind == 'point') {
        us++;
      } else if (event.kind == 'error') {
        opponent++;
      }
      if (event.kind == _manualSetEndKind && (us > 0 || opponent > 0)) {
        sets.add(_SetScore(us: us, opponent: opponent, isFinished: true));
        us = 0;
        opponent = 0;
        continue;
      }
      final usWon = us >= 25 && us - opponent >= 2;
      final opponentWon = opponent >= 25 && opponent - us >= 2;
      if (usWon || opponentWon) {
        sets.add(_SetScore(us: us, opponent: opponent, isFinished: true));
        us = 0;
        opponent = 0;
      }
    }
    if (us > 0 || opponent > 0) {
      sets.add(_SetScore(us: us, opponent: opponent, isFinished: false));
    }
    return sets;
  }

  Map<String, int> _playerSummary(
    MatchGame match,
    int playerId, {
    required String kind,
  }) {
    final summary = <String, int>{};
    final specialName = switch (playerId) {
      _unknownScorerId => 'Unbekannt',
      _teamScorerId => 'Mannschaft',
      _ => null,
    };
    for (final event in match.events.where(
      (entry) =>
          entry.kind == kind &&
          (entry.playerId == playerId ||
              (specialName != null &&
                  entry.playerId == null &&
                  entry.playerName == specialName)),
    )) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const PopScope(
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final selectedMatch = _selectedMatch;
    final Widget page;
    if (_activeSection == 'multi-stats' && _selectedMatches.isNotEmpty) {
      final selectedMatches = _selectedMatches;
      page = _buildStatsView(
        _combinedStatsMatch(selectedMatches),
        title: 'Statistik · ${selectedMatches.length} Spiele',
        onBack: _handleSystemBack,
        showSets: false,
        sourceMatches: selectedMatches,
      );
    } else if (selectedMatch != null && _activeSection == null) {
      page = _buildMatchDetailView(selectedMatch);
    } else if (selectedMatch != null && _activeSection == 'info') {
      page = _buildMatchInfoView(selectedMatch);
    } else if (selectedMatch != null && _activeSection == 'scoring') {
      page = _buildScoringView(selectedMatch);
    } else if (selectedMatch != null && _activeSection == 'player-selection') {
      page = _buildPlayerSelectionView(selectedMatch);
    } else if (selectedMatch != null &&
        _activeSection == 'category-selection') {
      page = _buildCategorySelectionView(selectedMatch);
    } else if (selectedMatch != null && _activeSection == 'stats') {
      page = _buildStatsView(selectedMatch);
    } else {
      page = _buildMatchListView();
    }
    final scoringPage = selectedMatch != null && _activeSection == 'scoring'
        ? Actions(
            actions: <Type, Action<Intent>>{
              _UndoScoringIntent: CallbackAction<_UndoScoringIntent>(
                onInvoke: (_) {
                  _undoLastMatchAction(_selectedMatch ?? selectedMatch);
                  return null;
                },
              ),
              _RedoScoringIntent: CallbackAction<_RedoScoringIntent>(
                onInvoke: (_) {
                  _redoLastMatchAction(_selectedMatch ?? selectedMatch);
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                ): const _UndoScoringIntent(),
                const SingleActivator(
                  LogicalKeyboardKey.keyY,
                  control: true,
                ): const _RedoScoringIntent(),
                const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                  shift: true,
                ): const _RedoScoringIntent(),
              },
              child: Focus(autofocus: true, child: page),
            ),
          )
        : page;
    return PopScope(
      canPop: _selectedMatchId == null && _activeSection != 'multi-stats',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: scoringPage,
    );
  }

  Widget _buildMatchListView() {
    final matches = List<MatchGame>.from(_matches)
      ..sort(compareMatchesByGameTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedMatchIds.isEmpty
              ? 'Punktewertung'
              : '${_selectedMatchIds.length} Spiele ausgewählt',
        ),
        actions: [
          if (_selectedMatchIds.isNotEmpty) ...[
            IconButton(
              key: const ValueKey('multi-match-statistics-button'),
              tooltip: 'Statistik für ${_selectedMatchIds.length} Spiele',
              icon: const Icon(Icons.bar_chart),
              onPressed: _openCombinedStats,
            ),
            IconButton(
              key: const ValueKey('export-selected-matches-button'),
              tooltip: '${_selectedMatchIds.length} Spiele exportieren',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () =>
                  AppBackupService.shareMatches(context, _selectedMatches),
            ),
            IconButton(
              key: const ValueKey('clear-match-selection-button'),
              tooltip: 'Auswahl aufheben',
              icon: const Icon(Icons.close),
              onPressed: _clearMatchSelection,
            ),
          ],
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.upload_outlined),
            onPressed: _importBackup,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactActions = constraints.maxWidth < 1000;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    key: const ValueKey('new-game-button'),
                    leading: const CircleAvatar(
                      child: Icon(Icons.add),
                    ),
                    title: const Text('Neues Spiel erfassen'),
                    subtitle: const Text('Spielinfos anlegen'),
                    onTap: _openNewMatchForm,
                  ),
                ),
                const SizedBox(height: 12),
                if (matches.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Noch keine Spiele erfasst.'),
                    ),
                  )
                else
                  for (final match in matches)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        key: ValueKey('match-row-${match.id}'),
                        leading: _selectedMatchIds.isEmpty
                            ? _buildMatchIcon(context, match)
                            : Checkbox(
                                key: ValueKey(
                                  'select-match-${match.id}',
                                ),
                                value: _selectedMatchIds.contains(match.id),
                                onChanged: (_) =>
                                    _toggleMatchSelection(match.id),
                              ),
                        title: Text(
                          match.opponentTeam.isEmpty
                              ? 'Neues Spiel'
                              : 'vs. ${match.opponentTeam}',
                        ),
                        subtitle: Text(
                          '${match.matchType} • ${_formatDateTime(match.matchDateTime)} • ${match.matchTag.isEmpty ? 'Ohne Stichwort' : match.matchTag} • ${match.location.isEmpty ? 'Ort offen' : match.location}',
                        ),
                        trailing: _selectedMatchIds.isNotEmpty
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (compactActions)
                                    PopupMenuButton<String>(
                                      tooltip: 'Weitere Aktionen',
                                      onSelected: (_) =>
                                          AppBackupService.shareMatch(
                                              context, match),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.share_outlined,
                                                  color: Theme.of(context)
                                                      .iconTheme
                                                      .color),
                                              const SizedBox(width: 12),
                                              Text('Spiel teilen'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    IconButton(
                                      tooltip: 'Spiel teilen',
                                      icon: const Icon(Icons.share_outlined),
                                      onPressed: () =>
                                          AppBackupService.shareMatch(
                                              context, match),
                                    ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                        selected: _selectedMatchIds.contains(match.id),
                        onLongPress: () => _toggleMatchSelection(match.id),
                        onTap: _selectedMatchIds.isNotEmpty
                            ? () => _toggleMatchSelection(match.id)
                            : () => _showMatchDetail(match.id),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMatchDetailView(MatchGame match) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            match.opponentTeam.isEmpty ? 'Spiel' : 'vs. ${match.opponentTeam}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeMatchDetail,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DetailTile(
              title: 'Spielinfos',
              subtitle:
                  '${match.matchType} • ${match.location.isEmpty ? 'Ort offen' : match.location}',
              icon: Icons.info_outline,
              onTap: () => _showMatchDetail(match.id, section: 'info'),
            ),
            const SizedBox(height: 12),
            _DetailTile(
              title: 'Punktewertung',
              subtitle:
                  '${match.players.length} Spieler • ${match.events.length} Einträge',
              icon: Icons.sports_volleyball,
              onTap: () => _showMatchDetail(match.id, section: 'scoring'),
            ),
            const SizedBox(height: 12),
            _DetailTile(
              title: 'Statistik',
              subtitle: 'Punkte und Fehler nach Art',
              icon: Icons.bar_chart,
              onTap: () => _showMatchDetail(match.id, section: 'stats'),
            ),
            const SizedBox(height: 12),
            _DetailTile(
              title: 'Verlauf',
              subtitle:
                  '${match.events.length} Einträge chronologisch anzeigen',
              icon: Icons.history,
              onTap: () => _openMatchHistory(match),
            ),
            const SizedBox(height: 12),
            _DetailTile(
              title: 'Spiel löschen',
              subtitle: 'Spiel und Statistik unwiderruflich entfernen',
              icon: Icons.delete_outline,
              color: const Color(0xFFFFB74D),
              onTap: () => _deleteMatch(match),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoView(MatchGame match) {
    final selectedTeam = match.teamId == null
        ? null
        : _teams.cast<Team?>().firstWhere(
              (team) => team?.id == match.teamId,
              orElse: () => null,
            );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielinfos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showMatchDetail(match.id),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('match-location-input'),
              controller: _locationController,
              onChanged: (value) =>
                  _updateMatchInfo(match, location: value.trim()),
              decoration: const InputDecoration(
                labelText: 'Spielort',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const ValueKey('match-team-select'),
              initialValue: match.teamId,
              decoration: const InputDecoration(
                labelText: 'Eigenes Team',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Kein Team auswählen'),
                ),
                ..._teams.map(
                  (team) => DropdownMenuItem<int?>(
                    value: team.id,
                    child: Text(
                        team.name.isEmpty ? 'Unbenanntes Team' : team.name),
                  ),
                ),
              ],
              onChanged: (teamId) => _selectTeam(match, teamId),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('match-league-select'),
              initialValue: match.league.isEmpty ? null : match.league,
              decoration: const InputDecoration(
                labelText: 'Spielklasse',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Keine Spielklasse auswählen'),
                ),
                ..._leagues.map(
                  (league) => DropdownMenuItem<String?>(
                    value: league,
                    child: Text(league),
                  ),
                ),
              ],
              onChanged: (league) =>
                  _updateMatchInfo(match, league: league ?? ''),
            ),
            const SizedBox(height: 12),
            if (selectedTeam != null) ...[
              const Text(
                'Trainer beim Spiel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (selectedTeam.coaches.isEmpty)
                const Text('Im ausgewählten Team sind keine Trainer angelegt.')
              else
                for (final coach in selectedTeam.coaches)
                  Row(
                    children: [
                      Checkbox(
                        key: ValueKey('select-match-coach-${coach.id}'),
                        value:
                            match.coaches.any((entry) => entry.id == coach.id),
                        onChanged: (selected) =>
                            _toggleCoach(match, coach, selected ?? false),
                      ),
                      Expanded(child: Text(coach.name)),
                    ],
                  ),
            ],
            if (selectedTeam != null) const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filled(
                  key: const ValueKey('add-coach-button'),
                  onPressed: () => _addCoachToMatch(match),
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Trainer hinzufügen',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('coach-name-input'),
                    controller: _coachNameController,
                    decoration: const InputDecoration(
                      labelText: 'Trainername',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            for (final coach in match.coaches.where(
              (entry) =>
                  selectedTeam?.coaches.every(
                    (teamCoach) => teamCoach.id != entry.id,
                  ) ??
                  true,
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(coach.name),
                subtitle: const Text('Zusätzlicher Trainer'),
                trailing: IconButton(
                  onPressed: () => _removeCoachFromMatch(match, coach),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Trainer entfernen',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('match-opponent-input'),
              controller: _opponentController,
              onChanged: (value) =>
                  _updateMatchInfo(match, opponentTeam: value.trim()),
              decoration: const InputDecoration(
                labelText: 'Gegnerteam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: match.matchType,
              decoration: const InputDecoration(
                labelText: 'Spieltyp',
                border: OutlineInputBorder(),
              ),
              items: _matchTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateMatchInfo(match, matchType: value);
                }
              },
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Datum',
                border: OutlineInputBorder(),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(_formatDate(match.matchDateTime)),
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: match.matchDateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selectedDate != null && mounted) {
                    _updateMatchInfo(
                      match,
                      matchDateTime: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        match.matchDateTime.hour,
                        match.matchDateTime.minute,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Uhrzeit',
                border: OutlineInputBorder(),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(_formatTime(match.matchDateTime)),
                onTap: () async {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(match.matchDateTime),
                  );
                  if (selectedTime != null && mounted) {
                    _updateMatchInfo(
                      match,
                      matchDateTime: DateTime(
                        match.matchDateTime.year,
                        match.matchDateTime.month,
                        match.matchDateTime.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('match-tag-input'),
              controller: _matchTagController,
              onChanged: (value) =>
                  _updateMatchInfo(match, matchTag: value.trim()),
              decoration: const InputDecoration(
                labelText: 'Spieltag / Stichwort',
                hintText: 'z. B. Samstag, Liga, Testspiel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
                label: 'Angelegt', value: _formatDateTime(match.createdAt)),
            const SizedBox(height: 24),
            const Text(
              'Team / Spieler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPlayerEditor(match),
            const SizedBox(height: 16),
            _buildRotationSetupButton(match),
          ],
        ),
      ),
    );
  }

  ScoreboardRotationState _initialRotationForMatch(MatchGame match) {
    final league = _leagues.contains(match.league) ? match.league : 'Herren';
    final count = rotationPlayerCount(league);
    final team = _teams.cast<Team?>().firstWhere(
          (entry) => entry?.id == match.teamId,
          orElse: () => null,
        );
    final players = match.players
        .map(
          (player) => RotationPlayer(
            id: 'match-${player.id}',
            name: _displayPlayerName(match, player),
            number: player.number > 0 ? player.number : null,
          ),
        )
        .toList();
    return ScoreboardRotationState(
      league: league,
      left: RotationTeamState(
        name: team?.name ?? 'Eigenes Team',
        players: players,
        positions: List<String?>.generate(
          count,
          (index) => index < players.length ? players[index].id : null,
        ),
      ),
      right: RotationTeamState(
        name: match.opponentTeam,
        positions: List<String?>.filled(count, null),
      ),
      servingSide: 0,
    );
  }

  Future<void> _configureMatchRotation(MatchGame match) async {
    final initial = match.rotationSetup ?? _initialRotationForMatch(match);
    final updated = await Navigator.of(context).push<ScoreboardRotationState>(
      MaterialPageRoute<ScoreboardRotationState>(
        builder: (_) => RotationSetupPage(
          database: widget.database,
          initial: initial,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _replaceMatch(match.copyWith(rotationSetup: updated));
  }

  bool _matchHasScoredPoints(MatchGame match) => match.events.any(
        (event) => event.kind == 'point' || event.kind == 'error',
      );

  Widget _buildRotationSetupButton(MatchGame match) {
    return OutlinedButton.icon(
      key: const ValueKey('match-rotation-setup-button'),
      onPressed: _matchHasScoredPoints(match)
          ? null
          : () => _configureMatchRotation(match),
      icon: const Icon(Icons.rotate_right),
      label: Text(
        match.rotationSetup == null
            ? 'Startaufstellung und Rotation festlegen'
            : 'Startaufstellung bearbeiten',
      ),
    );
  }

  ScoreboardRotationState? _rotationAfterEvents(MatchGame match) {
    return rotationAfterMatchEvents(match);
  }

  Widget _buildMatchRotation(MatchGame match) {
    final rotation = _rotationAfterEvents(match)!;
    final sourceTeam = match.teamId == null
        ? null
        : _teams.cast<Team?>().firstWhere(
              (entry) => entry?.id == match.teamId,
              orElse: () => null,
            );
    return MatchRotationView(
      rotation: rotation,
      teamName: rotation.left.name,
      teamColor: sourceTeam?.primaryColorValue == null
          ? const Color(0xFF1976D2)
          : Color(sourceTeam!.primaryColorValue!),
      showOnLeft: match.rotationIsOnLeft,
      onSideChanged: (showOnLeft) => _replaceMatch(
        match.copyWith(rotationIsOnLeft: showOnLeft),
      ),
      onSubstitute: (position) => _chooseSubstituteForPosition(match, position),
      onEdit: _matchHasScoredPoints(match)
          ? null
          : () => _configureMatchRotation(match),
    );
  }

  Future<void> _chooseSubstituteForPosition(
    MatchGame match,
    int position,
  ) async {
    final rotation = _rotationAfterEvents(match);
    if (rotation == null) return;
    final activeRotationIds = rotation.left.positions.toSet();
    final benchPlayers = match.players
        .where((player) => !activeRotationIds.contains('match-${player.id}'))
        .toList();
    if (benchPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine weiteren Bankspieler verfügbar.')),
      );
      return;
    }

    final selectedPlayer = await showModalBottomSheet<MatchPlayer>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('Einwechseln auf Position ${position + 1}')),
            for (final player in benchPlayers)
              ListTile(
                key: ValueKey('substitute-match-player-${player.id}'),
                leading: CircleAvatar(child: Text('${player.number}')),
                title: Text(player.name),
                subtitle: const Text('Bank'),
                onTap: () => Navigator.of(sheetContext).pop(player),
              ),
          ],
        ),
      ),
    );
    if (selectedPlayer == null || !mounted) return;

    final events = List<MatchEvent>.from(match.events)
      ..add(
        MatchEvent(
          id: match.events.length + 1,
          playerId: selectedPlayer.id,
          playerName: selectedPlayer.name,
          playerNumber: selectedPlayer.number,
          kind: 'substitution',
          category: 'Spielerwechsel',
          occurredAt: DateTime.now(),
          rotationPosition: position,
        ),
      );
    _replaceMatch(match.copyWith(events: events));
  }

  Widget _buildPlayerEditor(MatchGame match) {
    final team = match.teamId == null
        ? null
        : _teams.cast<Team?>().firstWhere(
              (entry) => entry?.id == match.teamId,
              orElse: () => null,
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (team != null) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kader für dieses Spiel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                key: const ValueKey('sync-team-player-numbers'),
                tooltip: 'Trikotnummern aus Team übernehmen',
                onPressed: () => _syncTeamPlayerNumbers(match),
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (team.players.isEmpty)
            const Text('Im ausgewählten Team sind noch keine Spieler angelegt.')
          else
            for (final teamPlayer in team.players)
              Builder(
                builder: (context) {
                  final matchPlayer =
                      match.players.cast<MatchPlayer?>().firstWhere(
                            (entry) =>
                                entry?.sourceTeamId == team.id &&
                                entry?.teamPlayerId == teamPlayer.id,
                            orElse: () => null,
                          );
                  final isSelected = matchPlayer != null;
                  return Row(
                    children: [
                      Checkbox(
                        key: ValueKey('select-team-player-${teamPlayer.id}'),
                        value: isSelected,
                        onChanged: (selected) => _toggleTeamPlayer(
                          match,
                          teamPlayer,
                          selected ?? false,
                        ),
                      ),
                      Expanded(child: Text(teamPlayer.name)),
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          key: ValueKey('team-player-number-${teamPlayer.id}'),
                          enabled: isSelected,
                          controller: matchPlayer == null
                              ? null
                              : _teamPlayerNumberController(match, matchPlayer),
                          initialValue: matchPlayer == null
                              ? teamPlayer.number?.toString() ?? ''
                              : null,
                          keyboardType: TextInputType.number,
                          onFieldSubmitted: (value) {
                            if (matchPlayer != null) {
                              _updateTeamPlayerNumber(
                                  match, matchPlayer, value);
                            }
                          },
                          onTapOutside: (_) {
                            if (matchPlayer != null) {
                              _updateTeamPlayerNumber(
                                match,
                                matchPlayer,
                                _teamPlayerNumberController(match, matchPlayer)
                                    .text,
                              );
                            }
                          },
                          decoration: const InputDecoration(labelText: 'Nr.'),
                        ),
                      ),
                    ],
                  );
                },
              ),
          const Divider(height: 32),
        ],
        Row(
          children: [
            IconButton.filled(
              key: const ValueKey('add-player-button'),
              onPressed: () => _addPlayerToMatch(match),
              style: IconButton.styleFrom(
                backgroundColor: AppPalette.green,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                _editingMatchPlayerId == null ? Icons.add : Icons.save,
                color: Colors.white,
              ),
              tooltip: _editingMatchPlayerId == null
                  ? 'Spieler hinzufügen'
                  : 'Spieler speichern',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey('player-name-input'),
                controller: _playerNameController,
                decoration: const InputDecoration(
                  labelText: 'Spielername',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: TextField(
                key: const ValueKey('player-number-input'),
                controller: _playerNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nr.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_editingMatchPlayerId != null)
              IconButton(
                key: const ValueKey('cancel-edit-match-player'),
                tooltip: 'Bearbeitung abbrechen',
                onPressed: _cancelEditingMatchPlayer,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (match.players.isEmpty)
          const Text('Noch keine Spieler angelegt.')
        else
          for (final player in match.players)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(player.name),
              subtitle: Text('Trikot ${player.number}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('edit-match-player-${player.id}'),
                    onPressed: () => _startEditingMatchPlayer(player),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Spieler bearbeiten',
                  ),
                  IconButton(
                    onPressed: () => _removePlayerFromMatch(match, player),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Spieler entfernen',
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildScoringView(MatchGame match) {
    final sets = _computeSets(match);
    final teamTimeouts = match.events
        .where(
            (event) => event.kind == _timeoutKind && event.category == 'Team')
        .length;
    final opponentTimeouts = match.events
        .where(
            (event) => event.kind == _timeoutKind && event.category == 'Gegner')
        .length;
    final timeoutsAvailable = teamTimeouts < 2 || opponentTimeouts < 2;
    final scoreSets = sets.isEmpty
        ? const <_SetScore>[
            _SetScore(us: 0, opponent: 0, isFinished: false),
          ]
        : sets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punktewertung'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showMatchDetail(match.id),
        ),
        actions: [
          IconButton(
            key: const ValueKey('undo-last-match-action'),
            tooltip: 'Rückgängig (Ctrl+Z)',
            onPressed: lastMatchActionEvent(match) == null
                ? null
                : () => _undoLastMatchAction(match),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const ValueKey('redo-last-match-action'),
            tooltip: 'Wiederholen (Ctrl+Y)',
            onPressed: _redoEventsByMatchId[match.id]?.isNotEmpty == true
                ? () => _redoLastMatchAction(match)
                : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            key: const ValueKey('match-history-appbar-button'),
            icon: const Icon(Icons.history),
            tooltip: 'Verlauf',
            onPressed: () => _openMatchHistory(match),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _ClockTile(clockText: _clockText)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StopwatchTile(
                      stopwatchText: _stopwatchTextFor(match),
                      stopwatchRunning: match.stopwatchRunning,
                      onToggle: () => _toggleStopwatch(match),
                      onReset: () => _resetStopwatch(match),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 140,
                child: FilledButton.icon(
                  key: const ValueKey('record-point-button'),
                  onPressed: () => _startEventSelection(match, isPoint: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFaed581),
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontFamily:
                          Theme.of(context).textTheme.labelLarge?.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle, size: 40),
                  label: const Text('Punkt'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 140,
                child: FilledButton.icon(
                  key: const ValueKey('record-error-button'),
                  onPressed: () => _startEventSelection(match, isPoint: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFe57373),
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontFamily:
                          Theme.of(context).textTheme.labelLarge?.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.error_outline, size: 40),
                  label: const Text('Fehler'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 92,
                child: FilledButton.icon(
                  key: const ValueKey('record-timeout-button'),
                  onPressed:
                      timeoutsAvailable ? () => _recordTimeout(match) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFfff176),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.red,
                    textStyle: TextStyle(
                      fontFamily:
                          Theme.of(context).textTheme.labelLarge?.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.schedule, size: 40),
                  label: Text(
                    'Auszeit\n$teamTimeouts:$opponentTimeouts',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('finish-set-button'),
                  onPressed: () => _endSetManually(match),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Satz beenden'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SetsTile(sets: scoreSets)),
                  const SizedBox(width: 12),
                  Expanded(child: _PointsTile(sets: scoreSets)),
                ],
              ),
              const SizedBox(height: 20),
              if (match.rotationSetup == null)
                _buildRotationSetupButton(match)
              else
                _buildMatchRotation(match),
            ],
          ),
        ),
      ),
    );
  }

  void _openMatchHistory(MatchGame match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MatchHistoryPage(
          match: match,
          onMatchChanged: _replaceMatch,
        ),
      ),
    );
  }

  Widget _buildPlayerSelectionView(MatchGame match) {
    final fieldPlayers = _fieldPlayersForScoring(match);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler buchen'),
        leading: IconButton(
          tooltip: 'Zur Hauptkategorie',
          icon: const Icon(Icons.arrow_back),
          onPressed: _backFromPlayerSelection,
        ),
        actions: [
          IconButton(
            key: const ValueKey('book-unknown-scorer'),
            tooltip: 'Ohne Spieler als Unbekannt buchen',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () => _bookPendingEventAsUnknown(match),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: fieldPlayers.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == fieldPlayers.length) {
              return _specialScorerCard(
                key: const ValueKey('select-scorer-unknown'),
                icon: Icons.person_search_outlined,
                title: 'Unbekannt',
                onTap: () => _selectSpecialScorer(match, _unknownScorerId),
              );
            }
            if (index == fieldPlayers.length + 1) {
              return _specialScorerCard(
                key: const ValueKey('select-scorer-team'),
                icon: Icons.groups_outlined,
                title: 'Mannschaft',
                onTap: () => _selectSpecialScorer(match, _teamScorerId),
              );
            }

            final player = fieldPlayers[index];
            return SizedBox(
              width: double.infinity,
              height: 140,
              child: Card(
                child: InkWell(
                  key: ValueKey('select-player-${player.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectPlayerForEvent(match, player),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _displayPlayerName(match, player),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Trikot ${player.number}'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _specialScorerCard({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 112,
      child: Card(
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 12),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelectionView(MatchGame match) {
    final isPoint = _pendingEventKind == 'point';
    final categories = _categoriesAtPendingPath();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pendingCategoryPath.isEmpty
              ? isPoint
                  ? 'Punktart auswählen'
                  : 'Fehler auswählen'
              : _pendingScorerId != null
                  ? '${_pendingCategoryPath.last} spezifizieren'
                  : _pendingCategoryPath.last,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _pendingCategoryPath.isEmpty
              ? _cancelEventSelection
              : _pendingScorerId != null && _pendingCategoryPath.length == 1
                  ? () => _backToScorerSelection(match)
                  : () => setState(() {
                        _pendingCategoryPath = _pendingCategoryPath.sublist(
                            0, _pendingCategoryPath.length - 1);
                      }),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryPath = <String>[
              ..._pendingCategoryPath,
              category.label,
            ];
            return SizedBox(
              width: double.infinity,
              height: 140,
              child: Card(
                child: InkWell(
                  key: ValueKey(
                    'select-category-${categoryPath.join('-')}',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectCategoryForEvent(match, category),
                  child: Center(
                    child: ListTile(
                      title: Text(
                        category.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing:
                          category.children.isNotEmpty || category.requiresText
                              ? const Icon(Icons.chevron_right)
                              : null,
                      minVerticalPadding: 24,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsView(
    MatchGame match, {
    String title = 'Statistik',
    VoidCallback? onBack,
    bool showSets = true,
    List<MatchGame>? sourceMatches,
  }) {
    final statisticsMatch = _matchWithAggregateScorerRows(match);
    final points = _pointSummary(match);
    final errors = _errorSummary(match);
    final sets = _computeSets(match);
    final matchTimes = sourceMatches == null
        ? const <DateTime>[]
        : (sourceMatches
            .map((sourceMatch) {
              final eventTimes = sourceMatch.events
                  .where(
                      (event) => event.kind == 'point' || event.kind == 'error')
                  .map((event) => event.occurredAt)
                  .toList()
                ..sort();
              return eventTimes.firstOrNull;
            })
            .whereType<DateTime>()
            .toList()
          ..sort());
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => _showMatchDetail(match.id),
        ),
        actions: [
          IconButton(
            key: const ValueKey('export-match-stats-pdf'),
            tooltip: 'Statistik als PDF exportieren',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportStatisticsPdf(
              statisticsMatch,
              title: title,
              sourceMatches: sourceMatches,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (sourceMatches != null && sourceMatches.isNotEmpty) ...[
              _SelectedMatchesSummary(matches: sourceMatches),
              const SizedBox(height: 12),
            ],
            if (showSets && sets.isNotEmpty) ...[
              _SetsOverview(sets: sets),
              const SizedBox(height: 12),
            ],
            _StatGroup(title: 'Punkte pro Art', entries: points),
            const SizedBox(height: 12),
            _StatGroup(title: 'Fehler pro Art', entries: errors),
            const SizedBox(height: 12),
            _TrendChartCard(
              title: 'Zeitverlauf gesamt',
              samples: _trendSamples(match),
              timeoutMarkers: _timeoutMarkers(match),
              matchTimes: matchTimes,
              height: 220,
            ),
            const SizedBox(height: 12),
            if (statisticsMatch.players.isNotEmpty) ...[
              const Text(
                'Spielerübersicht',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _PlayerStatsTable(
                title: 'Punkte pro Spieler',
                categories: _categoriesInMatch(statisticsMatch, 'point'),
                players: statisticsMatch.players,
                summaryFor: (player) =>
                    _playerSummary(match, player.id, kind: 'point'),
              ),
              const SizedBox(height: 12),
              _PlayerStatsTable(
                title: 'Fehler pro Spieler',
                categories: _categoriesInMatch(statisticsMatch, 'error'),
                players: statisticsMatch.players,
                summaryFor: (player) =>
                    _playerSummary(match, player.id, kind: 'error'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Zeitverlauf pro Spieler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final player in statisticsMatch.players) ...[
                _TrendChartCard(
                  title: player.name,
                  samples: _trendSamples(match, playerId: player.id),
                  timeoutMarkers: _timeoutMarkers(match),
                  matchTimes: matchTimes,
                  height: 180,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportStatisticsPdf(
    MatchGame match, {
    required String title,
    List<MatchGame>? sourceMatches,
  }) async {
    try {
      final landscape = await showModalBottomSheet<bool>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.stay_current_portrait_outlined),
                title: const Text('Hochformat'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
              ListTile(
                leading: const Icon(Icons.stay_current_landscape_outlined),
                title: const Text('Querformat'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      );
      if (landscape == null || !mounted) return;
      await AppBackupService.exportMatchStatsPdf(
        context,
        match,
        title: title,
        sourceMatches: sourceMatches,
        landscape: landscape,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF konnte nicht erstellt werden: $error')),
      );
    }
  }

  List<_TrendSample> _trendSamples(MatchGame match, {int? playerId}) {
    final events = match.events
        .where((event) => playerId == null || event.playerId == playerId)
        .toList()
      ..sort((a, b) {
        final timeComparison = a.occurredAt.compareTo(b.occurredAt);
        if (timeComparison != 0) return timeComparison;
        return a.id.compareTo(b.id);
      });

    if (events.isEmpty) {
      return const <_TrendSample>[];
    }

    final samples = <_TrendSample>[
      _TrendSample(
        time: events.first.occurredAt,
        points: 0,
        errors: 0,
        opponentErrors: 0,
      ),
    ];
    var points = 0;
    var errors = 0;
    var opponentErrors = 0;
    for (final event in events) {
      if (event.kind == 'point') {
        points++;
        if (event.category == _opponentErrorCategory) opponentErrors++;
      } else if (event.kind == 'error') {
        errors++;
      }
      samples.add(
        _TrendSample(
          time: event.occurredAt,
          points: points,
          errors: errors,
          opponentErrors: opponentErrors,
        ),
      );
    }
    return samples;
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} ${_formatTime(value)}';
  }

  String get _clockText {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Duration _stopwatchDurationFor(MatchGame match) {
    if (match.stopwatchRunning && match.stopwatchStartedAt != null) {
      return match.stopwatchElapsed +
          _now.difference(match.stopwatchStartedAt!);
    }
    return match.stopwatchElapsed;
  }

  String _stopwatchTextFor(MatchGame match) {
    final total = _stopwatchDurationFor(match);
    final mm = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _toggleStopwatch(MatchGame match) {
    if (match.stopwatchRunning) {
      _replaceMatch(
        match.copyWith(
          stopwatchElapsed: _stopwatchDurationFor(match),
          stopwatchRunning: false,
          clearStopwatchStartedAt: true,
        ),
      );
    } else {
      _replaceMatch(
        match.copyWith(
          stopwatchRunning: true,
          stopwatchStartedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _resetStopwatch(MatchGame match) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stoppuhr zurücksetzen?'),
        content: const Text('Die Stoppuhr wird auf 00:00 zurückgesetzt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    _replaceMatch(
      match.copyWith(
        stopwatchElapsed: Duration.zero,
        stopwatchRunning: false,
        clearStopwatchStartedAt: true,
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scoringSelectionTimer?.cancel();
    _playerNameController.dispose();
    _playerNumberController.dispose();
    _coachNameController.dispose();
    _locationController.dispose();
    _opponentController.dispose();
    _matchTagController.dispose();
    for (final controller in _teamNumberControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class MatchRotationView extends StatefulWidget {
  const MatchRotationView({
    super.key,
    required this.rotation,
    required this.teamName,
    this.teamColor = const Color(0xFF1976D2),
    this.showOnLeft = true,
    this.onSideChanged,
    this.onSubstitute,
    this.onEdit,
  });

  final ScoreboardRotationState rotation;
  final String teamName;
  final Color teamColor;
  final bool showOnLeft;
  final ValueChanged<bool>? onSideChanged;
  final ValueChanged<int>? onSubstitute;
  final VoidCallback? onEdit;

  @override
  State<MatchRotationView> createState() => _MatchRotationViewState();
}

class _MatchRotationViewState extends State<MatchRotationView> {
  late bool _showOnLeft = widget.showOnLeft;

  @override
  void didUpdateWidget(covariant MatchRotationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showOnLeft != widget.showOnLeft) {
      _showOnLeft = widget.showOnLeft;
    }
  }

  List<({int position, double x, double y})> _courtLayout(int count) {
    if (count == 6) {
      return const [
        (position: 4, x: 0.15, y: 0.18),
        (position: 3, x: 0.38, y: 0.18),
        (position: 5, x: 0.15, y: 0.5),
        (position: 2, x: 0.38, y: 0.5),
        (position: 0, x: 0.15, y: 0.82),
        (position: 1, x: 0.38, y: 0.82),
      ];
    }
    if (count == 4) {
      return const [
        (position: 0, x: 0.08, y: 0.5),
        (position: 1, x: 0.24, y: 0.82),
        (position: 2, x: 0.39, y: 0.5),
        (position: 3, x: 0.24, y: 0.18),
      ];
    }
    return const [
      (position: 0, x: 0.19, y: 0.82),
      (position: 1, x: 0.39, y: 0.5),
      (position: 2, x: 0.17, y: 0.18),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rotation = widget.rotation;
    final team = rotation.left;
    final count = rotationPlayerCount(rotation.league);
    final isComplete = team.positions.length >= count &&
        team.positions.take(count).every((id) =>
            id != null && team.players.any((player) => player.id == id));
    final sideName = widget.teamName.isEmpty ? 'Eigenes Team' : widget.teamName;

    return Card(
      key: const ValueKey('match-rotation-panel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sollaufstellung · $sideName',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    key: const ValueKey('match-rotation-edit-button'),
                    tooltip: 'Aufstellung bearbeiten',
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            SegmentedButton<bool>(
              key: const ValueKey('match-rotation-side-selector'),
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.keyboard_double_arrow_left),
                  label: Text('Links'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.keyboard_double_arrow_right),
                  label: Text('Rechts'),
                ),
              ],
              selected: {_showOnLeft},
              onSelectionChanged: (selection) {
                final showOnLeft = selection.single;
                setState(() => _showOnLeft = showOnLeft);
                widget.onSideChanged?.call(showOnLeft);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Aufschlag: ${rotation.servingSide == 0 ? 'eigenes Team' : 'Gegner'}',
              key: const ValueKey('match-rotation-serving-side'),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final courtSize = math.min(420.0, constraints.maxWidth);
                return Center(
                  child: SizedBox(
                    key: const ValueKey('match-rotation-court'),
                    width: courtSize,
                    height: courtSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD89B5B),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CustomPaint(
                        painter: _MatchRotationCourtPainter(
                          netOnLeft: !_showOnLeft,
                        ),
                        child: Stack(
                          children: [
                            for (final slot in _courtLayout(count))
                              Align(
                                alignment: Alignment(
                                  _showOnLeft ? slot.x * 2 - 1 : 1 - slot.x * 2,
                                  slot.y * 2 - 1,
                                ),
                                child: SizedBox(
                                  width: math.min(88, courtSize * 0.25),
                                  child: InkWell(
                                    key: ValueKey(
                                      'edit-rotation-position-${slot.position}',
                                    ),
                                    borderRadius: BorderRadius.circular(36),
                                    onTap: widget.onSubstitute == null
                                        ? null
                                        : () => widget.onSubstitute!(
                                              slot.position,
                                            ),
                                    child: _playerMarker(
                                      team: team,
                                      position: slot.position,
                                      serving: slot.position == 0 &&
                                          rotation.servingSide == 0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!isComplete)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aufstellung unvollständig: Rotation noch nicht aktiv.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerMarker({
    required RotationTeamState team,
    required int position,
    required bool serving,
  }) {
    final playerId =
        position < team.positions.length ? team.positions[position] : null;
    final player =
        team.players.where((entry) => entry.id == playerId).firstOrNull;
    final markerTextColor =
        ThemeData.estimateBrightnessForColor(widget.teamColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              key: ValueKey('match-rotation-player-$position'),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: player == null ? Colors.white24 : widget.teamColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: serving ? Colors.white : markerTextColor,
                  width: serving ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3),
                ],
              ),
              child: player == null
                  ? const Icon(Icons.person_outline, color: Colors.white)
                  : Text(
                      '${player.number ?? position + 1}',
                      style: TextStyle(
                        color: markerTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            Positioned(
              top: -3,
              left: -4,
              child: Container(
                key: ValueKey('match-rotation-position-badge-$position'),
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.teamColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${position + 1}',
                  key: ValueKey('match-rotation-position-number-$position'),
                  style: TextStyle(
                    color: markerTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          player?.name ?? 'Offen',
          key: ValueKey('match-rotation-position-$position'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
      ],
    );
  }
}

class _MatchRotationCourtPainter extends CustomPainter {
  const _MatchRotationCourtPainter({required this.netOnLeft});

  final bool netOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      paint,
    );
    final netX = netOnLeft ? 0.0 : size.width;
    final attackLineX = netOnLeft ? size.width / 3 : size.width * 2 / 3;
    canvas.drawLine(
      Offset(attackLineX, 0),
      Offset(attackLineX, size.height),
      paint,
    );
    final netPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    canvas.drawLine(Offset(netX, 0), Offset(netX, size.height), netPaint);
  }

  @override
  bool shouldRepaint(covariant _MatchRotationCourtPainter oldDelegate) =>
      oldDelegate.netOnLeft != netOnLeft;
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PlayerStatsTable extends StatefulWidget {
  const _PlayerStatsTable({
    required this.title,
    required this.categories,
    required this.players,
    required this.summaryFor,
  });

  final String title;
  final List<String> categories;
  final List<MatchPlayer> players;
  final Map<String, int> Function(MatchPlayer player) summaryFor;

  @override
  State<_PlayerStatsTable> createState() => _PlayerStatsTableState();
}

class _PlayerStatsTableState extends State<_PlayerStatsTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: DataTable(
                  columnSpacing: 20,
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  columns: [
                    const DataColumn(label: Text('Spieler')),
                    for (final category in widget.categories)
                      DataColumn(label: Text(category), numeric: true),
                    const DataColumn(
                      label: Text(
                        'Gesamt',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: [
                    for (final player in widget.players)
                      _buildRow(player, widget.summaryFor(player)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(MatchPlayer player, Map<String, int> summary) {
    final total = summary.values.fold(0, (total, value) => total + value);
    return DataRow(
      cells: [
        DataCell(Text(player.name)),
        for (final category in widget.categories)
          DataCell(Text('${summary[category] ?? 0}')),
        DataCell(
          Text(
            '$total',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _SetScore {
  const _SetScore({
    required this.us,
    required this.opponent,
    required this.isFinished,
  });

  final int us;
  final int opponent;
  final bool isFinished;
}

class _SelectedMatchesSummary extends StatelessWidget {
  const _SelectedMatchesSummary({required this.matches});

  final List<MatchGame> matches;

  String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('selected-match-summary'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ausgewählte Partien (${matches.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < matches.length; index++)
              ListTile(
                key: ValueKey('selected-match-summary-${matches[index].id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  matches[index].opponentTeam.isEmpty
                      ? 'Spiel ohne Gegner'
                      : 'vs. ${matches[index].opponentTeam}',
                ),
                subtitle: Text(
                  '${matches[index].matchType} · ${_formatDateTime(matches[index].matchDateTime)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendSample {
  const _TrendSample({
    required this.time,
    required this.points,
    required this.errors,
    required this.opponentErrors,
  });

  final DateTime time;
  final int points;
  final int errors;
  final int opponentErrors;
}

double trendChartMaxTimeScale(int sampleCount) =>
    (sampleCount / 4).clamp(16.0, 64.0).toDouble();

class _TrendChartCard extends StatefulWidget {
  const _TrendChartCard({
    required this.title,
    required this.samples,
    required this.timeoutMarkers,
    this.matchTimes = const <DateTime>[],
    required this.height,
  });

  final String title;
  final List<_TrendSample> samples;
  final List<DateTime> timeoutMarkers;
  final List<DateTime> matchTimes;
  final double height;

  @override
  State<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<_TrendChartCard> {
  double _scale = 1;

  double get _maxScale => trendChartMaxTimeScale(widget.samples.length);

  void _setScale(double scale) {
    final nextScale = scale.clamp(1.0, _maxScale).toDouble();
    setState(() => _scale = nextScale);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Zeitachse verkürzen',
                  onPressed: _scale <= 1 ? null : () => _setScale(_scale / 1.5),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: 'Zeitachse nach rechts erweitern',
                  onPressed: _scale >= _maxScale
                      ? null
                      : () => _setScale(_scale * 1.5),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  tooltip: 'Zeitachse zurücksetzen',
                  onPressed: _scale == 1 ? null : () => _setScale(1),
                  icon: const Icon(Icons.zoom_out_map),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: const [
                _TrendLegendDot(color: Colors.greenAccent, label: 'Punkte'),
                _TrendLegendDot(
                  color: Color(0xFFe57373),
                  label: 'Fehler',
                ),
                _TrendLegendDot(
                  color: Color(0xFF64B5F6),
                  label: 'Gegnerfehler',
                ),
                _TrendLegendLine(
                  color: Color(0xFFFFB74D),
                  label: 'Auszeit',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: widget.samples.isEmpty
                  ? const Center(child: Text('Noch keine Diagrammdaten.'))
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        key: ValueKey('trend-chart-scroll-${widget.title}'),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          key: ValueKey('trend-chart-content-${widget.title}'),
                          width: constraints.maxWidth * _scale,
                          height: widget.height,
                          child: CustomPaint(
                            painter: _TrendChartPainter(
                              samples: widget.samples,
                              timeoutMarkers: widget.timeoutMarkers,
                              matchTimes: widget.matchTimes,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendLegendDot extends StatelessWidget {
  const _TrendLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _TrendLegendLine extends StatelessWidget {
  const _TrendLegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.samples,
    required this.timeoutMarkers,
    required this.matchTimes,
  });

  final List<_TrendSample> samples;
  final List<DateTime> timeoutMarkers;
  final List<DateTime> matchTimes;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    const leftPadding = 36.0;
    const topPadding = 12.0;
    const rightPadding = 12.0;
    const bottomPadding = 38.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      math.max(0, size.width - leftPadding - rightPadding),
      math.max(0, size.height - topPadding - bottomPadding),
    );

    final firstTime = samples.first.time;
    final lastTime = samples.last.time;
    final spanMillis = math.max(
      1,
      lastTime.difference(firstTime).inMilliseconds,
    );

    double xFor(DateTime time) {
      final relative = time.difference(firstTime).inMilliseconds / spanMillis;
      return chartRect.left + chartRect.width * relative;
    }

    if (matchTimes.length > 1) {
      final boundaries = matchTimes
          .map((time) => xFor(time).clamp(chartRect.left, chartRect.right))
          .toList()
        ..sort();
      final bandColors = [
        const Color(0xFF42A5F5).withValues(alpha: 0.1),
        const Color(0xFFFFB74D).withValues(alpha: 0.1),
      ];
      for (var index = 0; index < boundaries.length; index++) {
        final left = boundaries[index].toDouble();
        final right = index + 1 < boundaries.length
            ? boundaries[index + 1].toDouble()
            : chartRect.right;
        if (right <= left) continue;
        canvas.drawRect(
          Rect.fromLTRB(left, chartRect.top, right, chartRect.bottom),
          Paint()..color = bandColors[index % bandColors.length],
        );
      }
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;

    for (var i = 1; i <= 3; i++) {
      final y = chartRect.top + chartRect.height * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }
    for (var i = 1; i <= 3; i++) {
      final x = chartRect.left + chartRect.width * i / 4;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);

    final maxValue = samples.fold<int>(0, (max, sample) {
      return math.max(
        max,
        math.max(
          math.max(sample.points, sample.errors),
          sample.opponentErrors,
        ),
      );
    });
    final maxY = math.max(1, maxValue);

    double yFor(int value) {
      final relative = value / maxY;
      return chartRect.bottom - chartRect.height * relative;
    }

    String formatTime(DateTime value) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }

    void paintSeries(List<Offset> points, Color color) {
      if (points.length < 2) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);

      final pointPaint = Paint()..color = color;
      for (final point in points) {
        canvas.drawCircle(point, 3.5, pointPaint);
      }
    }

    void paintTimeoutMarkers(List<DateTime> markers) {
      if (markers.isEmpty) return;
      final markerPaint = Paint()
        ..color = const Color(0xFFFFB74D).withValues(alpha: 0.95)
        ..strokeWidth = 2;
      for (final time in markers) {
        final x = xFor(time);
        canvas.drawLine(
          Offset(x, chartRect.top),
          Offset(x, chartRect.bottom),
          markerPaint,
        );
      }
    }

    final pointSeries = samples
        .map((sample) => Offset(xFor(sample.time), yFor(sample.points)))
        .toList();
    final errorSeries = samples
        .map((sample) => Offset(xFor(sample.time), yFor(sample.errors)))
        .toList();
    final opponentErrorSeries = samples
        .map((sample) => Offset(xFor(sample.time), yFor(sample.opponentErrors)))
        .toList();

    paintTimeoutMarkers(timeoutMarkers);
    paintSeries(pointSeries, Colors.greenAccent);
    paintSeries(errorSeries, const Color(0xFFe57373));
    paintSeries(opponentErrorSeries, const Color(0xFF64B5F6));

    const labelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final topLabel = TextPainter(
      text: TextSpan(text: '$maxY', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    topLabel.paint(canvas, Offset(4, chartRect.top - 2));

    final bottomLabel = TextPainter(
      text: const TextSpan(text: '0', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    bottomLabel.paint(canvas, Offset(8, chartRect.bottom - 14));

    const axisLabelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final startLabel = TextPainter(
      text: TextSpan(text: formatTime(firstTime), style: axisLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    startLabel.paint(canvas, Offset(chartRect.left, chartRect.bottom + 4));

    final middleTime = firstTime.add(
      Duration(milliseconds: spanMillis ~/ 2),
    );
    final middleLabel = TextPainter(
      text: TextSpan(text: formatTime(middleTime), style: axisLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    middleLabel.paint(
      canvas,
      Offset(
        chartRect.left + chartRect.width / 2 - middleLabel.width / 2,
        chartRect.bottom + 4,
      ),
    );

    final endLabel = TextPainter(
      text: TextSpan(text: formatTime(lastTime), style: axisLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    endLabel.paint(
      canvas,
      Offset(chartRect.right - endLabel.width, chartRect.bottom + 4),
    );
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.timeoutMarkers != timeoutMarkers ||
        oldDelegate.matchTimes != matchTimes;
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.event,
    required this.setNumber,
    required this.ourScore,
    required this.opponentScore,
  });

  final MatchEvent event;
  final int setNumber;
  final int ourScore;
  final int opponentScore;
}

class _MatchHistoryPage extends StatefulWidget {
  const _MatchHistoryPage({
    required this.match,
    required this.onMatchChanged,
  });

  final MatchGame match;
  final ValueChanged<MatchGame> onMatchChanged;

  @override
  State<_MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<_MatchHistoryPage> {
  late MatchGame _match = widget.match;

  List<_HistoryEntry> _historyEntries() {
    final sortedEvents = List<MatchEvent>.from(_match.events)
      ..sort((a, b) {
        final timeOrder = a.occurredAt.compareTo(b.occurredAt);
        return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
      });
    final entries = <_HistoryEntry>[];
    var setNumber = 1;
    var ourScore = 0;
    var opponentScore = 0;

    for (final event in sortedEvents) {
      if (event.kind == _manualSetEndKind) {
        entries.add(
          _HistoryEntry(
            event: event,
            setNumber: setNumber,
            ourScore: ourScore,
            opponentScore: opponentScore,
          ),
        );
        setNumber++;
        ourScore = 0;
        opponentScore = 0;
        continue;
      }
      if (event.kind == 'point') {
        ourScore++;
      } else if (event.kind == 'error') {
        opponentScore++;
      }
      entries.add(
        _HistoryEntry(
          event: event,
          setNumber: setNumber,
          ourScore: ourScore,
          opponentScore: opponentScore,
        ),
      );

      final setFinished = (ourScore >= 25 && ourScore - opponentScore >= 2) ||
          (opponentScore >= 25 && opponentScore - ourScore >= 2);
      if (setFinished) {
        setNumber++;
        ourScore = 0;
        opponentScore = 0;
      }
    }
    return entries;
  }

  Future<void> _editEvent(MatchEvent event) async {
    final updatedEvent = await showDialog<MatchEvent>(
      context: context,
      builder: (context) => _EditMatchEventDialog(
        event: event,
        players: _match.players,
      ),
    );
    if (updatedEvent == null || !mounted) return;
    final updated = _match.copyWith(
      events: _match.events
          .map((entry) => entry.id == updatedEvent.id ? updatedEvent : entry)
          .toList(),
    );
    widget.onMatchChanged(updated);
    setState(() => _match = updated);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _historyEntries();
    final finishedSets = entries.where((entry) {
      if (entry.event.kind == _manualSetEndKind) return true;
      final scoreDifference = entry.ourScore - entry.opponentScore;
      return (entry.ourScore >= 25 && scoreDifference >= 2) ||
          (entry.opponentScore >= 25 && scoreDifference <= -2);
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: SafeArea(
        child: entries.isEmpty
            ? const Center(
                child: Text('Noch keine Verlaufseinträge vorhanden.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    '${entries.length} Aktionen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$finishedSets abgeschlossene Sätze',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _MatchHistoryTimeline(
                    entries: entries,
                    onEdit: _editEvent,
                  ),
                ],
              ),
      ),
    );
  }
}

class _MatchHistoryTimeline extends StatelessWidget {
  const _MatchHistoryTimeline({
    required this.entries,
    required this.onEdit,
  });

  final List<_HistoryEntry> entries;
  final ValueChanged<MatchEvent> onEdit;

  String _formatTimestamp(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  String _kindLabel(MatchEvent entry) {
    if (entry.kind == _timeoutKind) return 'Auszeit';
    if (entry.kind == _manualSetEndKind) return 'Satzende';
    if (entry.kind == 'substitution') return 'Spielerwechsel';
    return entry.kind == 'point' ? 'Punkt' : 'Fehler';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.outlineVariant;
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _HistoryTimelineRow(
            entry: entries[index],
            previousSetNumber: index == 0 ? null : entries[index - 1].setNumber,
            lineColor: lineColor,
            formatTimestamp: _formatTimestamp,
            kindLabel: _kindLabel,
            onEdit: entries[index].event.kind == 'point' ||
                    entries[index].event.kind == 'error'
                ? () => onEdit(entries[index].event)
                : null,
          ),
      ],
    );
  }
}

class _EditMatchEventDialog extends StatefulWidget {
  const _EditMatchEventDialog({
    required this.event,
    required this.players,
  });

  final MatchEvent event;
  final List<MatchPlayer> players;

  @override
  State<_EditMatchEventDialog> createState() => _EditMatchEventDialogState();
}

class _EditMatchEventDialogState extends State<_EditMatchEventDialog> {
  late String _kind = widget.event.kind;
  late String _selectedScorer = _initialScorerKey(widget.event);
  late final TextEditingController _categoryController =
      TextEditingController(text: widget.event.category);

  String _initialScorerKey(MatchEvent event) {
    if (event.playerId == _unknownScorerId) return 'unknown';
    if (event.playerId == _teamScorerId) return 'team';
    if (event.playerId == null) {
      return event.playerName == 'Gegner' ? 'opponent' : 'unknown';
    }
    return widget.players.any((player) => player.id == event.playerId)
        ? 'player:${event.playerId}'
        : 'unknown';
  }

  void _save() {
    final scorerKey = _selectedScorer;
    final MatchEvent updated;
    if (scorerKey == 'unknown') {
      updated = widget.event.copyWith(
        playerId: _unknownScorerId,
        playerName: 'Unbekannt',
        playerNumber: 0,
        kind: _kind,
        category: _categoryController.text.trim(),
      );
    } else if (scorerKey == 'team') {
      updated = widget.event.copyWith(
        playerId: _teamScorerId,
        playerName: 'Mannschaft',
        playerNumber: 0,
        kind: _kind,
        category: _categoryController.text.trim(),
      );
    } else if (scorerKey == 'opponent') {
      updated = widget.event.copyWith(
        clearPlayerId: true,
        playerName: 'Gegner',
        playerNumber: 0,
        kind: _kind,
        category: _categoryController.text.trim(),
      );
    } else {
      final playerId = int.tryParse(scorerKey.substring('player:'.length));
      final player = widget.players.cast<MatchPlayer?>().firstWhere(
            (entry) => entry?.id == playerId,
            orElse: () => null,
          );
      if (player == null) return;
      updated = widget.event.copyWith(
        playerId: player.id,
        playerName: player.name,
        playerNumber: player.number,
        kind: _kind,
        category: _categoryController.text.trim(),
      );
    }
    Navigator.of(context).pop(updated);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Statistik bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Wertung'),
            items: const [
              DropdownMenuItem(value: 'point', child: Text('Punkt')),
              DropdownMenuItem(value: 'error', child: Text('Fehler')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _kind = value);
            },
          ),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Kategorie'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedScorer,
            decoration: const InputDecoration(labelText: 'Scorer'),
            items: [
              for (final player in widget.players)
                DropdownMenuItem(
                  value: 'player:${player.id}',
                  child: Text('${player.name} · ${player.number}'),
                ),
              const DropdownMenuItem(
                value: 'unknown',
                child: Text('Unbekannt'),
              ),
              const DropdownMenuItem(
                value: 'team',
                child: Text('Mannschaft'),
              ),
              const DropdownMenuItem(
                value: 'opponent',
                child: Text('Gegner'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedScorer = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

class _HistoryTimelineRow extends StatelessWidget {
  const _HistoryTimelineRow({
    required this.entry,
    required this.previousSetNumber,
    required this.lineColor,
    required this.formatTimestamp,
    required this.kindLabel,
    required this.onEdit,
  });

  final _HistoryEntry entry;
  final int? previousSetNumber;
  final Color lineColor;
  final String Function(DateTime) formatTimestamp;
  final String Function(MatchEvent) kindLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final isPoint = event.kind == 'point';
    final isTimeout = event.kind == _timeoutKind;
    final isManualSetEnd = event.kind == _manualSetEndKind;
    final isSubstitution = event.kind == 'substitution';
    final eventColor = isTimeout
        ? AppPalette.orange
        : isManualSetEnd || isSubstitution
            ? Theme.of(context).colorScheme.primary
            : isPoint
                ? AppPalette.green
                : AppPalette.red;
    final textTheme = Theme.of(context).textTheme;
    final scoreText = isTimeout || isManualSetEnd
        ? 'Satz ${entry.setNumber}'
        : '${entry.ourScore} : ${entry.opponentScore}';

    return Column(
      children: [
        if (previousSetNumber != null && previousSetNumber != entry.setNumber)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 10, top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Satz ${entry.setNumber}',
                style: textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: eventColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: eventColor.withValues(alpha: 0.35),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: Container(width: 2, color: lineColor)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lineColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            kindLabel(event),
                            style: textTheme.titleSmall?.copyWith(
                              color: eventColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            scoreText,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (onEdit != null)
                            IconButton(
                              key: ValueKey('edit-match-event-${event.id}'),
                              tooltip: 'Statistik bearbeiten',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isTimeout
                            ? 'Team-Auszeit'
                            : isSubstitution
                                ? '${event.playerName} · Position ${(event.rotationPosition ?? 0) + 1}'
                                : '${event.playerName}  •  ${event.category}',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTimestamp(event.occurredAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockTile extends StatelessWidget {
  const _ClockTile({required this.clockText});

  final String clockText;

  @override
  Widget build(BuildContext context) {
    return _ValueTile(title: 'Uhrzeit', value: clockText);
  }
}

class _StopwatchTile extends StatelessWidget {
  const _StopwatchTile({
    required this.stopwatchText,
    required this.stopwatchRunning,
    required this.onToggle,
    required this.onReset,
  });

  final String stopwatchText;
  final bool stopwatchRunning;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      onLongPress: onReset,
      child: _ValueTile(
        title: 'Stoppuhr',
        value: stopwatchText,
        icon: stopwatchRunning
            ? Icons.pause_circle_filled
            : Icons.play_circle_fill,
      ),
    );
  }
}

class _SetsTile extends StatelessWidget {
  const _SetsTile({required this.sets});

  final List<_SetScore> sets;

  @override
  Widget build(BuildContext context) {
    final finishedSets = sets.where((set) => set.isFinished);
    final setsWonByUs =
        finishedSets.where((set) => set.us > set.opponent).length;
    final setsWonByOpponent =
        finishedSets.where((set) => set.opponent > set.us).length;
    return _ValueTile(
      title: 'Sätze',
      value: '$setsWonByUs : $setsWonByOpponent',
    );
  }
}

class _PointsTile extends StatelessWidget {
  const _PointsTile({required this.sets});

  final List<_SetScore> sets;

  @override
  Widget build(BuildContext context) {
    final currentSet = sets.last;
    return _ValueTile(
      title: currentSet.isFinished ? 'Letzter Satz' : 'Punktestand',
      value: '${currentSet.us} : ${currentSet.opponent}',
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.title,
    required this.value,
    this.icon,
  });

  final String title;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        height: 140,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 44),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetsOverview extends StatelessWidget {
  const _SetsOverview({required this.sets});

  final List<_SetScore> sets;

  @override
  Widget build(BuildContext context) {
    final finishedSets = sets.where((set) => set.isFinished);
    final setsWonByUs =
        finishedSets.where((set) => set.us > set.opponent).length;
    final setsWonByOpponent =
        finishedSets.where((set) => set.opponent > set.us).length;
    final currentSet = sets.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Satzstand',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '$setsWonByUs : $setsWonByOpponent',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currentSet.isFinished ? 'Letzter Satz' : 'Aktueller Satz',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${currentSet.us} : ${currentSet.opponent}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sets.length > 1) ...[
              const SizedBox(height: 12),
              const Text('Sätze im Verlauf'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < sets.length; index++)
                    Chip(
                      label: Text(
                        '${sets[index].us}:${sets[index].opponent}',
                      ),
                      backgroundColor: !sets[index].isFinished
                          ? null
                          : sets[index].us > sets[index].opponent
                              ? Colors.green.withValues(alpha: 0.2)
                              : const Color(0xFFe57373).withValues(alpha: 0.2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatGroup extends StatelessWidget {
  const _StatGroup({required this.title, required this.entries});

  final String title;
  final Map<String, int> entries;

  @override
  Widget build(BuildContext context) {
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              const Text('Noch keine Einträge.')
            else
              ...sorted.map(
                (entry) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(entry.key)),
                    Text('${entry.value}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
