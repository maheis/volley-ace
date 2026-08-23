import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import 'training_page.dart';

class TrainingExercisesPage extends StatefulWidget {
  const TrainingExercisesPage({super.key, required this.database});

  final Database database;

  @override
  State<TrainingExercisesPage> createState() => _TrainingExercisesPageState();
}

class _TrainingExercisesPageState extends State<TrainingExercisesPage> {
  static const _recordKey = 'exercises';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('training_exercises');

  final List<TrainingExercise> _exercises = <TrainingExercise>[];
  String _nameFilter = '';
  String _typeFilter = '';
  bool _loading = true;

  List<TrainingExercise> get _visibleExercises {
    final filtered = _exercises.where((exercise) {
      final matchesName = _nameFilter.isEmpty ||
          exercise.title.toLowerCase().contains(_nameFilter.toLowerCase());
      final matchesType = _typeFilter.isEmpty || exercise.type == _typeFilter;
      return matchesName && matchesType;
    }).toList();
    filtered.sort((first, second) {
      final firstIndex = TrainingExercise.types.indexOf(first.type);
      final secondIndex = TrainingExercise.types.indexOf(second.type);
      final normalizedFirstIndex =
          firstIndex == -1 ? TrainingExercise.types.length : firstIndex;
      final normalizedSecondIndex =
          secondIndex == -1 ? TrainingExercise.types.length : secondIndex;
      return normalizedFirstIndex.compareTo(normalizedSecondIndex);
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.record(_recordKey).get(widget.database);
    final stored = data?['exercises'];
    if (!mounted) return;
    setState(() {
      _exercises
        ..clear()
        ..addAll(stored is List
            ? stored
                .whereType<Map>()
                .map((item) =>
                    TrainingExercise.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <TrainingExercise>[]);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _store.record(_recordKey).put(widget.database, <String, dynamic>{
      'exercises': _exercises.map((exercise) => exercise.toJson()).toList(),
    });
  }

  Future<void> _createExercise() async {
    final exercise = TrainingExercise(
      id: DateTime.now().microsecondsSinceEpoch,
      title: '',
      type: TrainingExercise.types.first,
      goal: '',
      duration: '',
      description: '',
      status: '',
    );
    setState(() => _exercises.add(exercise));
    await _save();
    if (!mounted) return;
    await _openEditor(exercise);
  }

  Future<void> _editExercise(TrainingExercise exercise) async {
    await _openEditor(exercise);
  }

  Future<void> _openEditor(TrainingExercise exercise) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrainingExerciseEditPage(
          exercise: exercise,
          onChanged: _updateExercise,
        ),
      ),
    );
  }

  void _updateExercise(TrainingExercise updated) {
    setState(() {
      final index = _exercises.indexWhere((item) => item.id == updated.id);
      if (index != -1) _exercises[index] = updated;
    });
    unawaited(_save());
  }

  Future<void> _deleteExercise(TrainingExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Übung löschen?'),
        content: Text('Soll „${exercise.title}“ wirklich gelöscht werden?'),
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
    setState(() => _exercises.removeWhere((item) => item.id == exercise.id));
    await _save();
  }

  Future<void> _copyExercise(TrainingExercise source) async {
    final copied = TrainingExercise(
      id: DateTime.now().microsecondsSinceEpoch,
      title: '${source.title} (Kopie)',
      type: source.type,
      goal: source.goal,
      duration: source.duration,
      description: source.description,
      status: '',
    );
    setState(() => _exercises.add(copied));
    await _save();
    if (!mounted) return;
    await _openEditor(copied);
  }

  Future<void> _shareExercise(TrainingExercise exercise) async {
    final jsonText =
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'formatVersion': 1,
      'type': 'training-exercise',
      'exercise': exercise.toJson(),
    });
    await AppBackupService.shareOrSaveJson(
      context,
      suggestedName:
          'volleyace-uebung-${DateTime.now().millisecondsSinceEpoch}.json',
      jsonText: jsonText,
      subject: 'VolleyAce Übung: ${exercise.title}',
      dialogTitle: 'Übung speichern',
    );
  }

