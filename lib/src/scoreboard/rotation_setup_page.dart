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
  late String _matchType;
  late RotationTeamState _left;
  late RotationTeamState _right;
  late int _servingSide;
  late int _consecutiveServePoints;
  bool _showCourt = true;
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
    _matchType = initial?.matchType ?? 'Freundschaftsspiel';
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
    if (volleyballLeagueOptions.contains(source.league)) {
      _changeLeague(source.league);
      setState(() => _matchType = matchTypeForTeamLeague(source.league));
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

  void _moveToBench(int side, RotationPlayer player) {
    final current = _teamAt(side);
    if (!current.positions.contains(player.id)) return;
    _replaceTeam(
      side,
      current.copyWith(
        positions:
            current.positions.map((id) => id == player.id ? null : id).toList(),
      ),
    );
  }

  Future<void> _selectPlayerForPosition(int side, int position) async {
    final team = _teamAt(side);
    if (team.players.isEmpty) return;
    final currentPlayerId =
        position < team.positions.length ? team.positions[position] : null;
    final selection = await showModalBottomSheet<_CourtPlayerSelection>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            ListTile(
              title: Text('Position ${position + 1}'),
              subtitle: Text(_displayName(side, side == 0 ? 'Blau' : 'Rot')),
            ),
            for (final player in team.players)
              ListTile(
                key: ValueKey(
                  'choose-player-$side-$position-${player.id}',
                ),
                leading: CircleAvatar(
                  child: Text(
                    player.number?.toString() ??
                        (player.name.isEmpty
                            ? '${position + 1}'
                            : player.name.characters.first),
                  ),
                ),
                title: Text(player.name),
                subtitle: Text(
                  team.positions.contains(player.id)
                      ? 'Position ${team.positions.indexOf(player.id) + 1}'
                      : 'Bank',
                ),
                trailing: player.id == currentPlayerId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(
                  _CourtPlayerSelection(player: player),
                ),
              ),
            if (currentPlayerId != null)
              ListTile(
                key: ValueKey('send-to-bank-$side-$position'),
                leading: const Icon(Icons.move_to_inbox_outlined),
                title: const Text('Auf die Bank setzen'),
                onTap: () => Navigator.of(sheetContext).pop(
                  const _CourtPlayerSelection(sendToBank: true),
                ),
              ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection.sendToBank) {
      final player = team.players
          .where((entry) => entry.id == currentPlayerId)
          .firstOrNull;
      if (player != null) _moveToBench(side, player);
      return;
    }
    final player = selection.player;
    if (player != null) _assignPlayer(side, position, player);
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
        matchType: _matchType,
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

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = rotationPlayerCount(_league);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _showCourt ? 'Spielinfos' : 'Zur Aufstellung',
          onPressed: () => setState(() => _showCourt = !_showCourt),
          icon: Icon(
            _showCourt ? Icons.info_outline : Icons.sports_volleyball,
          ),
        ),
        title: Text(_showCourt ? 'Aufstellung' : 'Spielinfos'),
        actions: [
          if (_showCourt)
            IconButton(
              tooltip: 'Seiten tauschen',
              onPressed: _swapSides,
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            key: const ValueKey('cancel-rotation-setup'),
            tooltip: 'Abbrechen',
            onPressed: _cancel,
            icon: const Icon(Icons.close),
          ),
          IconButton(
            key: const ValueKey('save-rotation-setup'),
            tooltip: 'Speichern',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _showCourt ? _buildLineupStep(count) : _buildInfoStep(),
      ),
    );
  }

  Widget _buildInfoStep() {
    return ListView(
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const ValueKey('rotation-match-type-select'),
          initialValue: _matchType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Spieltyp',
            border: OutlineInputBorder(),
          ),
          items: volleyballMatchTypeOptions
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (type) {
            if (type != null) setState(() => _matchType = type);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  _buildTeamHeader(0),
                  const SizedBox(height: 12),
                  _buildTeamHeader(1),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTeamHeader(0)),
                const SizedBox(width: 12),
                Expanded(child: _buildTeamHeader(1)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLineupStep(int count) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        _buildFullCourt(count),
        const SizedBox(height: 12),
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
                  _buildRosterEditor(0, count),
                  const SizedBox(height: 12),
                  _buildRosterEditor(1, count),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRosterEditor(0, count)),
                const SizedBox(width: 12),
                Expanded(child: _buildRosterEditor(1, count)),
              ],
            );
          },
        ),
      ],
    );
  }

  String _displayName(int side, String fallback) {
    final name = _teamNameControllers[side].text.trim();
    return name.isEmpty ? fallback : name;
  }

  Widget _buildTeamHeader(int side) {
    final team = _teamAt(side);
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
          ],
        ),
      ),
    );
  }

  Widget _buildRosterEditor(int side, int count) {
    final team = _teamAt(side);
    final activeIds = team.positions.take(count).whereType<String>().toSet();
    final bench =
        team.players.where((player) => !activeIds.contains(player.id)).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bank ${_displayName(side, side == 0 ? 'Blau' : 'Rot')} · ${bench.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Container(
              key: ValueKey('rotation-bank-$side'),
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: bench.isEmpty
                  ? team.players.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('Noch keine Spieler erfasst.'),
                          ),
                        )
                      : const SizedBox(height: 32)
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bench
                          .map((player) => _playerToken(side, player))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFullCourt(int count) {
    final layout = _courtLayout(count);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spielfeld · ${activeCount(0, count)}/$count',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Team Blau manuell rotieren',
                      onPressed: () => _rotate(0),
                      icon: const Icon(Icons.rotate_left),
                    ),
                    IconButton(
                      tooltip: 'Team Rot manuell rotieren',
                      onPressed: () => _rotate(1),
                      icon: const Icon(Icons.rotate_right),
                    ),
                    Expanded(
                      child: Text(
                        '${activeCount(1, count)}/$count · Spielfeld',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                AspectRatio(
                  aspectRatio: 2,
                  child: Container(
                    key: const ValueKey('rotation-court'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD89B5B),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CustomPaint(
                      painter: const _VolleyballCourtPainter(),
                      child: Stack(
                        children: [
                          for (final slot in layout) ...[
                            _courtPosition(
                              side: 0,
                              position: slot.position,
                              x: slot.x,
                              y: slot.y,
                            ),
                            _courtPosition(
                              side: 1,
                              position: slot.position,
                              x: 1 - slot.x,
                              y: slot.y,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  int activeCount(int side, int count) =>
      _teamAt(side).positions.take(count).whereType<String>().toSet().length;

  Widget _courtPosition({
    required int side,
    required int position,
    required double x,
    required double y,
  }) {
    final team = _teamAt(side);
    final playerId =
        position < team.positions.length ? team.positions[position] : null;
    final player =
        team.players.where((entry) => entry.id == playerId).firstOrNull;
    final teamColor =
        side == 0 ? const Color(0xFF1976D2) : const Color(0xFFC7434D);

    return Align(
      alignment: Alignment(x * 2 - 1, y * 2 - 1),
      child: Tooltip(
        message: 'Position ${position + 1} auswählen',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('rotation-position-$side-$position'),
            borderRadius: BorderRadius.circular(24),
            onTap: () => _selectPlayerForPosition(side, position),
            child: SizedBox(
              width: 76,
              height: 74,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: player == null ? Colors.white24 : teamColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ],
                        ),
                        child: player == null
                            ? const Icon(Icons.add,
                                color: Colors.white, size: 20)
                            : Text(
                                '${player.number ?? position + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      if (player != null)
                        SizedBox(
                          width: 74,
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 2)
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    top: 2,
                    left: 5,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${position + 1}',
                        style: TextStyle(
                          color: teamColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerToken(int side, RotationPlayer player) {
    final label = _playerLabel(player);
    return InputChip(
      key: ValueKey('rotation-bank-player-${side}-${player.id}'),
      label: Text(label, overflow: TextOverflow.ellipsis),
      avatar: const Icon(Icons.person_outline, size: 18),
      onDeleted: () => _removePlayer(side, player),
    );
  }

  String _playerLabel(RotationPlayer player) =>
      player.number == null ? player.name : '${player.number} · ${player.name}';
}

class _CourtPlayerSelection {
  const _CourtPlayerSelection({this.player, this.sendToBank = false});

  final RotationPlayer? player;
  final bool sendToBank;
}

class _VolleyballCourtPainter extends CustomPainter {
  const _VolleyballCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final width = size.width;
    final height = size.height;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, width - 2, height - 2),
      linePaint,
    );
    canvas.drawLine(Offset(width / 2, 0), Offset(width / 2, height), linePaint);
    canvas.drawLine(
      Offset(width * 0.25, 0),
      Offset(width * 0.25, height),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.75, 0),
      Offset(width * 0.75, height),
      linePaint,
    );
    final netPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(width / 2, 0),
      Offset(width / 2, height),
      netPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VolleyballCourtPainter oldDelegate) => false;
}
