import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import 'teams_page.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key, required this.database, this.initialPersonId});

  final Database database;
  final int? initialPersonId;

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late final _repository = PeopleRepository(widget.database);
  final _filter = TextEditingController();
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<LocalPerson> _people = [];
  List<Team> _teams = [];
  LocalPerson? _person;
  DateTime? _birthDate;
  bool _isPlayer = true;
  bool _loading = true;
  bool _saving = false;
  bool _initialOpened = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _filter.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final directory = await _repository.loadDirectory();
      if (!mounted) return;
      setState(() {
        _people = directory.people
            .where((person) => person.isPlayer || person.isCoach)
            .toList()
          ..sort((first, second) => first.id.compareTo(second.id));
        _teams = directory.teams
          ..sort((first, second) => first.name.compareTo(second.name));
        _loading = false;
        _error = null;
        if (!_initialOpened) {
          _initialOpened = true;
          final initial = _people
              .where((person) => person.id == widget.initialPersonId)
              .firstOrNull;
          if (initial != null) _setPerson(initial);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Personen konnten nicht geladen werden: $error';
        });
      }
    }
  }

  List<Team> _linkedTeams(LocalPerson person) => _teams.where((team) {
        return team.players.any((player) => player.personId == person.id) ||
            team.coaches.any((coach) => coach.personId == person.id);
      }).toList();

  void _setPerson(LocalPerson person) {
    _person = person;
    _name.text = person.name;
    _birthDate = person.birthDate;
    _isPlayer = person.isPlayer;
  }

  void _openPerson(LocalPerson person) => setState(() => _setPerson(person));

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await _repository.savePerson(_person!.copyWith(
        name: _name.text,
        birthDate: _birthDate,
        clearBirthDate: _birthDate == null,
        isPlayer: _person!.id == 0 ? _isPlayer : _person!.isPlayer,
        isCoach: _person!.id == 0 ? !_isPlayer : _person!.isCoach,
      ));
      if (!mounted) return;
      setState(() => _setPerson(saved));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Person gespeichert.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speichern fehlgeschlagen: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openTeam(Team team) async {
    final person = _person!;
    final coachOnly = person.isCoach &&
        !team.players.any(
          (player) => player.personId == person.id,
        );
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => TeamsPage(
          database: widget.database,
          initialTeamId: team.id,
          initialSection: coachOnly ? 'coaches' : 'players'),
    ));
    if (mounted) await _load();
  }

  Future<void> _linkTeam() async {
    final person = _person!;
    final linkedIds = _linkedTeams(person).map((team) => team.id).toSet();
    final available =
        _teams.where((team) => !linkedIds.contains(team.id)).toList();
    final selected = await showModalBottomSheet<Team>(
      context: context,
      builder: (context) => SafeArea(
          child: ListView(
        shrinkWrap: true,
        children: [
          for (final team in available)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title:
                  Text(team.name.isEmpty ? 'Unbenannte Mannschaft' : team.name),
              onTap: () => Navigator.of(context).pop(team),
            ),
        ],
      )),
    );
    if (selected == null || !mounted) return;
    try {
      await _repository.linkPerson(person.id, selected.id);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verknüpfung fehlgeschlagen: $error')));
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _birthDate = date);
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Widget _buildList() {
    final tokens = _filter.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final visible = _people.where((person) {
      final text =
          '${person.id} ${person.name} ${_linkedTeams(person).map((team) => team.name).join(' ')}'
              .toLowerCase();
      return tokens.every(text.contains);
    }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          key: const ValueKey('players-filter'),
          controller: _filter,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Spieler / Trainer / Mannschaft',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _filter.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Filter löschen',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_filter.clear),
                  ),
          ),
        ),
      ),
      Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(_people.isEmpty
                      ? 'Noch keine Spieler oder Trainer angelegt.'
                      : 'Keine Spieler oder Trainer gefunden.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final person = visible[index];
                    final teams = _linkedTeams(person);
                    final roles = [
                      if (person.isPlayer) 'Spieler',
                      if (person.isCoach) 'Trainer',
                    ].join(' · ');
                    return Card(
                      key: ValueKey('player-row-${person.id}'),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: Icon(
                            person.isCoach && !person.isPlayer
                                ? Icons.co_present_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$roles · ID ${person.id}${person.birthDate == null ? '' : ' · ${_date(person.birthDate!)}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              teams.isEmpty
                                  ? 'Keine Mannschaft'
                                  : teams.map((team) => team.name).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPerson(person),
                      ),
                    );
                  },
                )),
    ]);
  }

  Widget _buildForm(LocalPerson person) {
    final linked = _linkedTeams(person);
    return Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (person.id != 0) ...[
          Text('ID ${person.id}'),
          const SizedBox(height: 12)
        ],
        if (person.id == 0) ...[
          SegmentedButton<bool>(
            key: const ValueKey('new-person-role'),
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.person_outline),
                label: Text('Spieler'),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.co_present_outlined),
                label: Text('Trainer'),
              ),
            ],
            selected: {_isPlayer},
            onSelectionChanged: (selection) {
              setState(() => _isPlayer = selection.first);
            },
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            'Rolle: ${[
              if (person.isPlayer) 'Spieler',
              if (person.isCoach) 'Trainer',
            ].join(' · ')}',
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          key: const ValueKey('player-name-input'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Name', border: OutlineInputBorder()),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Name erforderlich'
              : null,
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Geburtsdatum', border: OutlineInputBorder()),
          child: ListTile(
            key: const ValueKey('player-birthdate-input'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(
                _birthDate == null ? 'Nicht angegeben' : _date(_birthDate!)),
            onTap: _pickBirthDate,
            trailing: _birthDate == null
                ? null
                : IconButton(
                    key: const ValueKey('player-birthdate-clear'),
                    tooltip: 'Geburtsdatum entfernen',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _birthDate = null),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Mannschaften', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (linked.isEmpty) const Text('Keine Mannschaft'),
        for (final team in linked)
          ListTile(
            key: ValueKey('player-team-${team.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title:
                Text(team.name.isEmpty ? 'Unbenannte Mannschaft' : team.name),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openTeam(team),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('link-player-team'),
          onPressed: person.id == 0 || linked.length == _teams.length || _saving
              ? null
              : _linkTeam,
          icon: const Icon(Icons.add_link),
          label: const Text('Mannschaft verknüpfen'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _person == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_saving) setState(() => _person = null);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_person == null
                ? 'Spieler / Trainer'
                : _person!.id == 0
                    ? _isPlayer
                        ? 'Neuer Spieler'
                        : 'Neuer Trainer'
                    : _person!.name),
            leading: _person == null
                ? null
                : IconButton(
                    tooltip: 'Zurück zu Spielern',
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        _saving ? null : () => setState(() => _person = null),
                  ),
            actions: [
              if (_person == null)
                PopupMenuButton<bool>(
                  key: const ValueKey('new-player-button'),
                  tooltip: 'Spieler oder Trainer hinzufügen',
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  enabled: !_loading,
                  onSelected: (isPlayer) => _openPerson(LocalPerson(
                    id: 0,
                    memberNumber: 0,
                    name: '',
                    isPlayer: isPlayer,
                    isCoach: !isPlayer,
                  )),
                  itemBuilder: (context) => const [
                    PopupMenuItem<bool>(
                      value: true,
                      child: Text('Spieler hinzufügen'),
                    ),
                    PopupMenuItem<bool>(
                      value: false,
                      child: Text('Trainer hinzufügen'),
                    ),
                  ],
                )
              else
                IconButton(
                  key: const ValueKey('player-save-button'),
                  tooltip: 'Speichern',
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _saving ? null : _save,
                ),
            ],
          ),
          body: SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!),
                          TextButton(
                              onPressed: _load,
                              child: const Text('Erneut versuchen')),
                        ]))
                      : _person == null
                          ? _buildList()
                          : _buildForm(_person!)),
        ),
      );
}