  Future<void> _importExercises() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Übungen importieren',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (result.isEmpty) return;
      final bytes = await result.single.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      final rawExercises = decoded is Map && decoded['exercises'] is List
          ? decoded['exercises'] as List
          : decoded is Map && decoded['exercise'] is Map
              ? <dynamic>[decoded['exercise']]
              : decoded is Map
                  ? <dynamic>[decoded]
                  : const <dynamic>[];
      final imported = rawExercises
          .whereType<Map>()
          .map((item) =>
              TrainingExercise.fromJson(Map<String, dynamic>.from(item)))
          .map((exercise) => TrainingExercise(
                id: DateTime.now().microsecondsSinceEpoch,
                title: exercise.title,
                type: exercise.type,
                goal: exercise.goal,
                duration: exercise.duration,
                description: exercise.description,
                status: '',
              ))
          .toList();
      if (imported.isEmpty) {
        throw const FormatException('Keine Übungsdaten gefunden.');
      }
      setState(() => _exercises.addAll(imported));
      await _save();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Übungen konnten nicht importiert werden: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainingsübungen'),
        actions: [
          IconButton(
            tooltip: 'Übungen importieren',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _importExercises,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: const Text('Neue Übung anlegen'),
                    subtitle: const Text('Übungseigenschaften erfassen'),
                    onTap: _createExercise,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nach Name filtern',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => _nameFilter = value.trim()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Nach Typ filtern',
                    border: OutlineInputBorder(),
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
                      setState(() => _typeFilter = value ?? ''),
                ),
                const SizedBox(height: 16),
                if (_exercises.isEmpty)
                  const Center(child: Text('Noch keine Übungen angelegt.'))
                else if (_visibleExercises.isEmpty)
                  const Center(child: Text('Keine Übungen gefunden.'))
                else
                  for (final exercise in _visibleExercises)
                    _ExerciseListTile(
                      exercise: exercise,
                      onEdit: () => _editExercise(exercise),
                      onShare: () => _shareExercise(exercise),
                      onCopy: () => _copyExercise(exercise),
                      onDelete: () => _deleteExercise(exercise),
                    ),
              ],
            ),
    );
  }
}

class _ExerciseListTile extends StatelessWidget {
  const _ExerciseListTile({
    required this.exercise,
    required this.onEdit,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
  });

  final TrainingExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactActions = constraints.maxWidth < 1000;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center_outlined),
            title: Text(exercise.title),
            subtitle: Text(
              '${exercise.type} · ${exercise.duration}\n${exercise.goal}',
            ),
            isThreeLine: true,
            onTap: onEdit,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compactActions)
                  PopupMenuButton<String>(
                    tooltip: 'Weitere Aktionen',
                    onSelected: (action) {
                      switch (action) {
                        case 'share':
                          onShare();
                        case 'copy':
                          onCopy();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_outlined,
                                color: Theme.of(context).iconTheme.color),
                            const SizedBox(width: 12),
                            Text('Übung teilen'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_outlined,
                                color: Theme.of(context).iconTheme.color),
                            const SizedBox(width: 12),
                            Text('Übung kopieren'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                color: Theme.of(context).iconTheme.color),
                            const SizedBox(width: 12),
                            Text('Übung löschen'),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  IconButton(
                    tooltip: 'Übung teilen',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: onShare,
                  ),
                  IconButton(
                    tooltip: 'Übung kopieren',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: onCopy,
                  ),
                  IconButton(
                    tooltip: 'Übung löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TrainingExerciseEditPage extends StatefulWidget {
  const TrainingExerciseEditPage({
    super.key,
    required this.exercise,
    required this.onChanged,
  });

  final TrainingExercise exercise;
  final ValueChanged<TrainingExercise> onChanged;

  @override
  State<TrainingExerciseEditPage> createState() =>
      _TrainingExerciseEditPageState();
}

class _TrainingExerciseEditPageState extends State<TrainingExerciseEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _goalController;
  late final TextEditingController _durationController;
  late final TextEditingController _descriptionController;
  late String _type;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _titleController = TextEditingController(text: exercise.title);
    _goalController = TextEditingController(text: exercise.goal);
    _durationController = TextEditingController(text: exercise.duration);
    _descriptionController = TextEditingController(text: exercise.description);
    _type = exercise.type;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(
      TrainingExercise(
        id: widget.exercise.id,
        title: _titleController.text.trim(),
        type: _type,
        goal: _goalController.text.trim(),
        duration: _durationController.text.trim(),
        description: _descriptionController.text.trim(),
        status: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Übung bearbeiten')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
                _notifyChanged();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Typ',
                border: OutlineInputBorder(),
              ),
              items: TrainingExercise.types
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                  _notifyChanged();
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                labelText: 'Ziel',
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
              onChanged: (_) => _notifyChanged(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _descriptionController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _notifyChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
