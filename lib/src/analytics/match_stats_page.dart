import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.name,
    required this.number,
  });

  final int id;
  final String name;
  final int number;

  MatchPlayer copyWith({int? id, String? name, int? number}) {
    return MatchPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'number': number,
      };

  static MatchPlayer fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final name = data['name'];
    final number = data['number'];

    return MatchPlayer(
      id: id is num ? id.toInt() : 0,
      name: name is String ? name : '',
      number: number is num ? number.toInt() : 0,
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
  final int playerId;
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
      playerId: playerId is num ? playerId.toInt() : 0,
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

class MatchGame {
  const MatchGame({
    required this.id,
    required this.createdAt,
    required this.location,
    required this.opponentTeam,
    required this.matchDateTime,
    required this.matchTag,
    required this.matchType,
    required this.players,
    required this.events,
  });

  final int id;
  final DateTime createdAt;
  final String location;
  final String opponentTeam;
  final DateTime matchDateTime;
  final String matchTag;
  final String matchType;
  final List<MatchPlayer> players;
  final List<MatchEvent> events;

  MatchGame copyWith({
    int? id,
    DateTime? createdAt,
    String? location,
    String? opponentTeam,
    DateTime? matchDateTime,
    String? matchTag,
    String? matchType,
    List<MatchPlayer>? players,
    List<MatchEvent>? events,
  }) {
    return MatchGame(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      opponentTeam: opponentTeam ?? this.opponentTeam,
      matchDateTime: matchDateTime ?? this.matchDateTime,
      matchTag: matchTag ?? this.matchTag,
      matchType: matchType ?? this.matchType,
      players: players ?? this.players,
      events: events ?? this.events,
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
        'players': players.map((player) => player.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
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
      players: players,
      events: events,
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

  static const List<String> _pointTypes = <String>['Ass', 'Angriff', 'Block'];
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

  final List<MatchGame> _matches = <MatchGame>[];
  int? _selectedMatchId;
  String? _activeSection;
  bool _isLoaded = false;
  int _nextMatchId = 1;

  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _matchTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final state = await _repository.load();
    if (!mounted) return;

    setState(() {
      _matches
        ..clear()
        ..addAll(state.matches)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  MatchGame? get _selectedMatch {
    for (final match in _matches) {
      if (match.id == _selectedMatchId) return match;
    }
    return null;
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
    });
  }

  void _closeMatchDetail() {
    setState(() {
      _selectedMatchId = null;
      _activeSection = null;
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
  }) {
    _replaceMatch(
      match.copyWith(
        location: location,
        opponentTeam: opponentTeam,
        matchDateTime: matchDateTime,
        matchTag: matchTag,
        matchType: matchType,
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

    final players = List<MatchPlayer>.from(match.players)
      ..add(MatchPlayer(
          id: match.players.length + 1, name: name, number: number));

    _replaceMatch(match.copyWith(players: players));
    _playerNameController.clear();
    _playerNumberController.clear();
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

  Future<void> _recordEventForMatch(MatchGame match,
      {required bool isPoint}) async {
    if (match.players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitte erst mindestens einen Spieler anlegen.')),
      );
      return;
    }

    final player = await showDialog<MatchPlayer>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Spieler auswählen'),
          children: match.players
              .map(
                (entry) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(entry),
                  child: Text('${entry.name} • Nr. ${entry.number}'),
                ),
              )
              .toList(),
        );
      },
    );
    if (player == null || !mounted) return;

    final category = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final options = isPoint ? _pointTypes : _errorTypes;
        return SimpleDialog(
          title: Text(isPoint ? 'Punktart wählen' : 'Fehler wählen'),
          children: options
              .map(
                (option) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(option),
                  child: Text(option),
                ),
              )
              .toList(),
        );
      },
    );
    if (category == null || !mounted) return;

    final events = List<MatchEvent>.from(match.events)
      ..add(
        MatchEvent(
          id: match.events.length + 1,
          playerId: player.id,
          playerName: player.name,
          playerNumber: player.number,
          kind: isPoint ? 'point' : 'error',
          category: category,
          occurredAt: DateTime.now(),
        ),
      );
    _replaceMatch(match.copyWith(events: events));
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
    if (selectedMatch != null && _activeSection == 'stats') {
      return _buildStatsView(selectedMatch);
    }

    return _buildMatchListView();
  }

  Widget _buildMatchListView() {
    final matches = List<MatchGame>.from(_matches)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Punktewertung')),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoView(MatchGame match) {
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
              value: match.matchType,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punktewertung'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showMatchDetail(match.id),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 160,
                      child: FilledButton.icon(
                        key: const ValueKey('record-point-button'),
                        onPressed: () =>
                            _recordEventForMatch(match, isPoint: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 160,
                      child: FilledButton.icon(
                        key: const ValueKey('record-error-button'),
                        onPressed: () =>
                            _recordEventForMatch(match, isPoint: false),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsView(MatchGame match) {
    final points = _pointSummary(match);
    final errors = _errorSummary(match);
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
            _StatGroup(title: 'Punkte pro Art', entries: points),
            const SizedBox(height: 12),
            _StatGroup(title: 'Fehler pro Art', entries: errors),
            const SizedBox(height: 12),
            if (match.players.isNotEmpty) ...[
              const Text(
                'Spielerübersicht',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final player in match.players)
                Card(
                  child: ListTile(
                    title: Text(player.name),
                    subtitle: Text('Trikot ${player.number}'),
                    trailing: Text(
                      '${match.events.where((event) => event.playerId == player.id && event.kind == 'point').length}P / ${match.events.where((event) => event.playerId == player.id && event.kind == 'error').length}F',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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

  @override
  void dispose() {
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
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
