import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import '../backup/app_backup_service.dart';
import '../theme/app_palette.dart';

enum _Tool { touch, point, freehand, straight, arrow }

enum _LineType { freehand, straight, arrow }

enum _SelectionKind { point, line }

class _DeleteSelectionIntent extends Intent {
  const _DeleteSelectionIntent();
}

class _BoardSelection {
  const _BoardSelection({required this.kind, required this.index});

  final _SelectionKind kind;
  final int index;
}

class _BoardPoint {
  const _BoardPoint({required this.position, required this.color});

  final Offset position;
  final Color color;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': position.dx,
        'y': position.dy,
        'color': color.toARGB32(),
      };

  static _BoardPoint fromJson(Map<String, dynamic> data) => _BoardPoint(
        position: Offset(
          (data['x'] as num?)?.toDouble() ?? 0.5,
          (data['y'] as num?)?.toDouble() ?? 0.5,
        ),
        color: Color(
          (data['color'] as num?)?.toInt() ??
              const Color(0xFFe57373).toARGB32(),
        ),
      );
}

class _BoardLine {
  const _BoardLine({
    required this.points,
    required this.color,
    this.type = _LineType.freehand,
  });

  final List<Offset> points;
  final Color color;
  final _LineType type;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points
            .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
            .toList(),
        'color': color.toARGB32(),
        'type': type.name,
      };

  static _BoardLine fromJson(Map<String, dynamic> data) {
    final storedPoints = data['points'];
    return _BoardLine(
      points: storedPoints is List
          ? storedPoints
              .whereType<Map>()
              .map(
                (point) => Offset(
                  (point['x'] as num?)?.toDouble() ?? 0.5,
                  (point['y'] as num?)?.toDouble() ?? 0.5,
                ),
              )
              .toList()
          : const <Offset>[],
      color: Color(
        (data['color'] as num?)?.toInt() ?? const Color(0xFFe57373).toARGB32(),
      ),
      type: _lineTypeFromJson(data['type']),
    );
  }

  static _LineType _lineTypeFromJson(Object? value) {
    return _LineType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => _LineType.freehand,
    );
  }
}

class _TacticPage {
  const _TacticPage(
      {required this.points, required this.lines, this.note = ''});

  final List<_BoardPoint> points;
  final List<_BoardLine> lines;
  final String note;

