import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';

class TeamPlayer {
  const TeamPlayer({
    required this.id,
    required this.name,
    required this.number,
    required this.birthDate,
    required this.position,
    required this.profile,
  });

  final int id;
  final String name;
  final int? number;
  final DateTime? birthDate;
  final String position;
  final String profile;

  TeamPlayer copyWith({
    String? name,
    int? number,
    bool clearNumber = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? position,
    String? profile,
  }) =>
      TeamPlayer(
        id: id,
        name: name ?? this.name,
        number: clearNumber ? null : (number ?? this.number),
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        position: position ?? this.position,
        profile: profile ?? this.profile,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'number': number,
        'birthDateMillis': birthDate?.millisecondsSinceEpoch,
        'position': position,
        'profile': profile,
      };

  static TeamPlayer fromJson(Map<String, dynamic> data) {
    final birthDateMillis = data['birthDateMillis'];
    return TeamPlayer(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      name: data['name'] is String ? data['name'] as String : '',
      number: data['number'] is num ? (data['number'] as num).toInt() : null,
      birthDate: birthDateMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(birthDateMillis.toInt())
          : null,
      position: data['position'] is String ? data['position'] as String : '',
      profile: data['profile'] is String ? data['profile'] as String : '',
    );
  }
}

class TeamCoach {
  const TeamCoach({
    required this.id,
    required this.name,
    required this.profile,
    required this.birthDate,
    required this.position,
  });

  final int id;
  final String name;
  final String profile;
  final DateTime? birthDate;
  final String position;

  TeamCoach copyWith({
    String? name,
    String? profile,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? position,
  }) =>
      TeamCoach(
        id: id,
        name: name ?? this.name,
        profile: profile ?? this.profile,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        position: position ?? this.position,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'profile': profile,
        'birthDateMillis': birthDate?.millisecondsSinceEpoch,
        'position': position,
      };

  static TeamCoach fromJson(Map<String, dynamic> data) {
    final birthDateMillis = data['birthDateMillis'];
    return TeamCoach(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      name: data['name'] is String ? data['name'] as String : '',
      profile: data['profile'] is String ? data['profile'] as String : '',
      birthDate: birthDateMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(birthDateMillis.toInt())
          : null,
      position: data['position'] is String ? data['position'] as String : '',
    );
  }
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.players,
    required this.coaches,
  });

  final int id;
  final String name;
  final List<TeamPlayer> players;
  final List<TeamCoach> coaches;

  Team copyWith({
    String? name,
    List<TeamPlayer>? players,
    List<TeamCoach>? coaches,
  }) =>
      Team(
        id: id,
        name: name ?? this.name,
        players: players ?? this.players,
        coaches: coaches ?? this.coaches,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'players': players.map((player) => player.toJson()).toList(),
        'coaches': coaches.map((coach) => coach.toJson()).toList(),
      };

  static Team fromJson(Map<String, dynamic> data) {
    List<T> readItems<T>(String key, T Function(Map<String, dynamic>) read) {
      final value = data[key];
      return value is List
          ? value
              .whereType<Map>()
              .map((item) => read(Map<String, dynamic>.from(item)))
              .toList()
          : <T>[];
    }

    return Team(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      name: data['name'] is String ? data['name'] as String : '',
      players: readItems('players', TeamPlayer.fromJson),
      coaches: readItems('coaches', TeamCoach.fromJson),
    );
  }
}

class TeamsRepository {
  TeamsRepository(Database database) : _database = database;

  static const String _recordKey = 'all';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('teams');

  final Database _database;

