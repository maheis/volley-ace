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

class MatchStatsState {
  const MatchStatsState({
    required this.players,
    required this.events,
  });

  static const MatchStatsState empty = MatchStatsState(
    players: <MatchPlayer>[],
    events: <MatchEvent>[],
  );

  final List<MatchPlayer> players;
  final List<MatchEvent> events;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'players': players.map((player) => player.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
      };

  static MatchStatsState fromJson(Map<String, dynamic>? data) {
    if (data == null) return empty;

    final playersData = data['players'];
    final eventsData = data['events'];

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

    return MatchStatsState(players: players, events: events);
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
  late final MatchStatsRepository _repository = MatchStatsRepository(
    widget.database,
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final List<MatchPlayer> _players = <MatchPlayer>[];
  final List<MatchEvent> _events = <MatchEvent>[];
  bool _isLoaded = false;
  int _nextPlayerId = 1;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final state = await _repository.load();
    if (!mounted) return;
    setState(() {
      _players.addAll(state.players);
      _events.addAll(state.events);
      _isLoaded = true;
      _nextPlayerId = state.players.isEmpty
          ? 1
          : state.players
                  .map((player) => player.id)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    });
  }

  Future<void> _persist() async {
    await _repository.save(
      MatchStatsState(
          players: List<MatchPlayer>.from(_players),
          events: List<MatchEvent>.from(_events)),
    );
  }

  void _addPlayer() {
    final name = _nameController.text.trim();
    final numberText = _numberController.text.trim();
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
        const SnackBar(content: Text('Die Trikotnummer muss eine Zahl sein.')),
      );
      return;
    }

    final player = MatchPlayer(id: _nextPlayerId++, name: name, number: number);
    setState(() {
      _players.add(player);
      _nameController.clear();
      _numberController.clear();
    });
    unawaited(_persist());
  }

  void _removePlayer(MatchPlayer player) {
    setState(() {
      _players.removeWhere((entry) => entry.id == player.id);
      _events.removeWhere((entry) => entry.playerId == player.id);
    });
    unawaited(_persist());
  }

  Future<void> _recordEvent({required bool isPoint}) async {
    if (_players.isEmpty) {
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
          children: _players
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

    setState(() {
      _events.add(
        MatchEvent(
          id: _events.length + 1,
          playerId: player.id,
          playerName: player.name,
          playerNumber: player.number,
          kind: isPoint ? 'point' : 'error',
          category: category,
          occurredAt: DateTime.now(),
        ),
      );
    });
    unawaited(_persist());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${player.name}: ${isPoint ? 'Punkt' : 'Fehler'} • $category'),
        ),
      );
    }
  }

  Map<String, int> _pointSummary() {
    final summary = <String, int>{};
    for (final event in _events.where((entry) => entry.kind == 'point')) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  Map<String, int> _errorSummary() {
    final summary = <String, int>{};
    for (final event in _events.where((entry) => entry.kind == 'error')) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final points = _pointSummary();
    final errors = _errorSummary();
    final totalPoints = _events.where((entry) => entry.kind == 'point').length;
    final totalErrors = _events.where((entry) => entry.kind == 'error').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Punktewertung')),
      body: !_isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'Punkte',
                                value: '$totalPoints',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'Fehler',
                                value: '$totalErrors',
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('player-name-input'),
                            controller: _nameController,
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
                            controller: _numberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Nr.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          key: const ValueKey('add-player-button'),
                          onPressed: _addPlayer,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Hinzufügen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_players.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('record-point-button'),
                              onPressed: () => _recordEvent(isPoint: true),
                              icon: const Icon(Icons.add_circle),
                              label: const Text('Punkt erfassen'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _recordEvent(isPoint: false),
                              icon: const Icon(Icons.error_outline),
                              label: const Text('Fehler erfassen'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Spieler',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _players.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          final playerPoints = _events
                              .where(
                                (event) =>
                                    event.playerId == player.id &&
                                    event.kind == 'point',
                              )
                              .length;
                          final playerErrors = _events
                              .where(
                                (event) =>
                                    event.playerId == player.id &&
                                    event.kind == 'error',
                              )
                              .length;

                          return ListTile(
                            title: Text(player.name),
                            subtitle: Text('Trikot ${player.number}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(label: Text('P $playerPoints')),
                                const SizedBox(width: 8),
                                Chip(label: Text('F $playerErrors')),
                                IconButton(
                                  onPressed: () => _removePlayer(player),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Spieler entfernen',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Noch keine Spieler angelegt.'),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Statistik',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _StatGroup(
                      title: 'Punkte pro Art',
                      entries: points,
                    ),
                    const SizedBox(height: 12),
                    _StatGroup(
                      title: 'Fehler pro Art',
                      entries: errors,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
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
