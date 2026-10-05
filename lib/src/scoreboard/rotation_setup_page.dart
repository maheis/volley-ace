import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../teams/teams_page.dart';
import 'rotation_state.dart';

class RotationSetupPage extends StatefulWidget {
  const RotationSetupPage({
    super.key,
    required this.database,
    this.initial,
  });

  final Database database;
  final ScoreboardRotationState? initial;

  @override
  State<RotationSetupPage> createState() => _RotationSetupPageState();
}

class _RotationSetupPageState extends State<RotationSetupPage> {
  late String _league;
  late RotationTeamState _left;
  late RotationTeamState _right;
  late int _servingSide;
  late int _consecutiveServePoints;
  final List<Team> _teams = <Team>[];
  final List<TextEditingController> _teamNameControllers =
      List<TextEditingController>.generate(2, (_) => TextEditingController());
  final List<TextEditingController> _playerNameControllers =
      List<TextEditingController>.generate(2, (_) => TextEditingController());
  final List<TextEditingController> _playerNumberControllers =
      List<TextEditingController>.generate(2, (_) => TextEditingController());

  RotationTeamState _teamAt(int side) => side == 0 ? _left : _right;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _league = initial?.league ?? 'Herren';
    _left = initial?.left ?? const RotationTeamState();
    _right = initial?.right ?? const RotationTeamState();
    _servingSide = initial?.servingSide ?? 0;
    _consecutiveServePoints = initial?.consecutiveServePoints ?? 0;
    _teamNameControllers[0].text = _left.name;
    _teamNameControllers[1].text = _right.name;
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final teams = await TeamsRepository(widget.database).load();
    if (!mounted) return;
    setState(() => _teams
      ..clear()
      ..addAll(teams));
  }

  @override
  void dispose() {
    for (final controller in [
      ..._teamNameControllers,
      ..._playerNameControllers,
      ..._playerNumberControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _replaceTeam(int side, RotationTeamState team) {
    setState(() {
      if (side == 0) {
        _left = team;
      } else {
        _right = team;
      }
      _teamNameControllers[side].text = team.name;
    });
  }

  void _loadTeam(int side, int? teamId) {
    final source = _teams.where((team) => team.id == teamId).firstOrNull;
    if (source == null) {
      _replaceTeam(
        side,
        _teamAt(side).copyWith(clearSourceTeamId: true),
      );
      return;
    }
    final players = source.players
        .map(
          (player) => RotationPlayer(
            id: 'team-${source.id}-${player.id}',
            name: player.name,
            number: player.number,
          ),
        )
        .toList();
    final count = rotationPlayerCount(_league);
    _replaceTeam(
      side,
      RotationTeamState(
        name: source.name,
        sourceTeamId: source.id,
        players: players,
        positions: List<String?>.generate(
          count,
          (index) => index < players.length ? players[index].id : null,
        ),
      ),
    );
  }

  RotationTeamState _resizeTeam(RotationTeamState team, int count) {
    final positions = List<String?>.generate(
      count,
      (index) => index < team.positions.length ? team.positions[index] : null,
    );
    final assigned = positions.whereType<String>().toSet();
    final bench = team.players.where((player) => !assigned.contains(player.id));
    for (var index = 0; index < positions.length; index++) {
      if (positions[index] != null) continue;
      final available = bench.where((player) => !assigned.contains(player.id));
      final next = available.firstOrNull;
      if (next == null) break;
      positions[index] = next.id;
      assigned.add(next.id);
    }
    return team.copyWith(positions: positions);
  }

  void _changeLeague(String league) {
    setState(() {
      _league = league;
      final count = rotationPlayerCount(league);
      _left = _resizeTeam(_left, count);
      _right = _resizeTeam(_right, count);
      _consecutiveServePoints = 0;
    });
  }

  void _addPlayer(int side) {
    final name = _playerNameControllers[side].text.trim();
    if (name.isEmpty) return;
    final number = int.tryParse(_playerNumberControllers[side].text.trim());
    final current = _teamAt(side);
    final player = RotationPlayer(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      number: number,
    );
    final positions = List<String?>.from(current.positions);
    final openPosition = positions.indexOf(null);
    if (openPosition >= 0) positions[openPosition] = player.id;
    _replaceTeam(
      side,
      current.copyWith(
        players: <RotationPlayer>[...current.players, player],
        positions: positions,
        clearSourceTeamId: true,
      ),
    );
    _playerNameControllers[side].clear();
    _playerNumberControllers[side].clear();
  }

  void _removePlayer(int side, RotationPlayer player) {
    final current = _teamAt(side);
    _replaceTeam(
      side,
      current.copyWith(
        players:
            current.players.where((entry) => entry.id != player.id).toList(),
        positions:
            current.positions.map((id) => id == player.id ? null : id).toList(),
      ),
    );
  }

  void _assignPlayer(int side, int position, RotationPlayer player) {
    final current = _teamAt(side);
    if (!current.players.any((entry) => entry.id == player.id)) return;
    final positions = List<String?>.from(current.positions);
    if (position < 0 || position >= positions.length) return;
    final oldPosition = positions.indexOf(player.id);
    final displaced = positions[position];
    positions[position] = player.id;
    if (oldPosition >= 0 && oldPosition != position) {
      positions[oldPosition] = displaced;
    }
    _replaceTeam(side, current.copyWith(positions: positions));
  }

  void _rotate(int side) {
    setState(() {
      if (side == 0) {
        _left = _rotationState.rotate(side).left;
      } else {
        _right = _rotationState.rotate(side).right;
      }
    });
  }

  ScoreboardRotationState get _rotationState => ScoreboardRotationState(
        league: _league,
        left: _teamAt(0).copyWith(name: _teamNameControllers[0].text.trim()),
        right: _teamAt(1).copyWith(name: _teamNameControllers[1].text.trim()),
        servingSide: _servingSide,
        consecutiveServePoints: _consecutiveServePoints,
      );

  void _swapSides() {
    setState(() {
      final team = _left;
      _left = _right;
      _right = team;
      final name = _teamNameControllers[0].text;
      _teamNameControllers[0].text = _teamNameControllers[1].text;
      _teamNameControllers[1].text = name;
      _servingSide = _servingSide == 0 ? 1 : 0;
    });
  }

  void _save() {
    Navigator.of(context).pop(_rotationState);
  }

  @override
  Widget build(BuildContext context) {
    final count = rotationPlayerCount(_league);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielaufstellung'),
        actions: [
          IconButton(
            tooltip: 'Seiten tauschen',
            onPressed: _swapSides,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('rotation-league-select'),
              initialValue: _league,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Spielklasse',
                border: OutlineInputBorder(),
              ),
              items: volleyballLeagueOptions
                  .map((league) => DropdownMenuItem(
                        value: league,
                        child: Text(
                            '$league · ${rotationPlayerCount(league)} Spieler'),
                      ))
                  .toList(),
              onChanged: (league) {
                if (league != null) _changeLeague(league);
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 0,
                  label: Text(_displayName(0, 'Blau')),
                  icon: const Icon(Icons.sports_volleyball),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(_displayName(1, 'Rot')),
                  icon: const Icon(Icons.sports_volleyball),
                ),
              ],
              selected: <int>{_servingSide},
              onSelectionChanged: (selection) =>
                  setState(() => _servingSide = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              'Aufschlagteam',
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      _buildTeamEditor(0, count),
                      const SizedBox(height: 12),
                      _buildTeamEditor(1, count),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTeamEditor(0, count)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTeamEditor(1, count)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('save-rotation-setup'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(int side, String fallback) {
    final name = _teamNameControllers[side].text.trim();
    return name.isEmpty ? fallback : name;
  }

  Widget _buildTeamEditor(int side, int count) {
    final team = _teamAt(side);
    final activeIds = team.positions.take(count).whereType<String>().toSet();
    final bench =
        team.players.where((player) => !activeIds.contains(player.id)).toList();
    final name = side == 0 ? 'Team A · Blau' : 'Team B · Rot';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('rotation-team-select-$side'),
              initialValue: team.sourceTeamId ?? -1,
              decoration: const InputDecoration(
                labelText: 'Spieler aus Team übernehmen',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Text('Kein Team'),
                ),
                ..._teams.map(
                  (source) => DropdownMenuItem<int>(
                    value: source.id,
                    child: Text(
                        source.name.isEmpty ? 'Unbenanntes Team' : source.name),
                  ),
                ),
              ],
              onChanged: (id) => _loadTeam(side, id == -1 ? null : id),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('rotation-team-name-$side'),
              controller: _teamNameControllers[side],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Teamname (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildCourt(side, count),
            const SizedBox(height: 12),
            Text('Bank · ${bench.length}',
                style: Theme.of(context).textTheme.titleSmall),
            if (bench.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bench
                    .map((player) => _playerToken(side, player, bench: true))
                    .toList(),
              ),
            if (team.players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Noch keine Spieler erfasst.'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey('rotation-player-name-$side'),
                    controller: _playerNameControllers[side],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Spielername',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addPlayer(side),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: ValueKey('rotation-player-number-$side'),
                    controller: _playerNumberControllers[side],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nr.',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addPlayer(side),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: 'Spieler hinzufügen',
                  onPressed: () => _addPlayer(side),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (team.players.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: team.players
                    .map(
                      (player) => InputChip(
                        key: ValueKey('rotation-player-${side}-${player.id}'),
                        label: Text(_playerLabel(player)),
                        onDeleted: () => _removePlayer(side, player),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourt(int side, int count) {
    final positions = _teamAt(side).positions;
    final positionOrder = count == 6
        ? const <int>[3, 2, 1, 4, 5, 0]
        : List<int>.generate(count, (index) => index);
    final court = Container(
      key: ValueKey('rotation-court-$side'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: positionOrder
            .map(
              (position) => _positionTarget(
                side,
                position,
                position < positions.length ? positions[position] : null,
              ),
            )
            .toList(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Spielfeld · ${activeCount(side, count)}/$count',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Manuell rotieren',
              onPressed: () => _rotate(side),
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
        court,
      ],
    );
  }

  int activeCount(int side, int count) =>
      _teamAt(side).positions.take(count).whereType<String>().toSet().length;

  Widget _positionTarget(int side, int position, String? playerId) {
    final team = _teamAt(side);
    final player =
        team.players.where((entry) => entry.id == playerId).firstOrNull;
    return DragTarget<RotationPlayer>(
      key: ValueKey('rotation-position-$side-$position'),
      onWillAcceptWithDetails: (details) =>
          team.players.any((entry) => entry.id == details.data.id),
      onAcceptWithDetails: (details) =>
          _assignPlayer(side, position, details.data),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return SizedBox(
          width: 104,
          height: 78,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlighted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  top: 4,
                  child: Text('${position + 1}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
                Center(
                  child: player == null
                      ? const Icon(Icons.add, size: 20)
                      : _playerToken(side, player),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _playerToken(int side, RotationPlayer player, {bool bench = false}) {
    final label = _playerLabel(player);
    final child = bench
        ? InputChip(
            label: Text(label, overflow: TextOverflow.ellipsis),
            avatar: const Icon(Icons.drag_indicator, size: 18),
          )
        : Container(
            width: 84,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.number != null)
                  Text('${player.number}',
                      style: Theme.of(context).textTheme.labelSmall),
                Text(
                  player.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          );
    return Tooltip(
      message: bench ? '$label einsetzen' : '$label verschieben',
      child: Draggable<RotationPlayer>(
        data: player,
        feedback: Material(
          color: Colors.transparent,
          child: Chip(label: Text(label)),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: child),
        child: child,
      ),
    );
  }

  String _playerLabel(RotationPlayer player) =>
      player.number == null ? player.name : '${player.number} · ${player.name}';
}
