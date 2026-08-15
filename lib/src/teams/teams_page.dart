import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

class TeamPlayer {
  const TeamPlayer({
    required this.id,
    required this.name,
    required this.number,
    required this.birthDate,
    required this.position,
  });

  final int id;
  final String name;
  final int? number;
  final DateTime? birthDate;
  final String position;

  TeamPlayer copyWith({
    String? name,
    int? number,
    bool clearNumber = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? position,
  }) =>
      TeamPlayer(
        id: id,
        name: name ?? this.name,
        number: clearNumber ? null : (number ?? this.number),
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        position: position ?? this.position,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'number': number,
        'birthDateMillis': birthDate?.millisecondsSinceEpoch,
        'position': position,
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
    );
  }
}

class TeamCoach {
  const TeamCoach({required this.id, required this.name});

  final int id;
  final String name;

  TeamCoach copyWith({String? name}) =>
      TeamCoach(id: id, name: name ?? this.name);

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  static TeamCoach fromJson(Map<String, dynamic> data) => TeamCoach(
        id: data['id'] is num ? (data['id'] as num).toInt() : 0,
        name: data['name'] is String ? data['name'] as String : '',
      );
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
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerNumberController = TextEditingController();
  final TextEditingController _playerPositionController =
      TextEditingController();
  final TextEditingController _coachNameController = TextEditingController();
  int? _selectedTeamId;
  String? _activeSection;
  DateTime? _playerBirthDate;
  TeamPlayer? _editingPlayer;
  TeamCoach? _editingCoach;
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
    _coachNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final teams = await _repository.load();
    if (!mounted) return;
    setState(() {
      _teams
        ..clear()
        ..addAll(teams);
      _nextTeamId = _teams.isEmpty
          ? 1
          : _teams.map((team) => team.id).reduce((a, b) => a > b ? a : b) + 1;
      _isLoaded = true;
    });
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
    _playerBirthDate = null;
    _editingPlayer = null;
  }

  void _clearCoachForm() {
    _coachNameController.clear();
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
        ) ??
        TeamPlayer(
          id: nextId,
          name: name,
          number: number,
          birthDate: _playerBirthDate,
          position: _playerPositionController.text.trim(),
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
    final coach =
        editingCoach?.copyWith(name: name) ?? TeamCoach(id: nextId, name: name);
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
      _playerBirthDate = player.birthDate;
    });
  }

  void _startEditingCoach(TeamCoach coach) {
    setState(() {
      _editingCoach = coach;
      _coachNameController.text = coach.name;
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
    if (_activeSection == 'coaches') {
      return _buildCoaches(team);
    }
    return _buildTeamDetail(team);
  }

  Widget _buildTeamList() => Scaffold(
        appBar: AppBar(title: const Text('Teams')),
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
                    if (player.birthDate != null) _formatDate(player.birthDate!)
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Trainer bearbeiten',
                        onPressed: () => _startEditingCoach(coach),
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
