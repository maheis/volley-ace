import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../teams/teams_page.dart';

class TrainingAttendance {
  const TrainingAttendance._();

  static const String participating = 'participating';
  static const String excused = 'excused';
  static const String unexcused = 'unexcused';
}

class TrainingExercise {
  static const List<String> types = <String>[
    'Aufwärmen',
    'Technik',
    'Taktik',
    'Spiel',
    'Kraft',
    'Ausdauer',
    'Koordination',
    'Dehnen',
    'Cooldown',
  ];

  const TrainingExercise({
    required this.id,
    required this.title,
    required this.type,
    required this.goal,
    required this.duration,
    required this.description,
    required this.status,
  });

  final int id;
  final String title;
  final String type;
  final String goal;
  final String duration;
  final String description;
  final String status;

  TrainingExercise copyWith({String? status}) => TrainingExercise(
        id: id,
        title: title,
        type: type,
        goal: goal,
        duration: duration,
        description: description,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'type': type,
        'goal': goal,
        'duration': duration,
        'description': description,
        'status': status,
      };

  static TrainingExercise fromJson(Map<String, dynamic> data) =>
      TrainingExercise(
        id: data['id'] is num ? (data['id'] as num).toInt() : 1,
        title: data['title'] is String ? data['title'] as String : 'Übung',
        type: data['type'] is String ? data['type'] as String : 'Technik',
        goal: data['goal'] is String ? data['goal'] as String : '',
        duration: data['duration'] is String ? data['duration'] as String : '',
        description:
            data['description'] is String ? data['description'] as String : '',
        status: data['status'] is String ? data['status'] as String : '',
      );
}

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.name,
    required this.teamId,
    required this.date,
    required this.location,
    required this.duration,
    required this.exercises,
    required this.attendance,
    required this.comments,
  });

  final int id;
  final String name;
  final int? teamId;
  final DateTime date;
  final String location;
  final String duration;
  final List<TrainingExercise> exercises;
  final Map<String, String> attendance;
  final Map<String, String> comments;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'teamId': teamId,
        'dateMillis': date.millisecondsSinceEpoch,
        'location': location,
        'duration': duration,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
        'attendance': attendance,
        'comments': comments,
      };

  static TrainingSession fromJson(Map<String, dynamic> data) {
    Map<String, String> readMap(String key) {
      final value = data[key];
      return value is Map
          ? value.map(
              (entryKey, entryValue) =>
                  MapEntry(entryKey.toString(), entryValue.toString()),
            )
          : <String, String>{};
    }

    final storedExercises = data['exercises'];

    return TrainingSession(
      id: data['id'] is num ? (data['id'] as num).toInt() : 1,
      name: data['name'] is String ? data['name'] as String : 'Training',
      teamId: data['teamId'] is num ? (data['teamId'] as num).toInt() : null,
      date: data['dateMillis'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['dateMillis'] as num).toInt(),
            )
          : DateTime.now(),
      location: data['location'] is String ? data['location'] as String : '',
      duration: data['duration'] is String ? data['duration'] as String : '',
      exercises: storedExercises is List
          ? storedExercises
              .whereType<Map>()
              .map((item) =>
                  TrainingExercise.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <TrainingExercise>[],
      attendance: readMap('attendance'),
      comments: readMap('comments'),
    );
  }
}

class TrainingRepository {
  TrainingRepository(Database database) : _database = database;

  static const String _recordKey = 'sessions';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('training');

  final Database _database;

