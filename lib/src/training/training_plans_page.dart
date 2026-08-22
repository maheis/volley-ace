import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import 'training_page.dart';
import 'training_exercises_page.dart';

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.topic,
    required this.duration,
    required this.description,
    required this.exercises,
  });

  final int id;
  final String topic;
  final String duration;
  final String description;
  final List<TrainingExercise> exercises;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'topic': topic,
        'duration': duration,
        'description': description,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      };

  static TrainingPlan fromJson(Map<String, dynamic> data) {
    final storedExercises = data['exercises'];
    return TrainingPlan(
      id: data['id'] is num ? (data['id'] as num).toInt() : 1,
      topic: data['topic'] is String ? data['topic'] as String : '',
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
    );
  }
}

class TrainingPlansPage extends StatefulWidget {
  const TrainingPlansPage({super.key, required this.database});

  final Database database;

  @override
  State<TrainingPlansPage> createState() => _TrainingPlansPageState();
}

class _TrainingPlansPageState extends State<TrainingPlansPage> {
  static const _recordKey = 'plans';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('training_plans');

  final List<TrainingPlan> _plans = <TrainingPlan>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.record(_recordKey).get(widget.database);
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
      _loading = false;
    });
  }

  Future<void> _save() => _store.record(_recordKey).put(
        widget.database,
        <String, dynamic>{
          'plans': _plans.map((plan) => plan.toJson()).toList(),
        },
      );

  Future<void> _createPlan() async {
    final plan = const TrainingPlan(
      id: 0,
      topic: '',
      duration: '',
      description: '',
      exercises: <TrainingExercise>[],
    ).copyWith(id: DateTime.now().microsecondsSinceEpoch);
    setState(() => _plans.add(plan));
    await _save();
    if (mounted) await _openEditor(plan);
  }

  Future<void> _openEditor(TrainingPlan plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrainingPlanEditPage(
          plan: plan,
          database: widget.database,
          onChanged: _updatePlan,
        ),
      ),
    );
  }

  void _updatePlan(TrainingPlan updated) {
    final index = _plans.indexWhere((plan) => plan.id == updated.id);
    if (index == -1) return;
    setState(() => _plans[index] = updated);
    unawaited(_save());
  }

  Future<void> _copyPlan(TrainingPlan source) async {
    final copy = TrainingPlan(
      id: DateTime.now().microsecondsSinceEpoch,
      topic: '${source.topic} (Kopie)',
      duration: source.duration,
      description: source.description,
      exercises: List<TrainingExercise>.from(source.exercises),
    );
    setState(() => _plans.add(copy));
    await _save();
    if (mounted) await _openEditor(copy);
  }

  Future<void> _deletePlan(TrainingPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trainingsplan löschen?'),
        content: Text('Soll „${plan.topic}“ wirklich gelöscht werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _plans.removeWhere((item) => item.id == plan.id));
    await _save();
  }

  Future<void> _sharePlan(TrainingPlan plan) async {
    final jsonText =
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'formatVersion': 1,
      'type': 'training-plan',
      'plan': plan.toJson(),
    });
    await AppBackupService.shareOrSaveJson(
      context,
      suggestedName:
          'volleyace-trainingsplan-${DateTime.now().millisecondsSinceEpoch}.json',
      jsonText: jsonText,
      subject: 'VolleyAce Trainingsplan: ${plan.topic}',
      dialogTitle: 'Trainingsplan speichern',
    );
  }

  Future<void> _importPlans() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Trainingspläne importieren',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (result.isEmpty) return;
      final decoded =
          jsonDecode(utf8.decode(await result.single.readAsBytes()));
      final rawPlans = decoded is Map && decoded['plans'] is List
          ? decoded['plans'] as List
          : decoded is Map && decoded['plan'] is Map
              ? <dynamic>[decoded['plan']]
              : decoded is Map
                  ? <dynamic>[decoded]
                  : const <dynamic>[];
      final imported = rawPlans.whereType<Map>().map((item) {
        final plan = TrainingPlan.fromJson(Map<String, dynamic>.from(item));
        return TrainingPlan(
          id: DateTime.now().microsecondsSinceEpoch,
          topic: plan.topic,
          duration: plan.duration,
          description: plan.description,
          exercises: plan.exercises,
        );
      }).toList();
      if (imported.isEmpty) {
        throw const FormatException('Keine Trainingspläne gefunden.');
      }
      setState(() => _plans.addAll(imported));
      await _save();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainingspläne'),
        actions: [
          IconButton(
            tooltip: 'Trainingspläne importieren',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _importPlans,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: const Text('Neuen Trainingsplan anlegen'),
                    subtitle: const Text('Thema, Dauer und Übungen festlegen'),
                    onTap: _createPlan,
                  ),
                ),
                const SizedBox(height: 16),
                if (_plans.isEmpty)
                  const Center(
                      child: Text('Noch keine Trainingspläne angelegt.'))
                else
                  for (final plan in _plans)
                    Card(
                      child: ListTile(
                        title: Text(plan.topic.isEmpty
                            ? 'Neuer Trainingsplan'
                            : plan.topic),
                        subtitle: Text(
                          '${plan.duration} · ${plan.exercises.length} Übungen\n${plan.description}',
                        ),
                        isThreeLine: true,
                        onTap: () => _openEditor(plan),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Trainingsplan teilen',
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () => _sharePlan(plan),
                            ),
                            IconButton(
                              tooltip: 'Trainingsplan kopieren',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () => _copyPlan(plan),
                            ),
                            IconButton(
                              tooltip: 'Trainingsplan löschen',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deletePlan(plan),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

extension on TrainingPlan {
  TrainingPlan copyWith({int? id}) => TrainingPlan(
        id: id ?? this.id,
        topic: topic,
        duration: duration,
        description: description,
        exercises: exercises,
      );
}

class TrainingPlanEditPage extends StatefulWidget {
  const TrainingPlanEditPage({
    super.key,
    required this.plan,
    required this.database,
    required this.onChanged,
  });

  final TrainingPlan plan;
  final Database database;
  final ValueChanged<TrainingPlan> onChanged;

  @override
  State<TrainingPlanEditPage> createState() => _TrainingPlanEditPageState();
}

class _TrainingPlanEditPageState extends State<TrainingPlanEditPage> {
  static const _exerciseRecordKey = 'exercises';
  static final StoreRef<String, Map<String, dynamic>> _exerciseStore =
      StoreRef<String, Map<String, dynamic>>('training_exercises');

  late final TextEditingController _topicController;
  late final TextEditingController _durationController;
  late final TextEditingController _descriptionController;
  late List<TrainingExercise> _exercises;
  List<TrainingExercise> _availableExercises = <TrainingExercise>[];
  late bool _durationWasEdited;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.plan.topic);
    _durationController = TextEditingController(text: widget.plan.duration);
    _descriptionController =
        TextEditingController(text: widget.plan.description);
    _exercises = List<TrainingExercise>.from(widget.plan.exercises);
    _durationWasEdited = widget.plan.duration.trim().isNotEmpty;
    _updateDurationFromExercises();
    _loadExercises();
  }

  int? _parseDurationMinutes(String value) {
    final duration = value.trim().toLowerCase();
    final clockMatch = RegExp(r'^(\d+)\s*:\s*([0-5]\d)$').firstMatch(duration);
    if (clockMatch != null) {
      return int.parse(clockMatch.group(1)!) * 60 +
          int.parse(clockMatch.group(2)!);
    }
    final minutesMatch =
        RegExp(r'^(\d+)\s*(?:min|mins|minute|minuten)?$').firstMatch(duration);
    return minutesMatch == null ? null : int.parse(minutesMatch.group(1)!);
  }

  void _updateDurationFromExercises() {
    if (_durationWasEdited) return;
    final totalMinutes = _exercises.fold<int>(0, (total, exercise) {
      return total + (_parseDurationMinutes(exercise.duration) ?? 0);
    });
    _durationController.text = totalMinutes == 0 ? '' : '$totalMinutes min';
  }

  Future<void> _loadExercises() async {
    final data =
        await _exerciseStore.record(_exerciseRecordKey).get(widget.database);
    final stored = data?['exercises'];
    if (!mounted) return;
    setState(() {
      _availableExercises = stored is List
          ? stored
              .whereType<Map>()
              .map((item) =>
                  TrainingExercise.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <TrainingExercise>[];
    });
  }

  Future<void> _saveAvailableExercises() => _exerciseStore
          .record(_exerciseRecordKey)
          .put(widget.database, <String, dynamic>{
        'exercises':
            _availableExercises.map((exercise) => exercise.toJson()).toList(),
      });

  void _notifyChanged() {
    widget.onChanged(
      TrainingPlan(
        id: widget.plan.id,
        topic: _topicController.text.trim(),
        duration: _durationController.text.trim(),
        description: _descriptionController.text.trim(),
        exercises: List<TrainingExercise>.from(_exercises),
      ),
    );
  }

  Future<void> _addExercise() async {
    var nameFilter = '';
    var typeFilter = '';
    final selected = await showDialog<TrainingExercise>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredExercises = _availableExercises.where((exercise) {
            final alreadyAdded =
                _exercises.any((item) => item.id == exercise.id);
            final matchesName = nameFilter.isEmpty ||
                exercise.title.toLowerCase().contains(nameFilter.toLowerCase());
            final matchesType =
                typeFilter.isEmpty || exercise.type == typeFilter;
            return !alreadyAdded && matchesName && matchesType;
          }).toList();

          return AlertDialog(
            title: const Text('Übung hinzufügen'),
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
                  DropdownButtonFormField<String>(
                    initialValue: typeFilter.isEmpty ? null : typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Nach Typ filtern',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Alle Typen'),
                      ),
                      ...TrainingExercise.types.map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => typeFilter = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredExercises.isEmpty
                        ? const Center(child: Text('Keine Übungen gefunden.'))
                        : ListView.builder(
                            itemCount: filteredExercises.length,
                            itemBuilder: (context, index) {
                              final exercise = filteredExercises[index];
                              return ListTile(
                                title: Text(exercise.title.isEmpty
                                    ? 'Übung'
                                    : exercise.title),
                                subtitle: Text(
                                    '${exercise.type} · ${exercise.duration}'),
                                onTap: () =>
                                    Navigator.pop(dialogContext, exercise),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final exercise = TrainingExercise(
                    id: DateTime.now().microsecondsSinceEpoch,
                    title: '',
                    type: TrainingExercise.types.first,
                    goal: '',
                    duration: '',
                    description: '',
                    status: '',
                  );
                  var updatedExercise = exercise;
                  await Navigator.of(dialogContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => TrainingExerciseEditPage(
                        exercise: exercise,
                        onChanged: (updated) => updatedExercise = updated,
                      ),
                    ),
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  _availableExercises.add(updatedExercise);
                  await _saveAvailableExercises();
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext, updatedExercise);
                },
                icon: const Icon(Icons.add),
                label: const Text('Neue Übung anlegen'),
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
    if (!mounted || selected == null) return;
    setState(() => _exercises.add(selected));
    _updateDurationFromExercises();
    _notifyChanged();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trainingsplan bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _topicController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Thema',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            decoration: const InputDecoration(
              labelText: 'Dauer',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              _durationWasEdited = true;
              _notifyChanged();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Übungen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Übung hinzufügen',
                onPressed: _availableExercises.isEmpty ? null : _addExercise,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_availableExercises.isEmpty)
            const Text('Lege zuerst Trainingsübungen an.')
          else if (_exercises.isEmpty)
            const Text('Noch keine Übungen hinzugefügt.')
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exercises.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final exercise = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, exercise);
                });
                _updateDurationFromExercises();
                _notifyChanged();
              },
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return Card(
                  key: ValueKey(exercise.id),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(exercise.title),
                    subtitle: Text('${exercise.type} · ${exercise.duration}'),
                    trailing: IconButton(
                      tooltip: 'Übung entfernen',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() => _exercises.removeAt(index));
                        _updateDurationFromExercises();
                        _notifyChanged();
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