  Future<List<Team>> load() async {
    final data = await _store.record(_recordKey).get(_database);
    final value = data?['teams'];
    return value is List
        ? value
            .whereType<Map>()
            .map((item) => Team.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <Team>[];
  }

  Future<void> save(List<Team> teams) => _store.record(_recordKey).put(
        _database,
        <String, dynamic>{
          'teams': teams.map((team) => team.toJson()).toList(),
        },
      );
}

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key, required this.database});

  final Database database;

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  late final TeamsRepository _repository = TeamsRepository(widget.database);
  final List<Team> _teams = <Team>[];
  static final StoreRef<String, Map<String, dynamic>> _matchStatsStore =
      StoreRef<String, Map<String, dynamic>>('analytics');
  final List<Map<String, dynamic>> _matches = <Map<String, dynamic>>[];
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerNumberController = TextEditingController();
  final TextEditingController _playerPositionController =
      TextEditingController();
  final TextEditingController _playerProfileController =
      TextEditingController();
  final TextEditingController _coachNameController = TextEditingController();
  final TextEditingController _coachProfileController = TextEditingController();
  final TextEditingController _coachPositionController =
      TextEditingController();
  int? _selectedTeamId;
  String? _activeSection;
  DateTime? _playerBirthDate;
  DateTime? _coachBirthDate;
  TeamPlayer? _editingPlayer;
  TeamCoach? _editingCoach;
  int? _selectedPlayerId;
  int? _selectedCoachId;
  int _nextTeamId = 1;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _playerNameController.dispose();
    _playerNumberController.dispose();
    _playerPositionController.dispose();
    _playerProfileController.dispose();
    _coachNameController.dispose();
    _coachProfileController.dispose();
    _coachPositionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      _repository.load(),
      _matchStatsStore.record('match_stats').get(widget.database),
    ]);
    final teams = results[0] as List<Team>;
    final matchStats = results[1] as Map<String, dynamic>?;
    final storedMatches = matchStats?['matches'];
    if (!mounted) return;
    setState(() {
      _teams
        ..clear()
        ..addAll(teams);
      _matches
        ..clear()
        ..addAll(
          storedMatches is List
              ? storedMatches
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
              : <Map<String, dynamic>>[],
        );
      _nextTeamId = _teams.isEmpty
          ? 1
          : _teams.map((team) => team.id).reduce((a, b) => a > b ? a : b) + 1;
      _isLoaded = true;
    });
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

  Future<void> _persist() => _repository.save(_teams);

  Team? get _selectedTeam {
    for (final team in _teams) {
      if (team.id == _selectedTeamId) return team;
    }
    return null;
  }

  void _openTeam(Team team, {String? section}) {
    if (section == 'info') _teamNameController.text = team.name;
    if (section == 'players') {
      _clearPlayerForm();
    }
    if (section == 'coaches') _clearCoachForm();
    setState(() {
      _selectedTeamId = team.id;
      _activeSection = section;
    });
  }

  void _closeTeam() => setState(() {
        _selectedTeamId = null;
        _activeSection = null;
        _selectedPlayerId = null;
        _selectedCoachId = null;
      });

  void _showPlayerStats(TeamPlayer player) => setState(() {
        _selectedPlayerId = player.id;
        _activeSection = 'player-stats';
      });

  void _showCoachStats(TeamCoach coach) => setState(() {
        _selectedCoachId = coach.id;
        _activeSection = 'coach-stats';
      });

  void _createTeam() {
    final team = Team(
      id: _nextTeamId++,
      name: '',
      players: const <TeamPlayer>[],
      coaches: const <TeamCoach>[],
    );
    _teams.add(team);
    unawaited(_persist());
    _openTeam(team, section: 'info');
  }

  void _replaceTeam(Team updated) {
    setState(() {
      final index = _teams.indexWhere((team) => team.id == updated.id);
      _teams[index] = updated;
    });
    unawaited(_persist());
  }

  Future<void> _deleteTeam(Team team) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Team löschen?'),
        content: Text(
          '„${team.name.isEmpty ? 'Unbenanntes Team' : team.name}“ wird unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() {
      _teams.removeWhere((entry) => entry.id == team.id);
      _selectedTeamId = null;
      _activeSection = null;
    });
    unawaited(_persist());
  }

  void _clearPlayerForm() {
    _playerNameController.clear();
    _playerNumberController.clear();
    _playerPositionController.clear();
    _playerProfileController.clear();
    _playerBirthDate = null;
    _editingPlayer = null;
  }

  void _clearCoachForm() {
    _coachNameController.clear();
    _coachProfileController.clear();
    _coachPositionController.clear();
    _coachBirthDate = null;
    _editingCoach = null;
  }

  void _savePlayer(Team team) {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ein Spielername ist erforderlich.')),
      );
      return;
    }
    final numberText = _playerNumberController.text.trim();
    final number = numberText.isEmpty ? null : int.tryParse(numberText);
    if (numberText.isNotEmpty && number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trikotnummer muss eine Zahl sein.')),
      );
      return;
    }
    final editingPlayer = _editingPlayer;
    final nextId = team.players.isEmpty
        ? 1
        : team.players
                .map((player) => player.id)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final player = editingPlayer?.copyWith(
          name: name,
          number: number,
          clearNumber: numberText.isEmpty,
          birthDate: _playerBirthDate,
          clearBirthDate: _playerBirthDate == null,
          position: _playerPositionController.text.trim(),
          profile: _playerProfileController.text.trim(),
        ) ??
        TeamPlayer(
          id: nextId,
          name: name,
          number: number,
          birthDate: _playerBirthDate,
          position: _playerPositionController.text.trim(),
          profile: _playerProfileController.text.trim(),
        );
    _replaceTeam(team.copyWith(
      players: editingPlayer == null
          ? <TeamPlayer>[...team.players, player]
          : team.players
              .map((entry) => entry.id == player.id ? player : entry)
              .toList(),
    ));
    setState(_clearPlayerForm);
  }

  void _saveCoach(Team team) {
    final name = _coachNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ein Trainername ist erforderlich.')),
      );
      return;
    }
    final editingCoach = _editingCoach;
    final nextId = team.coaches.isEmpty
        ? 1
        : team.coaches
                .map((coach) => coach.id)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final profile = _coachProfileController.text.trim();
    final coach = editingCoach?.copyWith(
          name: name,
          profile: profile,
          birthDate: _coachBirthDate,
          clearBirthDate: _coachBirthDate == null,
          position: _coachPositionController.text.trim(),
        ) ??
        TeamCoach(
          id: nextId,
          name: name,
          profile: profile,
          birthDate: _coachBirthDate,
          position: _coachPositionController.text.trim(),
        );
    _replaceTeam(team.copyWith(
      coaches: editingCoach == null
          ? <TeamCoach>[...team.coaches, coach]
          : team.coaches
              .map((entry) => entry.id == coach.id ? coach : entry)
              .toList(),
    ));
    setState(_clearCoachForm);
  }

  void _startEditingPlayer(TeamPlayer player) {
    setState(() {
      _editingPlayer = player;
      _playerNameController.text = player.name;
      _playerNumberController.text = player.number?.toString() ?? '';
      _playerPositionController.text = player.position;
      _playerProfileController.text = player.profile;
      _playerBirthDate = player.birthDate;
    });
  }

  void _startEditingCoach(TeamCoach coach) {
    setState(() {
      _editingCoach = coach;
      _coachNameController.text = coach.name;
      _coachProfileController.text = coach.profile;
      _coachPositionController.text = coach.position;
      _coachBirthDate = coach.birthDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final team = _selectedTeam;
    if (team == null) {
      return _buildTeamList();
    }
    if (_activeSection == 'info') {
      return _buildInfo(team);
    }
    if (_activeSection == 'players') {
      return _buildPlayers(team);
    }
    if (_activeSection == 'player-stats') {
      final player = team.players.cast<TeamPlayer?>().firstWhere(
            (entry) => entry?.id == _selectedPlayerId,
            orElse: () => null,
          );
      if (player != null) return _buildPlayerStats(team, player);
    }
    if (_activeSection == 'coach-stats') {
      final coach = team.coaches.cast<TeamCoach?>().firstWhere(
            (entry) => entry?.id == _selectedCoachId,
            orElse: () => null,
          );
      if (coach != null) return _buildCoachStats(team, coach);
    }
    if (_activeSection == 'coaches') {
      return _buildCoaches(team);
    }
    return _buildTeamDetail(team);
  }

  Widget _buildTeamList() => Scaffold(
        appBar: AppBar(
          title: const Text('Teams'),
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
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const ValueKey('new-team-button'),
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: const Text('Team anlegen'),
                subtitle: const Text('Team, Spieler und Trainer erfassen'),
                onTap: _createTeam,
              ),
            ),
            const SizedBox(height: 12),
            if (_teams.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Noch keine Teams angelegt.')))
            else
              for (final team in _teams)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                        team.name.isEmpty ? 'Unbenanntes Team' : team.name),
                    subtitle: Text(
                        '${team.players.length} Spieler • ${team.coaches.length} Trainer'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openTeam(team),
                  ),
                ),
          ],
        ),
      );

  Widget _buildTeamDetail(Team team) => Scaffold(
        appBar: AppBar(
          title: Text(team.name.isEmpty ? 'Team' : team.name),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back), onPressed: _closeTeam),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DetailTile(
                title: 'Info',
                subtitle: 'Teamname festlegen',
                icon: Icons.info_outline,
                onTap: () => _openTeam(team, section: 'info')),
            const SizedBox(height: 12),
            _DetailTile(
                title: 'Spieler',
                subtitle: '${team.players.length} Spieler',
                icon: Icons.people_outline,
                onTap: () => _openTeam(team, section: 'players')),
            const SizedBox(height: 12),
            _DetailTile(
                title: 'Trainer',
                subtitle: '${team.coaches.length} Trainer',
                icon: Icons.sports_outlined,
                onTap: () => _openTeam(team, section: 'coaches')),
            const SizedBox(height: 12),
            _DetailTile(
                title: 'Team löschen',
                subtitle: 'Team und Mitglieder unwiderruflich entfernen',
                icon: Icons.delete_outline,
                color: Colors.red,
                onTap: () => _deleteTeam(team)),
          ],
        ),
      );

  Widget _buildInfo(Team team) => Scaffold(
        appBar: _sectionAppBar('Info', team),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const ValueKey('team-name-input'),
            controller: _teamNameController,
            autofocus: true,
            onChanged: (value) =>
                _replaceTeam(team.copyWith(name: value.trim())),
            decoration: const InputDecoration(
                labelText: 'Teamname', border: OutlineInputBorder()),
          ),
        ),
      );

  Widget _buildPlayers(Team team) => Scaffold(
        appBar: _sectionAppBar('Spieler', team),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                key: const ValueKey('team-player-name-input'),
                controller: _playerNameController,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                key: const ValueKey('team-player-number-input'),
                controller: _playerNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Trikotnummer', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                key: const ValueKey('team-player-position-input'),
                controller: _playerPositionController,
                decoration: const InputDecoration(
                    labelText: 'Position', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('team-player-profile-input'),
              controller: _playerProfileController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Spielerprofil',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Geburtsdatum', border: OutlineInputBorder()),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(_playerBirthDate == null
                    ? 'Nicht angegeben'
                    : _formatDate(_playerBirthDate!)),
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _playerBirthDate ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now());
                  if (date != null && mounted) {
                    setState(() => _playerBirthDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
                key: const ValueKey('add-team-player-button'),
                onPressed: () => _savePlayer(team),
                icon: Icon(
                    _editingPlayer == null ? Icons.person_add : Icons.save),
                label: Text(
                  _editingPlayer == null ? 'Spieler hinzufügen' : 'Speichern',
                )),
            if (_editingPlayer != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Bearbeitung abbrechen',
                  onPressed: () => setState(_clearPlayerForm),
                ),
              ),
            const SizedBox(height: 24),
            if (team.players.isEmpty)
              const Text('Noch keine Spieler angelegt.')
            else
              for (final player in team.players)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(player.name),
                  subtitle: Text([
                    if (player.number != null) 'Trikot ${player.number}',
                    if (player.position.isNotEmpty) player.position,
                    if (player.birthDate != null)
                      _formatDate(player.birthDate!),
                    if (player.profile.isNotEmpty) player.profile,
                  ].join(' • ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Spieler bearbeiten',
                        onPressed: () => _startEditingPlayer(player),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bar_chart_outlined),
                        tooltip: 'Spielerstatistik',
                        onPressed: () => _showPlayerStats(player),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Spieler entfernen',
                        onPressed: () => _replaceTeam(team.copyWith(
                            players: team.players
                                .where((entry) => entry.id != player.id)
                                .toList())),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );

  Widget _buildPlayerStats(Team team, TeamPlayer player) {
    final games = <_PlayerMatchStats>[];
    for (final match in _matches) {
      if (match['teamId'] is! num ||
          (match['teamId'] as num).toInt() != team.id) {
        continue;
      }
      final players = match['players'];
      if (players is! List) continue;
      final matchPlayer = players.whereType<Map>().cast<Map?>().firstWhere(
            (entry) =>
                entry?['teamPlayerId'] is num &&
                (entry?['teamPlayerId'] as num).toInt() == player.id,
            orElse: () => null,
          );
      if (matchPlayer == null || matchPlayer['id'] is! num) continue;
      final playerId = (matchPlayer['id'] as num).toInt();
      final events = match['events'];
      final playerEvents = events is List
          ? events
              .whereType<Map>()
              .where((event) =>
                  event['playerId'] is num &&
                  (event['playerId'] as num).toInt() == playerId)
              .map((event) => Map<String, dynamic>.from(event))
              .toList()
          : <Map<String, dynamic>>[];
      games.add(_PlayerMatchStats(match: match, events: playerEvents));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistik: ${player.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _openTeam(team, section: 'players'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (games.isEmpty)
            const Text(
                'Für diesen Spieler wurden noch keine Punktewertungen erfasst.')
          else ...[
            _MatchParticipationTable(games: games),
            const SizedBox(height: 12),
            _PlayerCategoryStatsTable(
              title: 'Punkte pro Art',
              kind: 'point',
              games: games,
            ),
            const SizedBox(height: 12),
            _PlayerCategoryStatsTable(
              title: 'Fehler pro Art',
              kind: 'error',
              games: games,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoachStats(Team team, TeamCoach coach) {
    final matches = _matches.where((match) {
      if (match['teamId'] is! num ||
          (match['teamId'] as num).toInt() != team.id) {
        return false;
      }
      final coaches = match['coaches'];
      return coaches is List &&
          coaches.whereType<Map>().any(
                (entry) =>
                    entry['id'] is num &&
                    (entry['id'] as num).toInt() == coach.id,
              );
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistik: ${coach.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _openTeam(team, section: 'coaches'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (matches.isEmpty)
            const Text(
                'Für diesen Trainer wurden noch keine Teilnahmen erfasst.')
          else
            _CoachParticipationTable(matches: matches),
        ],
      ),
    );
  }

  Widget _buildCoaches(Team team) => Scaffold(
        appBar: _sectionAppBar('Trainer', team),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                key: const ValueKey('team-coach-name-input'),
                controller: _coachNameController,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('team-coach-position-input'),
              controller: _coachPositionController,
              decoration: const InputDecoration(
                labelText: 'Position',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Geburtsdatum',
                border: OutlineInputBorder(),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(_coachBirthDate == null
                    ? 'Nicht angegeben'
                    : _formatDate(_coachBirthDate!)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _coachBirthDate ?? DateTime(1980),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && mounted) {
                    setState(() => _coachBirthDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('team-coach-profile-input'),
              controller: _coachProfileController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Trainerprofil',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
                key: const ValueKey('add-team-coach-button'),
                onPressed: () => _saveCoach(team),
                icon:
                    Icon(_editingCoach == null ? Icons.person_add : Icons.save),
                label: Text(
                  _editingCoach == null ? 'Trainer hinzufügen' : 'Speichern',
                )),
            if (_editingCoach != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Bearbeitung abbrechen',
                  onPressed: () => setState(_clearCoachForm),
                ),
              ),
            const SizedBox(height: 24),
            if (team.coaches.isEmpty)
              const Text('Noch keine Trainer angelegt.')
            else
              for (final coach in team.coaches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(coach.name),
                  subtitle: Text([
                    if (coach.position.isNotEmpty) coach.position,
                    if (coach.birthDate != null) _formatDate(coach.birthDate!),
                    if (coach.profile.isNotEmpty) coach.profile,
                  ].join(' • ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Trainer bearbeiten',
                        onPressed: () => _startEditingCoach(coach),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bar_chart_outlined),
                        tooltip: 'Trainerstatistik',
                        onPressed: () => _showCoachStats(coach),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Trainer entfernen',
                        onPressed: () => _replaceTeam(team.copyWith(
                            coaches: team.coaches
                                .where((entry) => entry.id != coach.id)
                                .toList())),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );

  AppBar _sectionAppBar(String title, Team team) => AppBar(
        title: Text(title),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _openTeam(team)),
      );

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _DetailTile extends StatelessWidget {
  const _DetailTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.color});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: TextStyle(color: color)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _PlayerMatchStats {
  const _PlayerMatchStats({required this.match, required this.events});

  final Map<String, dynamic> match;
  final List<Map<String, dynamic>> events;
}

class _MatchParticipationTable extends StatelessWidget {
  const _MatchParticipationTable({required this.games});

  final List<_PlayerMatchStats> games;

  @override
  Widget build(BuildContext context) => _StatsTableCard(
        title: 'Teilgenommene Spiele',
        table: DataTable(
          border: TableBorder(
            verticalInside: BorderSide(color: Theme.of(context).dividerColor),
          ),
          columns: const [
            DataColumn(label: Text('Spiel')),
            DataColumn(label: Text('Typ')),
            DataColumn(label: Text('Punkte'), numeric: true),
            DataColumn(label: Text('Fehler'), numeric: true),
          ],
          rows: [
            for (final game in games)
              DataRow(cells: [
                DataCell(Text(_matchLabel(game.match))),
                DataCell(Text(_matchType(game.match))),
                DataCell(Text('${_countEvents(game.events, 'point')}')),
                DataCell(Text('${_countEvents(game.events, 'error')}')),
              ]),
          ],
        ),
      );

  static String _matchLabel(Map<String, dynamic> match) {
    final opponent = match['opponentTeam'];
    final opponentLabel =
        opponent is String && opponent.isNotEmpty ? 'vs. $opponent' : 'Spiel';
    final dateMillis = match['matchDateTimeMillis'];
    if (dateMillis is! num) return opponentLabel;
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis.toInt());
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return '$opponentLabel / $formattedDate';
  }

  static String _matchType(Map<String, dynamic> match) =>
      match['matchType'] is String ? match['matchType'] as String : '-';

  static int _countEvents(List<Map<String, dynamic>> events, String kind) =>
      events.where((event) => event['kind'] == kind).length;
}

class _PlayerCategoryStatsTable extends StatelessWidget {
  const _PlayerCategoryStatsTable({
    required this.title,
    required this.kind,
    required this.games,
  });

  final String title;
  final String kind;
  final List<_PlayerMatchStats> games;

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      for (final game in games)
        for (final event in game.events)
          if (event['kind'] == kind && event['category'] is String)
            event['category'] as String,
    }.toList()
      ..sort();
    final summaries = [for (final game in games) _summaryFor(game.events)];
    return _StatsTableCard(
      title: title,
      table: DataTable(
        border: TableBorder(
          verticalInside: BorderSide(color: Theme.of(context).dividerColor),
        ),
        columns: [
          const DataColumn(label: Text('Spiel')),
          for (final category in categories)
            DataColumn(
              label: Text(category),
              numeric: true,
            ),
          const DataColumn(
            label:
                Text('Gesamt', style: TextStyle(fontWeight: FontWeight.bold)),
            numeric: true,
          ),
        ],
        rows: [
          for (var index = 0; index < games.length; index++)
            DataRow(cells: [
              DataCell(Text(
                  _MatchParticipationTable._matchLabel(games[index].match))),
              for (final category in categories)
                DataCell(Text('${summaries[index][category] ?? 0}')),
              DataCell(
                Text(
                  '${summaries[index].values.fold<int>(0, (total, value) => total + value)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          DataRow(
            cells: [
              const DataCell(
                Text('Gesamt', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final category in categories)
                DataCell(
                  Text(
                    '${summaries.fold<int>(0, (total, summary) => total + (summary[category] ?? 0))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              DataCell(
                Text(
                  '${summaries.fold<int>(0, (total, summary) => total + summary.values.fold<int>(0, (rowTotal, value) => rowTotal + value))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _summaryFor(List<Map<String, dynamic>> events) {
    final summary = <String, int>{};
    for (final event in events.where((entry) => entry['kind'] == kind)) {
      final category = event['category'] is String
          ? event['category'] as String
          : 'Sonstiges';
      summary[category] = (summary[category] ?? 0) + 1;
    }
    return summary;
  }
}

class _CoachParticipationTable extends StatelessWidget {
  const _CoachParticipationTable({required this.matches});

  final List<Map<String, dynamic>> matches;

  @override
  Widget build(BuildContext context) => _StatsTableCard(
        title: 'Teilgenommene Spiele',
        table: DataTable(
          border: TableBorder(
            verticalInside: BorderSide(color: Theme.of(context).dividerColor),
          ),
          columns: const [
            DataColumn(label: Text('Spiel')),
            DataColumn(label: Text('Typ')),
          ],
          rows: [
            for (final match in matches)
              DataRow(cells: [
                DataCell(Text(_MatchParticipationTable._matchLabel(match))),
                DataCell(Text(_MatchParticipationTable._matchType(match))),
              ]),
          ],
        ),
      );
}

class _StatsTableCard extends StatelessWidget {
  const _StatsTableCard({required this.title, required this.table});

  final String title;
  final DataTable table;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              ),
            ],
          ),
        ),
      );
}