  Future<List<TrainingSession>> load() async {
    final data = await _store.record(_recordKey).get(_database);
    final storedSessions = data?['sessions'];
    if (storedSessions is List) {
      return storedSessions
          .whereType<Map>()
          .map((item) =>
              TrainingSession.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    final legacy = await _store.record('current').get(_database);
    return legacy == null
        ? <TrainingSession>[]
        : [TrainingSession.fromJson(legacy)];
  }

  Future<void> save(List<TrainingSession> sessions) =>
      _store.record(_recordKey).put(_database, <String, dynamic>{
        'sessions': sessions.map((session) => session.toJson()).toList(),
      });
}

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.database});

  final Database database;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late final TrainingRepository _repository =
      TrainingRepository(widget.database);
  late final TeamsRepository _teamsRepository =
      TeamsRepository(widget.database);
  final List<Team> _teams = <Team>[];
  final List<TrainingSession> _sessions = <TrainingSession>[];
  TrainingSession? _activeSession;
  String _activeView = 'list';
  Map<String, String> _attendance = <String, String>{};
  Map<String, String> _comments = <String, String>{};
  DateTime _trainingDate = DateTime.now();
  int _nextSessionId = 1;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _exerciseTitleController =
      TextEditingController();
  int? _editingExerciseId;
  String _exerciseType = 'Technik';
  final TextEditingController _exerciseGoalController = TextEditingController();
  final TextEditingController _exerciseDurationController =
      TextEditingController();
  final TextEditingController _exerciseDescriptionController =
      TextEditingController();
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _locationController.dispose();
    _durationController.dispose();
    _exerciseTitleController.dispose();
    _exerciseGoalController.dispose();
    _exerciseDurationController.dispose();
    _exerciseDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      _teamsRepository.load(),
      _repository.load(),
    ]);
    if (!mounted) return;
    final teams = results[0] as List<Team>;
    final sessions = results[1] as List<TrainingSession>;
    setState(() {
      _teams
        ..clear()
        ..addAll(teams);
      _sessions
        ..clear()
        ..addAll(sessions);
      _nextSessionId = _sessions.isEmpty
          ? 1
          : _sessions
                  .map((session) => session.id)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      _isLoaded = true;
    });
  }

  Future<void> _persist() => _repository.save(_sessions);

  void _createTraining() {
    final session = TrainingSession(
      id: _nextSessionId++,
      name: 'Training',
      teamId: null,
      date: DateTime.now(),
      location: '',
      duration: '',
      attendance: const <String, String>{},
      comments: const <String, String>{},
      exercises: const <TrainingExercise>[],
    );
    setState(() {
      _sessions.add(session);
      _activeSession = session;
      _activeView = 'info';
    });
    unawaited(_persist());
  }

  void _openTraining(TrainingSession session) {
    setState(() {
      _activeSession = session;
      _activeView = 'detail';
    });
  }

  void _closeTraining() {
    setState(() {
      _activeSession = null;
      _activeView = 'list';
    });
  }

  Future<void> _deleteTraining(TrainingSession session) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Training löschen?'),
        content: const Text('Dieses Training wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() {
      _sessions.removeWhere((entry) => entry.id == session.id);
      if (_activeSession?.id == session.id) {
        _activeSession = null;
        _activeView = 'list';
      }
    });
    await _persist();
  }

  void _openInfo(TrainingSession session) {
    _locationController.text = session.location;
    _durationController.text = session.duration;
    _trainingDate = session.date;
    setState(() {
      _activeSession = session;
      _activeView = 'info';
    });
  }

  void _openMatrix(TrainingSession session) {
    if (_teamFor(session) == null) return;
    setState(() {
      _activeSession = session;
      _activeView = 'matrix';
      _attendance = Map<String, String>.from(session.attendance);
      _comments = Map<String, String>.from(session.comments);
      _trainingDate = session.date;
    });
  }

  Team? _teamFor(TrainingSession session) {
    if (session.teamId == null) return null;
    return _teams.cast<Team?>().firstWhere(
          (team) => team?.id == session.teamId,
          orElse: () => null,
        );
  }

  Future<void> _selectTeam(Team team) async {
    final session = _activeSession;
    if (session == null) return;
    final updated = TrainingSession(
      id: session.id,
      name: session.name,
      teamId: team.id,
      date: session.date,
      location: session.location,
      duration: session.duration,
      attendance: session.attendance,
      comments: session.comments,
      exercises: session.exercises,
    );
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  void _replaceSession(TrainingSession updated) {
    final index = _sessions.indexWhere((session) => session.id == updated.id);
    if (index >= 0) _sessions[index] = updated;
  }

  Future<void> _persistMatrix() async {
    final session = _activeSession;
    if (session == null) return;
    final updated = TrainingSession(
      id: session.id,
      name: session.name,
      teamId: session.teamId,
      date: _trainingDate,
      location: session.location,
      duration: session.duration,
      attendance: _attendance,
      comments: _comments,
      exercises: session.exercises,
    );
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  Future<void> _setInfoField({String? location, String? duration}) async {
    final session = _activeSession;
    if (session == null) return;
    final updated = TrainingSession(
      id: session.id,
      name: session.name,
      teamId: session.teamId,
      date: session.date,
      location: location ?? session.location,
      duration: duration ?? session.duration,
      attendance: session.attendance,
      comments: session.comments,
      exercises: session.exercises,
    );
    _replaceSession(updated);
    _activeSession = updated;
    await _persist();
  }

  void _openPlan(TrainingSession session) => setState(() {
        _activeSession = session;
        _activeView = 'plan';
      });

  void _openAddExercise() {
    final session = _activeSession;
    if (session == null) return;
    setState(() {
      _editingExerciseId = null;
      _exerciseTitleController.clear();
      _exerciseType = 'Technik';
      _exerciseGoalController.clear();
      _exerciseDurationController.clear();
      _exerciseDescriptionController.clear();
      _activeView = 'add-exercise';
    });
  }

  void _openEditExercise(TrainingExercise exercise) {
    if (_activeSession == null) return;
    setState(() {
      _editingExerciseId = exercise.id;
      _exerciseTitleController.text = exercise.title;
      _exerciseType = exercise.type;
      _exerciseGoalController.text = exercise.goal;
      _exerciseDurationController.text = exercise.duration;
      _exerciseDescriptionController.text = exercise.description;
      _activeView = 'add-exercise';
    });
  }

  Future<void> _saveExercise() async {
    final session = _activeSession;
    final title = _exerciseTitleController.text.trim();
    if (session == null || title.isEmpty) return;
    final editedExercise = session.exercises
        .where((exercise) => exercise.id == _editingExerciseId)
        .firstOrNull;
    final exercise = TrainingExercise(
      id: editedExercise?.id ?? _nextExerciseId(),
      title: title,
      type: _exerciseType,
      goal: _exerciseGoalController.text.trim(),
      duration: _exerciseDurationController.text.trim(),
      description: _exerciseDescriptionController.text.trim(),
      status: editedExercise?.status ?? '',
    );
    final exercises = editedExercise == null
        ? [...session.exercises, exercise]
        : session.exercises
            .map((entry) => entry.id == editedExercise.id ? exercise : entry)
            .toList();
    final updated = _withExercises(session, exercises);
    setState(() {
      _editingExerciseId = null;
      _replaceSession(updated);
      _activeSession = updated;
      _activeView = 'plan';
    });
    await _persist();
  }

  int _nextExerciseId() {
    final exercises = _activeSession?.exercises ?? const <TrainingExercise>[];
    return exercises.isEmpty
        ? 1
        : exercises
                .map((exercise) => exercise.id)
                .reduce((a, b) => a > b ? a : b) +
            1;
  }

  TrainingSession _withExercises(
    TrainingSession session,
    List<TrainingExercise> exercises,
  ) =>
      TrainingSession(
        id: session.id,
        name: session.name,
        teamId: session.teamId,
        date: session.date,
        location: session.location,
        duration: session.duration,
        attendance: session.attendance,
        comments: session.comments,
        exercises: exercises,
      );

  Future<void> _setExerciseStatus(
    TrainingExercise exercise,
    String status,
  ) async {
    final session = _activeSession;
    if (session == null) return;
    final updatedExercises = session.exercises
        .map((entry) => entry.id == exercise.id
            ? entry.copyWith(status: entry.status == status ? '' : status)
            : entry)
        .toList();
    final updated = _withExercises(session, updatedExercises);
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  Future<void> _reorderExercises(int oldIndex, int newIndex) async {
    final session = _activeSession;
    if (session == null) return;
    final exercises = [...session.exercises];
    final exercise = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, exercise);
    final updated = _withExercises(session, exercises);
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  Future<void> _setAttendance(String key, String? value) async {
    setState(() {
      if (value == null) {
        _attendance.remove(key);
      } else {
        _attendance[key] = value;
      }
    });
    await _persistMatrix();
  }

  Future<void> _setComment(String key, String value) async {
    final comment = value.trim();
    if (comment.isEmpty) {
      _comments.remove(key);
    } else {
      _comments[key] = comment;
    }
    await _persistMatrix();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _trainingDate,
    );
    if (selectedDate == null || !mounted) return;
    setState(() => _trainingDate = selectedDate);
    await _persistMatrix();
  }

  Future<void> _selectInfoDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _trainingDate,
    );
    if (selectedDate == null || !mounted) return;
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      _trainingDate.hour,
      _trainingDate.minute,
    );
    await _setInfoDateTime(selectedDateTime);
  }

  Future<void> _selectInfoTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_trainingDate),
    );
    if (selectedTime == null || !mounted) return;
    final selectedDateTime = DateTime(
      _trainingDate.year,
      _trainingDate.month,
      _trainingDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    await _setInfoDateTime(selectedDateTime);
  }

  Future<void> _setInfoDateTime(DateTime dateTime) async {
    final session = _activeSession;
    if (session == null) return;
    final updated = TrainingSession(
      id: session.id,
      name: session.name,
      teamId: session.teamId,
      date: dateTime,
      location: session.location,
      duration: session.duration,
      attendance: session.attendance,
      comments: session.comments,
      exercises: session.exercises,
    );
    setState(() {
      _trainingDate = dateTime;
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_activeView == 'list') return _buildTrainingList();
    final session = _activeSession!;
    if (_activeView == 'info') return _buildTrainingInfo(session);
    if (_activeView == 'detail') return _buildTrainingDetail(session);
    if (_activeView == 'add-exercise') return _buildAddExercise(session);
    if (_activeView == 'plan') return _buildTrainingPlan(session);
    return _buildMatrix(session);
  }

  Widget _buildTrainingList() => Scaffold(
        appBar: AppBar(
          title: const Text('Training'),
          actions: [
            IconButton(
              key: const ValueKey('new-training-button'),
              tooltip: 'Training hinzufügen',
              icon: const Icon(Icons.add),
              onPressed: _createTraining,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const ValueKey('new-training-content-button'),
                leading: const CircleAvatar(
                  child: Icon(Icons.add),
                ),
                title: const Text('Neues Training erfassen'),
                subtitle: const Text('Trainingsinfos anlegen'),
                onTap: _createTraining,
              ),
            ),
            const SizedBox(height: 16),
            if (_sessions.isEmpty)
              const Center(child: Text('Noch keine Trainings angelegt.'))
            else
              for (final session in _sessions)
                Card(
                  child: ListTile(
                    title: Text(session.name),
                    subtitle: Text(
                      _sessionSummary(session),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('delete-training-${session.id}'),
                          tooltip: 'Training löschen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTraining(session),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _openTraining(session),
                  ),
                ),
          ],
        ),
      );

  Widget _buildTrainingInfo(TrainingSession session) => Scaffold(
        appBar: AppBar(
          title: const Text('Trainingsinfo'),
          leading: IconButton(
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeTraining,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Team auswählen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('training-location-input'),
              controller: _locationController,
              onChanged: (value) => unawaited(_setInfoField(location: value)),
              decoration: const InputDecoration(
                labelText: 'Ort',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('training-duration-input'),
              controller: _durationController,
              onChanged: (value) => unawaited(_setInfoField(duration: value)),
              decoration: const InputDecoration(
                labelText: 'Dauer',
                hintText: 'z. B. 90 Minuten',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Datum'),
                subtitle: Text(_formatDate(_trainingDate)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _selectInfoDate,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Uhrzeit'),
                subtitle: Text(_formatTime(_trainingDate)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _selectInfoTime,
              ),
            ),
            const SizedBox(height: 20),
            for (final team in _teams)
              Card(
                child: ListTile(
                  leading: Icon(
                    _teamFor(session)?.id == team.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title:
                      Text(team.name.isEmpty ? 'Unbenanntes Team' : team.name),
                  subtitle: Text(
                    '${team.players.length} Spieler, ${team.coaches.length} Trainer',
                  ),
                  onTap: () => _selectTeam(team),
                ),
              ),
            if (_teams.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Noch keine Teams angelegt.'),
                ),
              ),
          ],
        ),
      );

  Widget _buildTrainingDetail(TrainingSession session) {
    final team = _teamFor(session);
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeTraining,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _subpageTile(
            title: 'Info',
            subtitle: team == null ? 'Team auswählen' : team.name,
            icon: Icons.info_outline,
            onTap: () => _openInfo(session),
          ),
          const SizedBox(height: 12),
          _subpageTile(
            title: 'Teilnahme',
            subtitle: 'Teilnahme von Trainern und Spielern erfassen',
            icon: Icons.fact_check_outlined,
            onTap: team == null ? null : () => _openMatrix(session),
          ),
          const SizedBox(height: 12),
          _subpageTile(
            title: 'Trainingsplan',
            subtitle: '${session.exercises.length} Übungen',
            icon: Icons.list_alt_outlined,
            onTap: () => _openPlan(session),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingPlan(TrainingSession session) => Scaffold(
        appBar: AppBar(
          title: const Text('Trainingsplan'),
          leading: IconButton(
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _openTraining(session),
          ),
          actions: [
            IconButton(
              key: const ValueKey('add-training-exercise-button'),
              tooltip: 'Übung hinzufügen',
              icon: const Icon(Icons.add),
              onPressed: _openAddExercise,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const ValueKey('add-training-exercise-content-button'),
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: const Text('Übung hinzufügen'),
                subtitle: const Text('Ziel, Dauer und Beschreibung anlegen'),
                onTap: _openAddExercise,
              ),
            ),
            const SizedBox(height: 12),
            if (session.exercises.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Noch keine Übungen angelegt.'),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: true,
                itemCount: session.exercises.length,
                onReorderItem: _reorderExercises,
                itemBuilder: (context, index) {
                  final exercise = session.exercises[index];
                  return KeyedSubtree(
                    key: ValueKey(exercise.id),
                    child: _exerciseCard(exercise, index),
                  );
                },
              ),
          ],
        ),
      );

  Widget _buildAddExercise(TrainingSession session) => Scaffold(
        appBar: AppBar(
          title: Text(
            _editingExerciseId == null
                ? 'Übung hinzufügen'
                : 'Übung bearbeiten',
          ),
          leading: IconButton(
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _openPlan(session),
          ),
          actions: [
            IconButton(
              key: const ValueKey('save-training-exercise-button'),
              tooltip: 'Übung speichern',
              icon: const Icon(Icons.check),
              onPressed: _saveExercise,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('training-exercise-title-input'),
              controller: _exerciseTitleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Übung',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('training-exercise-type-input'),
              initialValue: _exerciseType,
              decoration: const InputDecoration(
                labelText: 'Typ',
                border: OutlineInputBorder(),
              ),
              items: TrainingExercise.types
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (type) {
                if (type != null) setState(() => _exerciseType = type);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('training-exercise-goal-input'),
              controller: _exerciseGoalController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Ziel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('training-exercise-duration-input'),
              controller: _exerciseDurationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Dauer',
                hintText: 'z. B. 10 Minuten',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('training-exercise-description-input'),
              controller: _exerciseDescriptionController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveExercise,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Übung speichern'),
            ),
          ],
        ),
      );

  Widget _exerciseCard(TrainingExercise exercise, int index) {
    final isCompleted = exercise.status == 'completed';
    final isSkipped = exercise.status == 'skipped';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isCompleted,
                  onChanged: (_) => _setExerciseStatus(exercise, 'completed'),
                ),
                Expanded(
                  child: Text(
                    '${index + 1}. ${exercise.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  key: ValueKey('edit-training-exercise-${exercise.id}'),
                  tooltip: 'Übung bearbeiten',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openEditExercise(exercise),
                ),
                IconButton(
                  tooltip: isSkipped
                      ? 'Übung wieder aktivieren'
                      : 'Übung überspringen',
                  icon: Icon(
                    isSkipped ? Icons.undo : Icons.skip_next_outlined,
                  ),
                  onPressed: () => _setExerciseStatus(exercise, 'skipped'),
                ),
              ],
            ),
            Text('Typ: ${exercise.type}'),
            if (exercise.goal.isNotEmpty) Text('Ziel: ${exercise.goal}'),
            if (exercise.duration.isNotEmpty)
              Text('Dauer: ${exercise.duration}'),
            if (exercise.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(exercise.description),
              ),
            if (isSkipped)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Übersprungen'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subpageTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) =>
      Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Widget _buildMatrix(TrainingSession session) {
    final team = _teamFor(session)!;
    final sortedPlayers = [...team.players]..sort((first, second) {
        if (first.number == null && second.number == null) {
          return first.name.toLowerCase().compareTo(second.name.toLowerCase());
        }
        if (first.number == null) return 1;
        if (second.number == null) return -1;
        final result = first.number!.compareTo(second.number!);
        return result == 0
            ? first.name.toLowerCase().compareTo(second.name.toLowerCase())
            : result;
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Teilnahme - ${team.name.isEmpty ? 'Team' : team.name}'),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _openTraining(session),
        ),
        actions: [
          IconButton(
            tooltip: 'Trainingstag auswählen',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder.all(color: Theme.of(context).dividerColor),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: IntrinsicColumnWidth(),
                2: IntrinsicColumnWidth(),
                3: IntrinsicColumnWidth(),
                4: FlexColumnWidth(),
              },
              children: [
                TableRow(children: [
                  _tableText('Name', bold: true),
                  _tableText('Teilnahme', bold: true),
                  _tableText('Entschuldigt', bold: true),
                  _tableText('Unentschuldigt', bold: true),
                  _tableText('Kommentar', bold: true),
                ]),
                if (team.coaches.isNotEmpty) _sectionRow('Trainer'),
                for (final coach in team.coaches)
                  _attendanceRow('coach:${coach.id}', coach.name, null),
                if (sortedPlayers.isNotEmpty) _sectionRow('Spieler'),
                for (final player in sortedPlayers)
                  _attendanceRow(
                      'player:${player.id}', player.name, player.number),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow _attendanceRow(String key, String name, int? number) {
    final currentValue = _attendance[key];
    return TableRow(children: [
      _tableText(number == null ? name : '$number  $name'),
      _attendanceCell(key, currentValue, TrainingAttendance.participating),
      _attendanceCell(key, currentValue, TrainingAttendance.excused),
      _attendanceCell(key, currentValue, TrainingAttendance.unexcused),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: TextFormField(
          initialValue: _comments[key] ?? '',
          onChanged: (value) => unawaited(_setComment(key, value)),
          textAlign: TextAlign.left,
          decoration:
              const InputDecoration(isDense: true, border: InputBorder.none),
        ),
      ),
    ]);
  }

  TableRow _sectionRow(String label) => TableRow(children: [
        _tableText(label, bold: true),
        for (var index = 0; index < 4; index++) const SizedBox.shrink(),
      ]);

  Widget _tableText(String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ),
      );

  Widget _attendanceCell(String key, String? currentValue, String value) =>
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Checkbox(
            value: currentValue == value,
            onChanged: (checked) =>
                _setAttendance(key, checked == true ? value : null),
          ),
        ),
      );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';

  String _sessionSummary(TrainingSession session) {
    final details = <String>[
      _formatDate(session.date),
      _teamFor(session)?.name ?? 'Kein Team ausgewählt',
      if (session.location.isNotEmpty) session.location,
      if (session.duration.isNotEmpty) session.duration,
    ];
    return details.join(' • ');
  }
}