  _TacticPage copy() => _TacticPage(
        points: List<_BoardPoint>.from(points),
        note: note,
        lines: lines
            .map(
              (line) => _BoardLine(
                points: List<Offset>.from(line.points),
                color: line.color,
                type: line.type,
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points.map((point) => point.toJson()).toList(),
        'lines': lines.map((line) => line.toJson()).toList(),
        'note': note,
      };

  static _TacticPage fromJson(Map<String, dynamic> data) {
    final storedPoints = data['points'];
    final storedLines = data['lines'];
    return _TacticPage(
      points: storedPoints is List
          ? storedPoints
              .whereType<Map>()
              .map((item) =>
                  _BoardPoint.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <_BoardPoint>[],
      lines: storedLines is List
          ? storedLines
              .whereType<Map>()
              .map((item) =>
                  _BoardLine.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <_BoardLine>[],
      note: data['note'] is String ? data['note'] as String : '',
    );
  }
}

class _SavedTactic {
  const _SavedTactic({
    required this.id,
    required this.name,
    required this.pages,
  });

  final int id;
  final String name;
  final List<_TacticPage> pages;

  _TacticPage get firstPage => pages.isEmpty
      ? const _TacticPage(points: <_BoardPoint>[], lines: <_BoardLine>[])
      : pages.first;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'pages': pages.map((page) => page.toJson()).toList(),
      };

  static _SavedTactic fromJson(Map<String, dynamic> data) {
    final storedPages = data['pages'];
    final pages = storedPages is List
        ? storedPages
            .whereType<Map>()
            .map(
                (item) => _TacticPage.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <_TacticPage>[
            _TacticPage.fromJson(data),
          ];
    return _SavedTactic(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      name: data['name'] is String ? data['name'] as String : 'Unbenannt',
      pages: pages,
    );
  }
}

class TacticsPage extends StatefulWidget {
  const TacticsPage({
    super.key,
    required this.database,
    this.embeddedBoard,
    this.onEmbeddedBoardChanged,
    this.embeddedTitle,
  });

  final Database database;
  final Map<String, dynamic>? embeddedBoard;
  final ValueChanged<Map<String, dynamic>>? onEmbeddedBoardChanged;
  final String? embeddedTitle;

  @override
  State<TacticsPage> createState() => _TacticsPageState();
}

class _TacticsPageState extends State<TacticsPage> {
  static const _recordKey = 'board';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('tactics');
  static const _colors = <Color>[
    AppPalette.red,
    AppPalette.blue,
    AppPalette.yellow,
    AppPalette.green,
    Colors.white,
  ];

  final List<_BoardPoint> _points = <_BoardPoint>[];
  final List<_BoardLine> _lines = <_BoardLine>[];
  final List<_TacticPage> _pages = <_TacticPage>[];
  final List<_SavedTactic> _savedTactics = <_SavedTactic>[];
  final TextEditingController _pageNoteController = TextEditingController();
  Color _selectedColor = AppPalette.red;
  _Tool _tool = _Tool.point;
  List<Offset>? _activeLine;
  int? _movingPointIndex;
  int? _movingLineIndex;
  Offset? _lastDragPosition;
  _BoardSelection? _selection;
  String? _activeTacticName;
  bool _isRotated = false;
  bool _showPointNumbers = false;
  bool _showPageNote = true;
  bool _showBoard = false;
  int _currentPageIndex = 0;
  bool _isObjectHovered = false;
  int _activePointerCount = 0;
  bool _multiTouchActive = false;
  bool _rawPointerMoved = false;
  Offset? _pointerDownPosition;
  Offset? _lastRawPointerPosition;
  bool _isLoaded = false;

  @override
  void dispose() {
    _pageNoteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _showBoard = widget.embeddedBoard != null;
    _load();
  }

  Future<void> _load() async {
    final data = widget.embeddedBoard ??
        await _store.record(_recordKey).get(widget.database);
    if (!mounted) return;
    final storedPoints = data?['points'];
    final storedLines = data?['lines'];
    final storedPages = data?['pages'];
    final storedTactics = data?['tactics'];
    setState(() {
      _points
        ..clear()
        ..addAll(
          storedPoints is List
              ? storedPoints.whereType<Map>().map((item) =>
                  _BoardPoint.fromJson(Map<String, dynamic>.from(item)))
              : const <_BoardPoint>[],
        );
      _lines
        ..clear()
        ..addAll(
          storedLines is List
              ? storedLines.whereType<Map>().map((item) =>
                  _BoardLine.fromJson(Map<String, dynamic>.from(item)))
              : const <_BoardLine>[],
        );
      _pages
        ..clear()
        ..addAll(
          storedPages is List
              ? storedPages.whereType<Map>().map((item) =>
                  _TacticPage.fromJson(Map<String, dynamic>.from(item)))
              : <_TacticPage>[
                  _TacticPage(
                    points: List<_BoardPoint>.from(_points),
                    lines: _lines
                        .map((line) => _BoardLine(
                              points: List<Offset>.from(line.points),
                              color: line.color,
                              type: line.type,
                            ))
                        .toList(),
                  ),
                ],
        );
      if (_pages.isEmpty) {
        _pages.add(const _TacticPage(points: [], lines: []));
      }
      _currentPageIndex = 0;
      _loadPage(_currentPageIndex);
      _savedTactics
        ..clear()
        ..addAll(
          storedTactics is List
              ? storedTactics.whereType<Map>().map((item) =>
                  _SavedTactic.fromJson(Map<String, dynamic>.from(item)))
              : const <_SavedTactic>[],
        );
      _activeTacticName = data?['activeTacticName'] as String?;
      _isRotated = (data?['isRotated']) is bool
          ? (data?['isRotated'] as bool)
          : (data?['isLandscape']) is bool
              ? (data?['isLandscape'] as bool)
              : false;
      _showPointNumbers = (data?['showPointNumbers'] as bool?) ?? false;
      _showPageNote = (data?['showPageNote'] as bool?) ?? true;
      _isLoaded = true;
    });
  }

  _TacticPage _currentPageSnapshot() => _TacticPage(
        points: List<_BoardPoint>.from(_points),
        note: _pageNoteController.text,
        lines: _lines
            .map((line) => _BoardLine(
                  points: List<Offset>.from(line.points),
                  color: line.color,
                  type: line.type,
                ))
            .toList(),
      );

  void _syncCurrentPage() {
    if (_pages.isEmpty) {
      _pages.add(_currentPageSnapshot());
    } else {
      _pages[_currentPageIndex] = _currentPageSnapshot();
    }
  }

  void _loadPage(int index) {
    final page = _pages[index];
    _pageNoteController.text = page.note;
    _points
      ..clear()
      ..addAll(page.points);
    _lines
      ..clear()
      ..addAll(page.lines.map((line) => _BoardLine(
            points: List<Offset>.from(line.points),
            color: line.color,
            type: line.type,
          )));
    _selection = null;
  }

  Future<void> _persist() {
    _syncCurrentPage();
    if (_activeTacticName != null) {
      final index = _savedTactics.indexWhere(
        (tactic) => tactic.name == _activeTacticName,
      );
      if (index >= 0) {
        _savedTactics[index] = _SavedTactic(
          id: _savedTactics[index].id,
          name: _savedTactics[index].name,
          pages: _pages.map((page) => page.copy()).toList(),
        );
      }
    }
    final payload = <String, dynamic>{
      'pages': _pages.map((page) => page.toJson()).toList(),
      'isRotated': _isRotated,
      'showPointNumbers': _showPointNumbers,
      'showPageNote': _showPageNote,
    };
    if (widget.embeddedBoard != null) {
      widget.onEmbeddedBoardChanged?.call(payload);
      return Future<void>.value();
    }
    return _store.record(_recordKey).put(
      widget.database,
      <String, dynamic>{
        'points': _points.map((point) => point.toJson()).toList(),
        'lines': _lines.map((line) => line.toJson()).toList(),
        'pages': _pages.map((page) => page.toJson()).toList(),
        'tactics': _savedTactics.map((tactic) => tactic.toJson()).toList(),
        'activeTacticName': _activeTacticName,
        'isRotated': _isRotated,
        'showPointNumbers': _showPointNumbers,
        'showPageNote': _showPageNote,
      },
    );
  }

  Future<void> _createTactic() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neue Taktik'),
        content: TextField(
          key: const ValueKey('tactic-name-input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name der Taktik'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isEmpty || !mounted) return;
    final tactic = _SavedTactic(
      id: _savedTactics.isEmpty
          ? 1
          : _savedTactics
                  .map((entry) => entry.id)
                  .reduce((a, b) => a > b ? a : b) +
              1,
      name: trimmedName,
      pages: [const _TacticPage(points: [], lines: [])],
    );
    setState(() {
      _savedTactics.add(tactic);
      _activeTacticName = tactic.name;
      _pages
        ..clear()
        ..add(tactic.firstPage.copy());
      _currentPageIndex = 0;
      _loadPage(0);
      _showBoard = true;
    });
    await _persist();
  }

  Future<void> _shareSavedTactic(_SavedTactic tactic) async {
    final payload = <String, dynamic>{
      'type': 'tactics-board',
      'savedAt': DateTime.now().toIso8601String(),
      'name': tactic.name,
      'pages': tactic.pages.map((page) => page.toJson()).toList(),
    };
    await AppBackupService.shareOrSaveJson(
      context,
      suggestedName:
          'volleyace-taktiktafel-${DateTime.now().millisecondsSinceEpoch}.json',
      jsonText: const JsonEncoder.withIndent('  ').convert(payload),
      subject: 'VolleyAce Taktiktafel-Stand',
      dialogTitle: 'Taktiktafel speichern',
    );
  }

  Future<void> _importTactic() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Taktik importieren',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (result.isEmpty) return;
      final bytes = await result.single.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Ungültiges Taktikformat.');
      }
      final data = Map<String, dynamic>.from(decoded);
      final rawTactic = data['tactic'] is Map ? data['tactic'] : data;
      final tactic = _SavedTactic.fromJson(
        Map<String, dynamic>.from(rawTactic as Map),
      );
      final nextId = _savedTactics.isEmpty
          ? 1
          : _savedTactics
                  .map((entry) => entry.id)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      final imported = _SavedTactic(
        id: nextId,
        name: '${tactic.name} (Import)',
        pages: tactic.pages.map((page) => page.copy()).toList(),
      );
      setState(() => _savedTactics.add(imported));
      await _persist();
      _loadTactic(imported);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Taktik konnte nicht importiert werden: $error')),
      );
    }
  }

