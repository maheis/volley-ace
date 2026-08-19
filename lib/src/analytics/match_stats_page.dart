import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import '../teams/teams_page.dart';

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
  });

  final int id;
  final int? playerId;
  final String playerName;
  final int playerNumber;
  final String kind;
  final String category;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'playerNumber': playerNumber,
        'kind': kind,
        'category': category,
        'occurredAtMillis': occurredAt.millisecondsSinceEpoch,
      };

  static MatchEvent fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final playerId = data['playerId'];
    final playerName = data['playerName'];
    final playerNumber = data['playerNumber'];
    final kind = data['kind'];
    final category = data['category'];
    final occurredAtMillis = data['occurredAtMillis'];

    return MatchEvent(
      id: id is num ? id.toInt() : 0,
      playerId: playerId is num ? playerId.toInt() : null,
      playerName: playerName is String ? playerName : 'Unbekannt',
      playerNumber: playerNumber is num ? playerNumber.toInt() : 0,
      kind: kind is String ? kind : 'point',
      category: category is String ? category : 'Ass',
      occurredAt: occurredAtMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(occurredAtMillis.toInt())
          : DateTime.now(),
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
    this.teamId,
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
  final int? teamId;
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
    int? teamId,
    bool clearTeamId = false,
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
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
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
        'teamId': teamId,
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
      teamId: data['teamId'] is num ? (data['teamId'] as num).toInt() : null,
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
  const MatchStatsPage({super.key, required this.database});

  final Database database;

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

  static const String _opponentErrorCategory = 'Gegner Fehler';
  static const List<String> _pointTypes = <String>[
    'Ass',
    'Angriff',
    'Block',
    _opponentErrorCategory,
  ];
  static const List<String> _errorTypes = <String>[
    'Aufschlag',
    'Ball ins Aus',
    'Ball ins Netz',
    'Ball nicht rüber',
    'Zugeschaut',
    'Tusch',
    'Übertritt',
    'Netz Berührung',
    'Sonstiges',
  ];

  late final MatchStatsRepository _repository = MatchStatsRepository(
    widget.database,
  );
  late final TeamsRepository _teamsRepository =
      TeamsRepository(widget.database);

  final List<MatchGame> _matches = <MatchGame>[];
  final List<Team> _teams = <Team>[];
  int? _selectedMatchId;
  String? _activeSection;
  String? _pendingEventKind;
  String? _pendingCategory;
  bool _isLoaded = false;
  int _nextMatchId = 1;

  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _matchTagController = TextEditingController();

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

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
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _teams
        ..clear()
        ..addAll(teams);
      _isLoaded = true;
      _nextMatchId = _matches.isEmpty
          ? 1
          : _matches.map((match) => match.id).reduce((a, b) => a > b ? a : b) +
              1;
    });
  }

  Future<void> _persist() async {
    final matches = List<MatchGame>.from(_matches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _repository.save(MatchStatsState(matches: matches));
  }

  Future<void> _exportBackup() async {
    await AppBackupService.exportBackup(context, widget.database);
  }

  Future<void> _importBackup() async {
    final imported =
        await AppBackupService.importBackup(context, widget.database);
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

  void _showMatchDetail(int matchId, {String? section}) {
    if (section == 'info') {
      final match = _matches.firstWhere((entry) => entry.id == matchId);
      _locationController.text = match.location;
      _opponentController.text = match.opponentTeam;
      _matchTagController.text = match.matchTag;
    }
    setState(() {
      _selectedMatchId = matchId;
      _activeSection = section;
      _pendingEventKind = null;
      _pendingCategory = null;
    });
  }

  void _closeMatchDetail() {
    setState(() {
      _selectedMatchId = null;
      _activeSection = null;
      _pendingEventKind = null;
      _pendingCategory = null;
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
    int? teamId,
    bool clearTeamId = false,
    List<MatchCoach>? coaches,
  }) {
    _replaceMatch(
      match.copyWith(
        location: location,
        opponentTeam: opponentTeam,
        matchDateTime: matchDateTime,
        matchTag: matchTag,
        matchType: matchType,
        teamId: teamId,
        clearTeamId: clearTeamId,
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

    final nextId = match.players.isEmpty
        ? 1
        : match.players
                .map((player) => player.id)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final players = List<MatchPlayer>.from(match.players)
      ..add(MatchPlayer(id: nextId, name: name, number: number));

    _replaceMatch(match.copyWith(players: players));
    _playerNameController.clear();
    _playerNumberController.clear();
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
      players.removeWhere((entry) => entry.teamPlayerId == player.id);
    }
    _replaceMatch(match.copyWith(players: players));
  }

  void _selectTeam(MatchGame match, int? teamId) {
    _updateMatchInfo(
      match,
      teamId: teamId,
      clearTeamId: teamId == null,
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

  void _updateTeamPlayerNumber(
      MatchGame match, MatchPlayer player, String value) {
    final number = int.tryParse(value.trim());
    if (number == null) return;
    _replaceMatch(match.copyWith(
      players: match.players
          .map((entry) =>
              entry.id == player.id ? entry.copyWith(number: number) : entry)
          .toList(),
    ));
  }

  void _removePlayerFromMatch(MatchGame match, MatchPlayer player) {
    final players = List<MatchPlayer>.from(match.players)
      ..removeWhere((entry) => entry.id == player.id);
    final events = List<MatchEvent>.from(match.events)
      ..removeWhere((event) => event.playerId == player.id);
    _replaceMatch(match.copyWith(players: players, events: events));
  }

  void _replaceMatch(MatchGame updated) {
    setState(() {
      final index = _matches.indexWhere((match) => match.id == updated.id);
      if (index >= 0) {
        _matches[index] = updated;
      } else {
        _matches.insert(0, updated);
      }
      _matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    setState(() {
      _pendingEventKind = isPoint ? 'point' : 'error';
      _pendingCategory = null;
      _activeSection = 'category-selection';
    });
  }

  void _selectPlayerForEvent(MatchGame match, MatchPlayer player) {
    final category = _pendingCategory;
    if (category == null) return;
    _createEvent(match, playerId: player.id, category: category);
  }

  void _selectCategoryForEvent(MatchGame match, String category) {
    if (category == _opponentErrorCategory) {
      _createEvent(
        match,
        playerId: null,
        category: category,
        playerName: 'Gegner',
        playerNumber: 0,
      );
      return;
    }

    setState(() {
      _pendingCategory = category;
      _activeSection = 'player-selection';
    });
  }

  void _createEvent(
    MatchGame match, {
    required int? playerId,
    required String category,
    String? playerName,
    int? playerNumber,
  }) {
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
      _pendingCategory = null;
      _activeSection = 'scoring';
    });
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
      } else {
        opponent++;
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
    for (final event in match.events.where(
      (entry) => entry.playerId == playerId && entry.kind == kind,
    )) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selectedMatch = _selectedMatch;
    if (selectedMatch != null && _activeSection == null) {
      return _buildMatchDetailView(selectedMatch);
    }
    if (selectedMatch != null && _activeSection == 'info') {
      return _buildMatchInfoView(selectedMatch);
    }
    if (selectedMatch != null && _activeSection == 'scoring') {
      return _buildScoringView(selectedMatch);
    }
    if (selectedMatch != null && _activeSection == 'player-selection') {
      return _buildPlayerSelectionView(selectedMatch);
    }
    if (selectedMatch != null && _activeSection == 'category-selection') {
      return _buildCategorySelectionView(selectedMatch);
    }
    if (selectedMatch != null && _activeSection == 'stats') {
      return _buildStatsView(selectedMatch);
    }

    return _buildMatchListView();
  }

  Widget _buildMatchListView() {
    final matches = List<MatchGame>.from(_matches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punktewertung'),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportBackup,
          ),
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.upload_outlined),
            onPressed: _importBackup,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
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
                    title: Text(
                      match.opponentTeam.isEmpty
                          ? 'Neues Spiel'
                          : 'vs. ${match.opponentTeam}',
                    ),
                    subtitle: Text(
                      '${match.matchType} • ${_formatDateTime(match.matchDateTime)} • ${match.matchTag.isEmpty ? 'Ohne Stichwort' : match.matchTag} • ${match.location.isEmpty ? 'Ort offen' : match.location}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showMatchDetail(match.id),
                  ),
                ),
          ],
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
              color: Colors.red,
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
          ],
        ),
      ),
    );
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
          const Text(
            'Kader für dieses Spiel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          initialValue: matchPlayer?.number.toString() ??
                              (teamPlayer.number?.toString() ?? ''),
                          keyboardType: TextInputType.number,
                          onFieldSubmitted: (value) {
                            if (matchPlayer != null) {
                              _updateTeamPlayerNumber(
                                  match, matchPlayer, value);
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
        const Text(
          'Spieler manuell hinzufügen',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
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
            const SizedBox(width: 12),
            IconButton.filled(
              key: const ValueKey('add-player-button'),
              onPressed: () => _addPlayerToMatch(match),
              icon: const Icon(Icons.add),
              tooltip: 'Spieler hinzufügen',
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
              trailing: IconButton(
                onPressed: () => _removePlayerFromMatch(match, player),
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Spieler entfernen',
              ),
            ),
      ],
    );
  }

  Widget _buildScoringView(MatchGame match) {
    final sets = _computeSets(match);
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
                    backgroundColor: Colors.green,
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
                    backgroundColor: Colors.red,
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
              Row(
                children: [
                  Expanded(child: _SetsTile(sets: scoreSets)),
                  const SizedBox(width: 12),
                  Expanded(child: _PointsTile(sets: scoreSets)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMatchHistory(MatchGame match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MatchHistoryPage(match: match),
      ),
    );
  }

  Widget _buildPlayerSelectionView(MatchGame match) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler auswählen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              setState(() => _activeSection = 'category-selection'),
        ),
      ),
      body: SafeArea(
        child: match.players.isEmpty
            ? const Center(child: Text('Noch keine Spieler angelegt.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: match.players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final player = match.players[index];
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

  Widget _buildCategorySelectionView(MatchGame match) {
    final isPoint = _pendingEventKind == 'point';
    final categories = isPoint ? _pointTypes : _errorTypes;
    return Scaffold(
      appBar: AppBar(
        title: Text(isPoint ? 'Punktart auswählen' : 'Fehler auswählen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeSection = 'player-selection'),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            return SizedBox(
              width: double.infinity,
              height: 140,
              child: Card(
                child: InkWell(
                  key: ValueKey('select-category-$category'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectCategoryForEvent(match, category),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildStatsView(MatchGame match) {
    final points = _pointSummary(match);
    final errors = _errorSummary(match);
    final sets = _computeSets(match);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showMatchDetail(match.id),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (sets.isNotEmpty) ...[
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
              height: 220,
            ),
            const SizedBox(height: 12),
            if (match.players.isNotEmpty) ...[
              const Text(
                'Spielerübersicht',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _PlayerStatsTable(
                title: 'Punkte pro Spieler',
                categories: _pointTypes,
                players: match.players,
                summaryFor: (player) =>
                    _playerSummary(match, player.id, kind: 'point'),
              ),
              const SizedBox(height: 12),
              _PlayerStatsTable(
                title: 'Fehler pro Spieler',
                categories: _errorTypes,
                players: match.players,
                summaryFor: (player) =>
                    _playerSummary(match, player.id, kind: 'error'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Zeitverlauf pro Spieler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final player in match.players) ...[
                _TrendChartCard(
                  title: player.name,
                  samples: _trendSamples(match, playerId: player.id),
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
      ),
    ];
    var points = 0;
    var errors = 0;
    for (final event in events) {
      if (event.kind == 'point') {
        points++;
      } else {
        errors++;
      }
      samples.add(
        _TrendSample(
          time: event.occurredAt,
          points: points,
          errors: errors,
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
    _playerNameController.dispose();
    _playerNumberController.dispose();
    _locationController.dispose();
    _opponentController.dispose();
    _matchTagController.dispose();
    super.dispose();
  }
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

class _TrendSample {
  const _TrendSample({
    required this.time,
    required this.points,
    required this.errors,
  });

  final DateTime time;
  final int points;
  final int errors;
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.title,
    required this.samples,
    required this.height,
  });

  final String title;
  final List<_TrendSample> samples;
  final double height;

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
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const _TrendLegendDot(
                  color: Colors.greenAccent,
                  label: 'Punkte',
                ),
                const SizedBox(width: 12),
                const _TrendLegendDot(color: Colors.redAccent, label: 'Fehler'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: height,
              width: double.infinity,
              child: samples.isEmpty
                  ? const Center(child: Text('Noch keine Diagrammdaten.'))
                  : CustomPaint(
                      painter: _TrendChartPainter(samples: samples),
                      child: const SizedBox.expand(),
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

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({required this.samples});

  final List<_TrendSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    const leftPadding = 36.0;
    const topPadding = 12.0;
    const rightPadding = 12.0;
    const bottomPadding = 24.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      math.max(0, size.width - leftPadding - rightPadding),
      math.max(0, size.height - topPadding - bottomPadding),
    );

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
      return math.max(max, math.max(sample.points, sample.errors));
    });
    final maxY = math.max(1, maxValue);
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

    double yFor(int value) {
      final relative = value / maxY;
      return chartRect.bottom - chartRect.height * relative;
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

    final pointSeries = samples
        .map((sample) => Offset(xFor(sample.time), yFor(sample.points)))
        .toList();
    final errorSeries = samples
        .map((sample) => Offset(xFor(sample.time), yFor(sample.errors)))
        .toList();

    paintSeries(pointSeries, Colors.greenAccent);
    paintSeries(errorSeries, Colors.redAccent);

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
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

class _MatchHistoryPage extends StatelessWidget {
  const _MatchHistoryPage({required this.match});

  final MatchGame match;

  @override
  Widget build(BuildContext context) {
    final entries = List<MatchEvent>.from(match.events)
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: entries.isEmpty
              ? const Center(
                  child: Text('Noch keine Verlaufseinträge vorhanden.'),
                )
              : SingleChildScrollView(
                  child: _MatchHistoryTable(entries: entries),
                ),
        ),
      ),
    );
  }
}

class _MatchHistoryTable extends StatelessWidget {
  const _MatchHistoryTable({required this.entries});

  final List<MatchEvent> entries;

  String _formatTimestamp(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  String _kindLabel(MatchEvent entry) {
    return entry.kind == 'point' ? 'Punkt' : 'Fehler';
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: IntrinsicColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          const TableRow(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text('Zeit', style: headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text('Typ', style: headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text('Spieler', style: headerStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text('Kategorie', style: headerStyle),
              ),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    _formatTimestamp(entries[i].occurredAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    _kindLabel(entries[i]),
                    style: TextStyle(
                      color: entries[i].kind == 'point'
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    entries[i].playerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    entries[i].category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
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
                              : Colors.red.withValues(alpha: 0.2),
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
