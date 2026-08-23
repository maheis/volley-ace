import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import '../teams/teams_page.dart';
import '../theme/app_palette.dart';
import 'training_plans_page.dart';

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
    required this.description,
    required this.exercises,
    required this.attendance,
    required this.comments,
    this.guests = const <String>[],
    this.trainingPlanId,
  });

  final int id;
  final String name;
  final int? teamId;
  final DateTime date;
  final String location;
  final String duration;
  final String description;
  final List<TrainingExercise> exercises;
  final Map<String, String> attendance;
  final Map<String, String> comments;
  final List<String> guests;
  final int? trainingPlanId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'teamId': teamId,
        'dateMillis': date.millisecondsSinceEpoch,
        'location': location,
        'duration': duration,
        'description': description,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
        'attendance': attendance,
        'comments': comments,
        'guests': guests,
        'trainingPlanId': trainingPlanId,
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

    final storedGuests = data['guests'];

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
      description:
          data['description'] is String ? data['description'] as String : '',
      exercises: storedExercises is List
          ? storedExercises
              .whereType<Map>()
              .map((item) =>
                  TrainingExercise.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <TrainingExercise>[],
      attendance: readMap('attendance'),
      comments: readMap('comments'),
      guests: storedGuests is List
          ? storedGuests.whereType<String>().toList()
          : <String>[],
      trainingPlanId: data['trainingPlanId'] is num
          ? (data['trainingPlanId'] as num).toInt()
          : null,
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
  static final StoreRef<String, Map<String, dynamic>> _plansStore =
      StoreRef<String, Map<String, dynamic>>('training_plans');
  final List<TrainingPlan> _plans = <TrainingPlan>[];
  TrainingSession? _activeSession;
  String _activeView = 'list';
  Map<String, String> _attendance = <String, String>{};
  Map<String, String> _comments = <String, String>{};
  List<String> _guests = <String>[];
  DateTime _trainingDate = DateTime.now();
  int _nextSessionId = 1;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _trainingDescriptionController =
      TextEditingController();
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _exerciseTitleController =
      TextEditingController();
  int? _editingExerciseId;
  String _exerciseType = 'Technik';
  final TextEditingController _exerciseGoalController = TextEditingController();
  final TextEditingController _exerciseDurationController =
      TextEditingController();
  final TextEditingController _exerciseDescriptionController =
      TextEditingController();
  final ScrollController _attendanceVerticalController = ScrollController();
  final ScrollController _attendanceHorizontalController = ScrollController();
  bool _isLoaded = false;

  List<TrainingSession> get _sortedSessions => List<TrainingSession>.of(
        _sessions,
      )..sort((first, second) {
          final dateComparison = second.date.compareTo(first.date);
          return dateComparison != 0
              ? dateComparison
              : second.id.compareTo(first.id);
        });

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadPlans());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _trainingDescriptionController.dispose();
    _guestNameController.dispose();
    _exerciseTitleController.dispose();
    _exerciseGoalController.dispose();
    _exerciseDurationController.dispose();
    _exerciseDescriptionController.dispose();
    _attendanceVerticalController.dispose();
    _attendanceHorizontalController.dispose();
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

  Future<void> _loadPlans() async {
    final data = await _plansStore.record('plans').get(widget.database);
    final stored = data?['plans'];
    if (!mounted) return;
    setState(() {
      _plans
        ..clear()
        ..addAll(stored is List
            ? stored
                .whereType<Map>()
                .map((item) =>
                    TrainingPlan.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <TrainingPlan>[]);
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
      description: '',
      attendance: const <String, String>{},
      comments: const <String, String>{},
      guests: const <String>[],
      exercises: const <TrainingExercise>[],
    );
    setState(() {
      _sessions.add(session);
      _activeSession = session;
      _activeView = 'info';
    });
    unawaited(_persist());
  }

  Future<void> _copyTraining(TrainingSession source) async {
    final copied = TrainingSession(
      id: _nextSessionId++,
      name: '${source.name} (Kopie)',
      teamId: source.teamId,
      date: DateTime.now(),
      location: source.location,
      duration: source.duration,
      description: source.description,
      attendance: const <String, String>{},
      comments: const <String, String>{},
      guests: const <String>[],
      exercises: source.exercises
          .map(
            (exercise) => TrainingExercise(
              id: exercise.id,
              title: exercise.title,
              type: exercise.type,
              goal: exercise.goal,
              duration: exercise.duration,
              description: exercise.description,
              status: '',
            ),
          )
          .toList(),
      trainingPlanId: source.trainingPlanId,
    );
    setState(() {
      _sessions.add(copied);
      _activeSession = copied;
      _activeView = 'info';
    });
    _nameController.text = copied.name;
    _locationController.text = copied.location;
    _durationController.text = copied.duration;
    _trainingDescriptionController.text = copied.description;
    await _persist();
  }

  Future<void> _shareTraining(TrainingSession session) async {
    final jsonText =
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'formatVersion': 1,
      'type': 'training',
      'training': session.toJson(),
    });
    await AppBackupService.shareOrSaveJson(
      context,
      suggestedName:
          'volleyace-training-${DateTime.now().millisecondsSinceEpoch}.json',
      jsonText: jsonText,
      subject: 'VolleyAce Training: ${session.name}',
      dialogTitle: 'Training speichern',
    );
  }

  Future<void> _importTraining() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Training importieren',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (result.isEmpty) return;
      final bytes = await result.single.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      final rawTrainings = decoded is Map && decoded['trainings'] is List
          ? decoded['trainings'] as List
          : decoded is Map && decoded['training'] is Map
              ? <dynamic>[decoded['training']]
              : decoded is Map
                  ? <dynamic>[decoded]
                  : const <dynamic>[];
      final imported = rawTrainings
          .whereType<Map>()
          .map((item) =>
              TrainingSession.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (imported.isEmpty) {
        throw const FormatException('Keine Trainingsdaten gefunden.');
      }
      final copied = imported.map(_withNewSessionId).toList();
      setState(() {
        _sessions.addAll(copied);
        _activeSession = copied.first;
        _activeView = 'info';
      });
      _nameController.text = copied.first.name;
      _locationController.text = copied.first.location;
      _durationController.text = copied.first.duration;
      _trainingDescriptionController.text = copied.first.description;
      await _persist();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Training konnte nicht importiert werden: $error')),
      );
    }
  }

  TrainingSession _withNewSessionId(TrainingSession source) => TrainingSession(
        id: _nextSessionId++,
        name: source.name,
        teamId: source.teamId,
        date: source.date,
        location: source.location,
        duration: source.duration,
        description: source.description,
        attendance: source.attendance,
        comments: source.comments,
        guests: source.guests,
        exercises: source.exercises,
        trainingPlanId: source.trainingPlanId,
      );

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
    _nameController.text = session.name;
    _locationController.text = session.location;
    _durationController.text = session.duration;
    _trainingDescriptionController.text = session.description;
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
      _guests = List<String>.from(session.guests);
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
      description: session.description,
      attendance: session.attendance,
      comments: session.comments,
      guests: session.guests,
      exercises: session.exercises,
      trainingPlanId: session.trainingPlanId,
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
      description: session.description,
      attendance: _attendance,
      comments: _comments,
      guests: _guests,
      exercises: session.exercises,
      trainingPlanId: session.trainingPlanId,
    );
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  Future<void> _setInfoField({
    String? name,
    String? location,
    String? duration,
    String? description,
  }) async {
    final session = _activeSession;
    if (session == null) return;
    final updated = TrainingSession(
      id: session.id,
      name: name ?? session.name,
      teamId: session.teamId,
      date: session.date,
      location: location ?? session.location,
      duration: duration ?? session.duration,
      description: description ?? session.description,
      attendance: session.attendance,
      comments: session.comments,
      guests: session.guests,
      exercises: session.exercises,
      trainingPlanId: session.trainingPlanId,
    );
    _replaceSession(updated);
    _activeSession = updated;
    await _persist();
  }

  void _openPlan(TrainingSession session) => setState(() {
        _activeSession = session;
        _activeView = 'plan';
      });

  Future<void> _selectTrainingPlan(TrainingSession session) async {
    if (_plans.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Noch keine Trainingspläne angelegt.')),
      );
      return;
    }
    var nameFilter = '';
    var topicFilter = '';
    var selectionMade = false;
    final selected = await showDialog<TrainingPlan>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredPlans = _plans.where((plan) {
            final name = plan.topic.toLowerCase();
            final topic = plan.description.toLowerCase();
            return (nameFilter.isEmpty ||
                    name.contains(nameFilter.toLowerCase())) &&
                (topicFilter.isEmpty ||
                    topic.contains(topicFilter.toLowerCase()));
          }).toList();

          return AlertDialog(
            title: const Text('Trainingsplan auswählen'),
            content: SizedBox(
              width: 480,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nach Name filtern',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setDialogState(() => nameFilter = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nach Thema filtern',
                      prefixIcon: Icon(Icons.topic_outlined),
                    ),
                    onChanged: (value) =>
                        setDialogState(() => topicFilter = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredPlans.isEmpty
                        ? const Center(
                            child: Text('Keine Trainingspläne gefunden.'))
                        : ListView.builder(
                            itemCount: filteredPlans.length,
                            itemBuilder: (context, index) {
                              final plan = filteredPlans[index];
                              return ListTile(
                                leading: const Icon(Icons.view_list_outlined),
                                title: Text(plan.topic.isEmpty
                                    ? 'Trainingsplan'
                                    : plan.topic),
                                subtitle:
                                    Text('${plan.exercises.length} Übungen'),
                                onTap: () {
                                  selectionMade = true;
                                  Navigator.pop(dialogContext, plan);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              if (session.trainingPlanId != null)
                TextButton(
                  onPressed: () {
                    selectionMade = true;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Keinen Trainingsplan verwenden'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Abbrechen'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || !selectionMade) return;
    final exercises = selected?.exercises ?? const <TrainingExercise>[];
    final updated = TrainingSession(
      id: session.id,
      name: session.name,
      teamId: session.teamId,
      date: session.date,
      location: session.location,
      duration: session.duration,
      description: session.description,
      attendance: session.attendance,
      comments: session.comments,
      guests: session.guests,
      exercises: exercises,
      trainingPlanId: selected?.id,
    );
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  Future<void> _openAddExercise() async {
    final session = _activeSession;
    if (session == null) return;
    final exercise = TrainingExercise(
      id: _nextExerciseId(),
      title: '',
      type: 'Technik',
      goal: '',
      duration: '',
      description: '',
      status: '',
    );
    final updated = _withExercises(session, [...session.exercises, exercise]);
    setState(() {
      _editingExerciseId = exercise.id;
      _exerciseTitleController.clear();
      _exerciseType = 'Technik';
      _exerciseGoalController.clear();
      _exerciseDurationController.clear();
      _exerciseDescriptionController.clear();
      _replaceSession(updated);
      _activeSession = updated;
      _activeView = 'add-exercise';
    });
    await _persist();
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

  void _updateExerciseFromFields() {
    final session = _activeSession;
    final exerciseId = _editingExerciseId;
    if (session == null || exerciseId == null) return;
    final updatedExercise = TrainingExercise(
      id: exerciseId,
      title: _exerciseTitleController.text.trim(),
      type: _exerciseType,
      goal: _exerciseGoalController.text.trim(),
      duration: _exerciseDurationController.text.trim(),
      description: _exerciseDescriptionController.text.trim(),
      status: session.exercises
              .where((exercise) => exercise.id == exerciseId)
              .firstOrNull
              ?.status ??
          '',
    );
    final exercises = session.exercises
        .map((entry) => entry.id == exerciseId ? updatedExercise : entry)
        .toList();
    final updated = _withExercises(session, exercises);
    setState(() {
      _replaceSession(updated);
      _activeSession = updated;
    });
    unawaited(_persist());
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
        description: session.description,
        attendance: session.attendance,
        comments: session.comments,
        guests: session.guests,
        exercises: exercises,
        trainingPlanId: session.trainingPlanId,
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

  Future<void> _addGuest() async {
    final trimmedName = _guestNameController.text.trim();
    if (trimmedName.isEmpty) return;
    setState(() => _guests.add(trimmedName));
    _guestNameController.clear();
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
      description: session.description,
      attendance: session.attendance,
      comments: session.comments,
      guests: session.guests,
      exercises: session.exercises,
      trainingPlanId: session.trainingPlanId,
    );
    setState(() {
      _trainingDate = dateTime;
      _replaceSession(updated);
      _activeSession = updated;
    });
    await _persist();
  }

  void _handleSystemBack() {
    if (_activeView == 'list') return;
    setState(() {
      if (_activeView == 'add-exercise') {
        _activeView = 'plan';
      } else if (_activeView == 'info' ||
          _activeView == 'plan' ||
          _activeView == 'matrix') {
        _activeView = 'detail';
      } else {
        _activeSession = null;
        _activeView = 'list';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const PopScope(
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final Widget page;
    if (_activeView == 'list') {
      page = _buildTrainingList();
    } else {
      final session = _activeSession!;
      if (_activeView == 'info') {
        page = _buildTrainingInfo(session);
      } else if (_activeView == 'detail') {
        page = _buildTrainingDetail(session);
      } else if (_activeView == 'add-exercise') {
        page = _buildAddExercise(session);
      } else if (_activeView == 'plan') {
        page = _buildTrainingPlan(session);
      } else {
        page = _buildMatrix(session);
      }
    }
    return PopScope(
      canPop: _activeView == 'list',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: page,
    );
  }

  Widget _buildTrainingList() => Scaffold(
        appBar: AppBar(
          title: const Text('Training'),
          actions: [
            IconButton(
              key: const ValueKey('import-training-button'),
              tooltip: 'Training importieren',
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _importTraining,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compactActions = constraints.maxWidth < 1000;
            return ListView(
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
                  for (final session in _sortedSessions)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(session.name),
                        subtitle: Text(
                          _sessionSummary(session),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (compactActions)
                              PopupMenuButton<String>(
                                tooltip: 'Weitere Aktionen',
                                onSelected: (action) {
                                  switch (action) {
                                    case 'share':
                                      _shareTraining(session);
                                    case 'copy':
                                      _copyTraining(session);
                                    case 'delete':
                                      _deleteTraining(session);
                                  }
                                },
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
                                        Text('Training teilen'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_outlined,
                                            color: Theme.of(context)
                                                .iconTheme
                                                .color),
                                        const SizedBox(width: 12),
                                        Text('Training kopieren'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Theme.of(context)
                                                .iconTheme
                                                .color),
                                        const SizedBox(width: 12),
                                        Text('Training löschen'),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              IconButton(
                                key: ValueKey('share-training-${session.id}'),
                                tooltip: 'Training teilen',
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () => _shareTraining(session),
                              ),
                              IconButton(
                                key: ValueKey('copy-training-${session.id}'),
                                tooltip: 'Training kopieren',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () => _copyTraining(session),
                              ),
                              IconButton(
                                key: ValueKey('delete-training-${session.id}'),
                                tooltip: 'Training löschen',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteTraining(session),
                              ),
                            ],
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openTraining(session),
                      ),
                    ),
              ],
            );
          },
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
              key: const ValueKey('training-name-input'),
              controller: _nameController,
              onChanged: (value) => unawaited(_setInfoField(name: value)),
              decoration: const InputDecoration(
                labelText: 'Name des Trainings',
                border: OutlineInputBorder(),
              ),
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
            TextField(
              key: const ValueKey('training-description-input'),
              controller: _trainingDescriptionController,
              minLines: 3,
              maxLines: 6,
              onChanged: (value) =>
                  unawaited(_setInfoField(description: value)),
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Kurze Beschreibung des Trainings',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
        actions: [
          IconButton(
            key: ValueKey('share-training-detail-${session.id}'),
            tooltip: 'Training teilen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareTraining(session),
          ),
          IconButton(
            key: ValueKey('copy-training-detail-${session.id}'),
            tooltip: 'Training kopieren',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copyTraining(session),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _subpageTile(
            title: 'Info',
            subtitle: session.description.isEmpty
                ? (team == null ? 'Team auswählen' : team.name)
                : session.description,
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.view_list_outlined),
                title: const Text('Trainingsplan auswählen'),
                subtitle: Text(
                  session.trainingPlanId == null
                      ? 'Kein Trainingsplan ausgewählt'
                      : (_plans
                              .where(
                                  (plan) => plan.id == session.trainingPlanId)
                              .firstOrNull
                              ?.topic ??
                          'Trainingsplan nicht gefunden'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTrainingPlan(session),
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
              onChanged: (_) => _updateExerciseFromFields(),
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
                if (type != null) {
                  setState(() => _exerciseType = type);
                  _updateExerciseFromFields();
                }
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
              onChanged: (_) => _updateExerciseFromFields(),
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
              onChanged: (_) => _updateExerciseFromFields(),
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
              onChanged: (_) => _updateExerciseFromFields(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Teilnahme - ${team.name.isEmpty ? 'Team' : team.name}'),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _openTraining(session),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: const EdgeInsets.all(12),
          child: Scrollbar(
            controller: _attendanceVerticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _attendanceVerticalController,
              child: Column(
                children: [
                  Scrollbar(
                    controller: _attendanceHorizontalController,
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.depth == 1,
                    child: SingleChildScrollView(
                      controller: _attendanceHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth - 24,
                        ),
                        child: Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          border: TableBorder.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FixedColumnWidth(52),
                            2: FixedColumnWidth(52),
                            3: FixedColumnWidth(52),
                            4: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(children: [
                              _tableText('Name', bold: true),
                              _attendanceHeader(
                                Icons.add_circle_outline,
                                'Teilnahme',
                                AppPalette.green,
                              ),
                              _attendanceHeader(
                                Icons.circle_outlined,
                                'Entschuldigt',
                                AppPalette.yellow,
                              ),
                              _attendanceHeader(
                                Icons.error_outline,
                                'Unentschuldigt',
                                AppPalette.red,
                              ),
                              _tableText('Kommentar', bold: true),
                            ]),
                            if (team.coaches.isNotEmpty) _sectionRow('Trainer'),
                            for (final coach in team.coaches)
                              _attendanceRow(
                                  'coach:${coach.id}', coach.name, null),
                            if (team.players.isNotEmpty) _sectionRow('Spieler'),
                            for (final player in team.players)
                              _attendanceRow('player:${player.id}', player.name,
                                  player.number),
                            if (_guests.isNotEmpty) _sectionRow('Gäste'),
                            for (var index = 0; index < _guests.length; index++)
                              _attendanceRow(
                                  'guest:$index', _guests[index], null),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('guest-name-input'),
                          controller: _guestNameController,
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _addGuest(),
                          decoration: const InputDecoration(
                            labelText: 'Gastspieler',
                            hintText: 'Name eingeben',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('add-guest-button'),
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.green,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Gastspieler hinzufügen',
                        icon: const Icon(Icons.add),
                        onPressed: _addGuest,
                      ),
                    ],
                  ),
                ],
              ),
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
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 250),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TextFormField(
            initialValue: _comments[key] ?? '',
            onChanged: (value) => unawaited(_setComment(key, value)),
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _attendanceHeader(IconData icon, String tooltip, Color color) =>
      Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Icon(icon, color: color),
        ),
      );

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

  Widget _attendanceCell(String key, String? currentValue, String value) {
    final color = switch (value) {
      TrainingAttendance.participating => AppPalette.green,
      TrainingAttendance.excused => AppPalette.yellow,
      TrainingAttendance.unexcused => AppPalette.red,
      _ => null,
    };
    return Center(
      child: Checkbox(
        key: ValueKey('attendance-$key-$value'),
        value: currentValue == value,
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (color == null) return null;
          return states.contains(WidgetState.selected)
              ? color
              : color.withValues(alpha: 0.24);
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (color == null) return null;
          return BorderSide(color: color, width: 1.5);
        }),
        onChanged: (checked) =>
            _setAttendance(key, checked == true ? value : null),
      ),
    );
  }

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