  void _handleDeleteSelectionIntent() {
    if (_selection == null) return;
    _deleteSelection();
  }

  void _loadTactic(_SavedTactic tactic) {
    setState(() {
      _pages
        ..clear()
        ..addAll(tactic.pages.map((page) => page.copy()));
      _currentPageIndex = 0;
      _loadPage(_currentPageIndex);
      _selection = null;
      _activeTacticName = tactic.name;
      _showBoard = true;
    });
    _persist();
  }

  void _addPage() {
    _syncCurrentPage();
    setState(() {
      _pages.add(_pages[_currentPageIndex].copy());
      _currentPageIndex = _pages.length - 1;
      _loadPage(_currentPageIndex);
    });
    _persist();
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pages.length || index == _currentPageIndex) {
      return;
    }
    _syncCurrentPage();
    setState(() {
      _currentPageIndex = index;
      _loadPage(index);
    });
    _persist();
  }

  void _deleteCurrentPage() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_currentPageIndex);
      _currentPageIndex = _currentPageIndex.clamp(0, _pages.length - 1);
      _loadPage(_currentPageIndex);
    });
    _persist();
  }

  Future<void> _deleteTactic(_SavedTactic tactic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Taktik löschen?'),
        content: Text('„${tactic.name}“ wird unwiderruflich gelöscht.'),
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
    if (confirmed != true || !mounted) return;
    setState(() {
      _savedTactics.removeWhere((entry) => entry.id == tactic.id);
      if (_activeTacticName == tactic.name) _activeTacticName = null;
    });
    _persist();
  }

  Offset _relativePosition(Offset position, Size size) {
    final normalized = Offset(
      (position.dx / size.width).clamp(0.0, 1.0),
      (position.dy / size.height).clamp(0.0, 1.0),
    );
    return _isRotated ? Offset(1 - normalized.dy, normalized.dx) : normalized;
  }

  void _handleTap(TapUpDetails details, Size size) {
    final position = _relativePosition(details.localPosition, size);
    final pointIndex = _findPointAt(position, size);
    if (pointIndex != null) {
      setState(() => _selection = _BoardSelection(
            kind: _SelectionKind.point,
            index: pointIndex,
          ));
      return;
    }
    final lineIndex = _findLineAt(position, size);
    if (lineIndex != null) {
      setState(() => _selection = _BoardSelection(
            kind: _SelectionKind.line,
            index: lineIndex,
          ));
      return;
    }
    if (_selection != null) {
      setState(() => _selection = null);
    }
    if (_tool != _Tool.point) return;
    setState(() => _points.add(
          _BoardPoint(
            position: position,
            color: _selectedColor,
          ),
        ));
    _persist();
  }

  void _startDrag(DragStartDetails details, Size size) {
    final position = _relativePosition(details.localPosition, size);
    if (_tool == _Tool.touch || _tool == _Tool.point) {
      final pointIndex = _findPointAt(position, size);
      if (pointIndex != null) {
        setState(() {
          _movingPointIndex = pointIndex;
          _selection = _BoardSelection(
            kind: _SelectionKind.point,
            index: pointIndex,
          );
          _lastDragPosition = position;
        });
        return;
      }
      if (_tool == _Tool.point) return;
    }
    final lineIndex = _findLineAt(position, size);
    setState(() {
      _lastDragPosition = position;
      if (lineIndex != null) {
        _movingLineIndex = lineIndex;
        _selection = _BoardSelection(
          kind: _SelectionKind.line,
          index: lineIndex,
        );
      } else if (_tool != _Tool.touch &&
          (_tool == _Tool.freehand ||
              _tool == _Tool.straight ||
              _tool == _Tool.arrow)) {
        _activeLine = <Offset>[position];
      }
    });
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    final position = _relativePosition(details.localPosition, size);
    final pointIndex = _movingPointIndex;
    if (pointIndex != null) {
      setState(() {
        _points[pointIndex] = _BoardPoint(
          position: position,
          color: _points[pointIndex].color,
        );
        _lastDragPosition = position;
      });
      return;
    }
    final lineIndex = _movingLineIndex;
    final lastPosition = _lastDragPosition;
    if (lineIndex != null && lastPosition != null) {
      final delta = position - lastPosition;
      setState(() {
        final line = _lines[lineIndex];
        _lines[lineIndex] = _BoardLine(
          color: line.color,
          type: line.type,
          points: line.points
              .map(
                (point) => Offset(
                  (point.dx + delta.dx).clamp(0.0, 1.0),
                  (point.dy + delta.dy).clamp(0.0, 1.0),
                ),
              )
              .toList(),
        );
        _lastDragPosition = position;
      });
      return;
    }
    if (_activeLine == null) return;
    setState(() {
      if (_tool == _Tool.freehand) {
        _activeLine!.add(position);
      } else {
        if (_activeLine!.length == 1) {
          _activeLine!.add(position);
        } else {
          _activeLine![1] = position;
        }
      }
    });
  }

  void _finishDrag(DragEndDetails details) {
    final line = _activeLine;
    setState(() {
      if (line != null && line.length > 1) {
        _lines.add(
          _BoardLine(
            points: line,
            color: _selectedColor,
            type: switch (_tool) {
              _Tool.arrow => _LineType.arrow,
              _Tool.straight => _LineType.straight,
              _ => _LineType.freehand,
            },
          ),
        );
      }
      _activeLine = null;
      _movingPointIndex = null;
      _movingLineIndex = null;
      _lastDragPosition = null;
    });
    _persist();
  }

  int? _findPointAt(Offset position, Size size) {
    const hitRadius = 20.0;
    for (var index = _points.length - 1; index >= 0; index--) {
      final point = _points[index].position;
      final distance = Offset(
        (point.dx - position.dx) * size.width,
        (point.dy - position.dy) * size.height,
      ).distance;
      if (distance <= hitRadius) return index;
    }
    return null;
  }

  int? _findLineAt(Offset position, Size size) {
    const hitDistance = 14.0;
    for (var index = _lines.length - 1; index >= 0; index--) {
      final points = _lines[index].points;
      for (var pointIndex = 1; pointIndex < points.length; pointIndex++) {
        final start = Offset(points[pointIndex - 1].dx * size.width,
            points[pointIndex - 1].dy * size.height);
        final end = Offset(points[pointIndex].dx * size.width,
            points[pointIndex].dy * size.height);
        final target =
            Offset(position.dx * size.width, position.dy * size.height);
        if (_distanceToSegment(target, start, end) <= hitDistance) return index;
      }
    }
    return null;
  }

  static double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final projection =
        ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
            lengthSquared;
    final nearest = start + segment * projection.clamp(0.0, 1.0);
    return (point - nearest).distance;
  }

  void _undo() {
    setState(() {
      if (_tool != _Tool.point && _lines.isNotEmpty) {
        _lines.removeLast();
      } else if (_points.isNotEmpty) {
        _points.removeLast();
      } else if (_lines.isNotEmpty) {
        _lines.removeLast();
      }
    });
    _persist();
  }

  Future<void> _deleteSelection() async {
    final selection = _selection;
    if (selection == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Objekt löschen?'),
        content: const Text('Das ausgewählte Objekt wird gelöscht.'),
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
    if (confirmed != true || !mounted) return;
    setState(() {
      if (selection.kind == _SelectionKind.point &&
          selection.index < _points.length) {
        _points.removeAt(selection.index);
      }
      if (selection.kind == _SelectionKind.line &&
          selection.index < _lines.length) {
        _lines.removeAt(selection.index);
      }
      _selection = null;
    });
    _persist();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Taktiktafel leeren?'),
        content: const Text('Alle Punkte und Linien werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leeren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _points.clear();
      _lines.clear();
      _selection = null;
    });
    _persist();
  }

  Widget _buildTacticList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taktiktafel'),
        actions: [
          IconButton(
            key: const ValueKey('import-tactic-button'),
            tooltip: 'Taktik importieren',
            onPressed: _importTactic,
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const ValueKey('new-tactic-button'),
              leading: const CircleAvatar(child: Icon(Icons.add)),
              title: const Text('Neue Taktik'),
              subtitle: const Text('Taktiktafel öffnen'),
              onTap: _createTactic,
            ),
          ),
          const SizedBox(height: 12),
          if (_savedTactics.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Noch keine Taktiken gespeichert.'),
              ),
            )
          else
            for (final tactic in _savedTactics)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.sports_volleyball),
                  title: Text(tactic.name),
                  subtitle: Text(
                    '${tactic.pages.length} Seiten • ${tactic.pages.fold<int>(0, (total, page) => total + page.points.length)} Punkte',
                  ),
                  onTap: () => _loadTactic(tactic),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Taktik teilen',
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _shareSavedTactic(tactic),
                      ),
                      IconButton(
                        tooltip: 'Taktik löschen',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTactic(tactic),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _showBoard ? _buildBoard(context) : _buildTacticList();
  }

  Widget _buildBoard(BuildContext context) {
    final isAndroidLandscape =
        Theme.of(context).platform == TargetPlatform.android &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: isAndroidLandscape
          ? null
          : AppBar(
              title: Text(widget.embeddedTitle ?? 'Taktiktafel'),
              leading: IconButton(
                tooltip: 'Zurück zur Taktikübersicht',
                onPressed: _closeBoard,
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                IconButton(
                  tooltip: _isRotated
                      ? 'Feld ins Hochformat drehen'
                      : 'Feld ins Querformat drehen',
                  onPressed: () {
                    setState(() => _isRotated = !_isRotated);
                    _persist();
                  },
                  icon: const Icon(Icons.screen_rotation),
                ),
                IconButton(
                  tooltip:
                      _showPageNote ? 'Notiz ausblenden' : 'Notiz einblenden',
                  color: _showPageNote
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  onPressed: () {
                    setState(() => _showPageNote = !_showPageNote);
                    _persist();
                  },
                  icon: Icon(
                    _showPageNote ? Icons.notes : Icons.notes_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Neue Seite aus aktueller Seite',
                  onPressed: _addPage,
                  icon: const Icon(Icons.note_add_outlined),
                ),
                IconButton(
                  tooltip: 'Vorherige Seite',
                  onPressed: _currentPageIndex == 0
                      ? null
                      : () => _selectPage(_currentPageIndex - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Nächste Seite',
                  onPressed: _currentPageIndex >= _pages.length - 1
                      ? null
                      : () => _selectPage(_currentPageIndex + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      body: !_isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.delete):
                      _DeleteSelectionIntent(),
                  SingleActivator(LogicalKeyboardKey.backspace):
                      _DeleteSelectionIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _DeleteSelectionIntent:
                        CallbackAction<_DeleteSelectionIntent>(
                      onInvoke: (intent) {
                        _handleDeleteSelectionIntent();
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const toolbarHeight = 116.0;
                        final availableHeight = constraints.maxHeight -
                            (isAndroidLandscape ? 0 : toolbarHeight);
                        final availableWidth = constraints.maxWidth - 24;
                        final boardAspectRatio = _isRotated ? 1.6 : 0.625;
                        final contentWidth = _showPageNote
                            ? (availableWidth - 12) / 2
                            : availableWidth;
                        final boardHeight =
                            contentWidth / boardAspectRatio < availableHeight
                                ? contentWidth / boardAspectRatio
                                : availableHeight;
                        final boardWidth = boardHeight * boardAspectRatio;
                        _isRotated ? boardHeight * 2 : boardHeight / 2;
                        final size = Size(boardWidth, boardHeight);
                        return Column(
                          children: [
                            if (!isAndroidLandscape)
                              SizedBox(
                                height: toolbarHeight,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SegmentedButton<_Tool>(
                                              showSelectedIcon: false,
                                              segments: const [
                                                ButtonSegment(
                                                  value: _Tool.touch,
                                                  icon: Icon(
                                                      Icons.pan_tool_outlined),
                                                  tooltip:
                                                      'Objekte verschieben',
                                                ),
                                                ButtonSegment(
                                                  value: _Tool.point,
                                                  icon: Icon(Icons.circle),
                                                  tooltip: 'Punkte platzieren',
                                                ),
                                                ButtonSegment(
                                                  value: _Tool.freehand,
                                                  icon: Icon(Icons.gesture),
                                                  tooltip:
                                                      'Freihandlinie zeichnen',
                                                ),
                                                ButtonSegment(
                                                  value: _Tool.straight,
                                                  icon: Icon(Icons.remove),
                                                  tooltip:
                                                      'Gerade Linie zeichnen',
                                                ),
                                                ButtonSegment(
                                                  value: _Tool.arrow,
                                                  icon:
                                                      Icon(Icons.arrow_forward),
                                                  tooltip: 'Pfeil zeichnen',
                                                ),
                                              ],
                                              selected: <_Tool>{_tool},
                                              onSelectionChanged: (selected) =>
                                                  setState(() =>
                                                      _tool = selected.first),
                                            ),
                                            IconButton(
                                              tooltip: 'Rückgängig',
                                              onPressed: _points.isEmpty &&
                                                      _lines.isEmpty
                                                  ? null
                                                  : _undo,
                                              icon: const Icon(Icons.undo),
                                            ),
                                            IconButton(
                                              tooltip: 'Aktuelle Seite leeren',
                                              onPressed: _points.isEmpty &&
                                                      _lines.isEmpty
                                                  ? null
                                                  : _clear,
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                            ),
                                            IconButton(
                                              tooltip: 'Aktuelle Seite löschen',
                                              onPressed: _pages.length > 1
                                                  ? _deleteCurrentPage
                                                  : null,
                                              icon: const Icon(
                                                  Icons.delete_sweep_outlined),
                                            ),
                                            if (_selection != null)
                                              IconButton(
                                                tooltip:
                                                    'Ausgewähltes Objekt löschen',
                                                onPressed: _deleteSelection,
                                                icon: const Icon(
                                                    Icons.delete_forever),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 4,
                                        children: [
                                          IconButton(
                                            tooltip: _showPointNumbers
                                                ? 'Punktnummern ausblenden'
                                                : 'Punktnummern anzeigen',
                                            color: _showPointNumbers
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                            onPressed: () {
                                              setState(() => _showPointNumbers =
                                                  !_showPointNumbers);
                                              _persist();
                                            },
                                            icon: const Icon(
                                                Icons.format_list_numbered),
                                          ),
                                          for (final color in _colors)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              child: IconButton(
                                                tooltip: 'Farbe auswählen',
                                                onPressed: () => setState(() =>
                                                    _selectedColor = color),
                                                icon: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: _selectedColor ==
                                                              color
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                          : Colors.transparent,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: const SizedBox(
                                                      width: 20, height: 20),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InteractiveViewer(
                                      key: const ValueKey(
                                          'tactics-board-viewport'),
                                      minScale: 1,
                                      maxScale: 4,
                                      panEnabled: false,
                                      scaleEnabled: true,
                                      trackpadScrollCausesScale: true,
                                      boundaryMargin: const EdgeInsets.all(320),
                                      constrained: true,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: boardWidth,
                                        height: boardHeight,
                                        child: Semantics(
                                          label: 'Volleyballfeld',
                                          child: MouseRegion(
                                            cursor: _isObjectHovered
                                                ? SystemMouseCursors.click
                                                : SystemMouseCursors.basic,
                                            onHover: (event) {
                                              final position =
                                                  _relativePosition(
                                                event.localPosition,
                                                size,
                                              );
                                              final isHovered = _findPointAt(
                                                          position, size) !=
                                                      null ||
                                                  _findLineAt(position, size) !=
                                                      null;
                                              if (isHovered !=
                                                  _isObjectHovered) {
                                                setState(() =>
                                                    _isObjectHovered =
                                                        isHovered);
                                              }
                                            },
                                            onExit: (_) {
                                              if (_isObjectHovered) {
                                                setState(() =>
                                                    _isObjectHovered = false);
                                              }
                                            },
                                            child: Listener(
                                              key: const ValueKey(
                                                  'tactics-board'),
                                              onPointerDown: (event) {
                                                _activePointerCount++;
                                                if (_activePointerCount > 1) {
                                                  _multiTouchActive = true;
                                                  _activeLine = null;
                                                  _movingPointIndex = null;
                                                  _movingLineIndex = null;
                                                  return;
                                                }
                                                _rawPointerMoved = false;
                                                _pointerDownPosition =
                                                    event.localPosition;
                                                _lastRawPointerPosition =
                                                    event.localPosition;
                                                _startDrag(
                                                  DragStartDetails(
                                                    globalPosition:
                                                        event.position,
                                                    localPosition:
                                                        event.localPosition,
                                                    kind: event.kind,
                                                  ),
                                                  size,
                                                );
                                              },
                                              onPointerMove: (event) {
                                                if (_activePointerCount != 1 ||
                                                    _multiTouchActive) {
                                                  return;
                                                }
                                                final downPosition =
                                                    _pointerDownPosition;
                                                if (downPosition != null &&
                                                    (event.localPosition -
                                                                downPosition)
                                                            .distance >
                                                        8) {
                                                  _rawPointerMoved = true;
                                                }
                                                _lastRawPointerPosition =
                                                    event.localPosition;
                                                _updateDrag(
                                                  DragUpdateDetails(
                                                    globalPosition:
                                                        event.position,
                                                    localPosition:
                                                        event.localPosition,
                                                    kind: event.kind,
                                                  ),
                                                  size,
                                                );
                                              },
                                              onPointerUp: (event) {
                                                if (_activePointerCount == 1 &&
                                                    !_multiTouchActive) {
                                                  if (!_rawPointerMoved) {
                                                    _handleTap(
                                                      TapUpDetails(
                                                        kind: event.kind,
                                                        localPosition:
                                                            event.localPosition,
                                                      ),
                                                      size,
                                                    );
                                                  }
                                                  _finishDrag(DragEndDetails());
                                                }
                                                _activePointerCount =
                                                    (_activePointerCount - 1)
                                                        .clamp(0, 10);
                                                if (_activePointerCount == 0) {
                                                  _multiTouchActive = false;
                                                  _pointerDownPosition = null;
                                                }
                                              },
                                              onPointerCancel: (event) {
                                                if (_activePointerCount == 1 &&
                                                    !_multiTouchActive &&
                                                    !_rawPointerMoved &&
                                                    _lastRawPointerPosition !=
                                                        null) {
                                                  _handleTap(
                                                    TapUpDetails(
                                                      kind: event.kind,
                                                      localPosition:
                                                          _lastRawPointerPosition!,
                                                    ),
                                                    size,
                                                  );
                                                }
                                                _activePointerCount =
                                                    (_activePointerCount - 1)
                                                        .clamp(0, 10);
                                                if (_activePointerCount == 0) {
                                                  _multiTouchActive = false;
                                                  _pointerDownPosition = null;
                                                  _finishDrag(DragEndDetails());
                                                }
                                              },
                                              child: CustomPaint(
                                                size: size,
                                                painter:
                                                    _VolleyballCourtPainter(
                                                  points: _points,
                                                  lines: _lines,
                                                  activeLine: _activeLine,
                                                  activeLineType: switch (
                                                      _tool) {
                                                    _Tool.arrow =>
                                                      _LineType.arrow,
                                                    _Tool.straight =>
                                                      _LineType.straight,
                                                    _ => _LineType.freehand,
                                                  },
                                                  activeColor: _selectedColor,
                                                  outerColor: Theme.of(context)
                                                      .cardColor,
                                                  selection: _selection,
                                                  isRotated: _isRotated,
                                                  showPointNumbers:
                                                      _showPointNumbers,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_showPageNote) ...[
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: boardWidth,
                                        height: boardHeight,
                                        child: TextField(
                                          key: const ValueKey(
                                              'tactics-page-note-input'),
                                          controller: _pageNoteController,
                                          expands: true,
                                          maxLines: null,
                                          minLines: null,
                                          textAlignVertical:
                                              TextAlignVertical.top,
                                          decoration: const InputDecoration(
                                            labelText: 'Notiz dieser Seite',
                                            alignLabelWithHint: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (_) => _persist(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _closeBoard() {
    _syncCurrentPage();
    _persist();
    if (widget.embeddedBoard != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _showBoard = false);
  }
}

class _VolleyballCourtPainter extends CustomPainter {
  const _VolleyballCourtPainter({
    required this.points,
    required this.lines,
    required this.activeLine,
    required this.activeLineType,
    required this.activeColor,
    required this.outerColor,
    required this.selection,
    required this.isRotated,
    required this.showPointNumbers,
  });

  final List<_BoardPoint> points;
  final List<_BoardLine> lines;
  final List<Offset>? activeLine;
  final _LineType activeLineType;
  final Color activeColor;
  final Color outerColor;
  final _BoardSelection? selection;
  final bool isRotated;
  final bool showPointNumbers;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final horizontalMargin = isRotated ? 0.125 : 0.2;
    final verticalMargin = isRotated ? 0.2 : 0.125;
    final court = Rect.fromLTWH(
      outer.left + outer.width * horizontalMargin,
      outer.top + outer.height * verticalMargin,
      outer.width * (1 - horizontalMargin * 2),
      outer.height * (1 - verticalMargin * 2),
    );
    canvas.drawRect(outer, Paint()..color = outerColor);
    canvas.drawRect(
      outer,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRect(court, Paint()..color = const Color(0xFFD89A58));
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRect(court, linePaint);
    if (isRotated) {
      final netX = court.center.dx;
      final threeMeter = court.width / 6;
      canvas.drawLine(
        Offset(netX, court.top),
        Offset(netX, court.bottom),
        linePaint,
      );
      canvas.drawLine(
        Offset(netX - threeMeter, court.top),
        Offset(netX - threeMeter, court.bottom),
        linePaint,
      );
      canvas.drawLine(
        Offset(netX + threeMeter, court.top),
        Offset(netX + threeMeter, court.bottom),
        linePaint,
      );
    } else {
      final netY = court.center.dy;
      final threeMeter = court.height / 6;
      canvas.drawLine(
        Offset(court.left, netY),
        Offset(court.right, netY),
        linePaint,
      );
      canvas.drawLine(
        Offset(court.left, netY - threeMeter),
        Offset(court.right, netY - threeMeter),
        linePaint,
      );
      canvas.drawLine(
        Offset(court.left, netY + threeMeter),
        Offset(court.right, netY + threeMeter),
        linePaint,
      );
    }

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      _drawLine(
        canvas,
        size,
        _rotatePoints(line.points),
        line.color,
        type: line.type,
        isSelected:
            selection?.kind == _SelectionKind.line && selection?.index == index,
      );
    }
    if (activeLine != null) {
      _drawLine(
        canvas,
        size,
        _rotatePoints(activeLine!),
        activeColor,
        type: activeLineType,
      );
    }
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final pointRadius = (size.shortestSide / 320 * 12).clamp(12.0, 24.0);
      final boardPosition = _rotatePosition(point.position);
      final position = Offset(
        boardPosition.dx * size.width,
        boardPosition.dy * size.height,
      );
      final isSelected =
          selection?.kind == _SelectionKind.point && selection?.index == index;
      if (isSelected) {
        canvas.drawCircle(
          position,
          pointRadius + 3,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      canvas.drawCircle(position, pointRadius, Paint()..color = point.color);
      canvas.drawCircle(
        position,
        pointRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (showPointNumbers) {
        final number = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(
              color: Colors.white,
              fontSize: pointRadius * 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(
          canvas,
          position - Offset(number.width / 2, number.height / 2),
        );
      }
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color, {
    _LineType type = _LineType.freehand,
    bool isSelected = false,
  }) {
    if (points.length < 2) return;
    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    if (type == _LineType.arrow) {
      final end = Offset(
        points.last.dx * size.width,
        points.last.dy * size.height,
      );
      final start = Offset(
        points[points.length - 2].dx * size.width,
        points[points.length - 2].dy * size.height,
      );
      final direction = end - start;
      if (direction.distance > 0) {
        final unit = direction / direction.distance;
        final perpendicular = Offset(-unit.dy, unit.dx);
        final arrowLength = 18.0;
        final arrowWidth = 8.0;
        final arrowPath = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - unit.dx * arrowLength + perpendicular.dx * arrowWidth,
            end.dy - unit.dy * arrowLength + perpendicular.dy * arrowWidth,
          )
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - unit.dx * arrowLength - perpendicular.dx * arrowWidth,
            end.dy - unit.dy * arrowLength - perpendicular.dy * arrowWidth,
          );
        canvas.drawPath(
          arrowPath,
          Paint()
            ..color = color
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }
    if (isSelected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  Offset _rotatePosition(Offset position) =>
      isRotated ? Offset(position.dy, 1 - position.dx) : position;

  List<Offset> _rotatePoints(List<Offset> points) =>
      points.map(_rotatePosition).toList();

  @override
  bool shouldRepaint(covariant _VolleyballCourtPainter oldDelegate) => true;
}
