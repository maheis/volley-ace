import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

enum _Tool { point, line }

enum _SelectionKind { point, line }

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
        color: Color((data['color'] as num?)?.toInt() ?? Colors.red.toARGB32()),
      );
}

class _BoardLine {
  const _BoardLine({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points
            .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
            .toList(),
        'color': color.toARGB32(),
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
      color: Color((data['color'] as num?)?.toInt() ?? Colors.red.toARGB32()),
    );
  }
}

class _SavedTactic {
  const _SavedTactic({
    required this.id,
    required this.name,
    required this.points,
    required this.lines,
  });

  final int id;
  final String name;
  final List<_BoardPoint> points;
  final List<_BoardLine> lines;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'points': points.map((point) => point.toJson()).toList(),
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  static _SavedTactic fromJson(Map<String, dynamic> data) {
    final storedPoints = data['points'];
    final storedLines = data['lines'];
    return _SavedTactic(
      id: data['id'] is num ? (data['id'] as num).toInt() : 0,
      name: data['name'] is String ? data['name'] as String : 'Unbenannt',
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
    );
  }
}

class TacticsPage extends StatefulWidget {
  const TacticsPage({super.key, required this.database});

  final Database database;

  @override
  State<TacticsPage> createState() => _TacticsPageState();
}

class _TacticsPageState extends State<TacticsPage> {
  static const _recordKey = 'board';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('tactics');
  static const _colors = <Color>[
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.white,
  ];

  final List<_BoardPoint> _points = <_BoardPoint>[];
  final List<_BoardLine> _lines = <_BoardLine>[];
  final List<_SavedTactic> _savedTactics = <_SavedTactic>[];
  Color _selectedColor = Colors.red;
  _Tool _tool = _Tool.point;
  List<Offset>? _activeLine;
  int? _movingPointIndex;
  int? _movingLineIndex;
  Offset? _lastDragPosition;
  _BoardSelection? _selection;
  String? _activeTacticName;
  bool _isRotated = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.record(_recordKey).get(widget.database);
    if (!mounted) return;
    final storedPoints = data?['points'];
    final storedLines = data?['lines'];
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
      _isLoaded = true;
    });
  }

  Future<void> _persist() => _store.record(_recordKey).put(
        widget.database,
        <String, dynamic>{
          'points': _points.map((point) => point.toJson()).toList(),
          'lines': _lines.map((line) => line.toJson()).toList(),
          'tactics': _savedTactics.map((tactic) => tactic.toJson()).toList(),
          'activeTacticName': _activeTacticName,
          'isRotated': _isRotated,
        },
      );

  Future<void> _saveTactic() async {
    final controller = TextEditingController(text: _activeTacticName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Taktik speichern'),
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
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) return;
    setState(() {
      final index =
          _savedTactics.indexWhere((tactic) => tactic.name == trimmedName);
      final id = index >= 0
          ? _savedTactics[index].id
          : (_savedTactics.isEmpty
              ? 1
              : _savedTactics
                      .map((tactic) => tactic.id)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
      final tactic = _SavedTactic(
        id: id,
        name: trimmedName,
        points: List<_BoardPoint>.from(_points),
        lines: List<_BoardLine>.from(_lines),
      );
      if (index >= 0) {
        _savedTactics[index] = tactic;
      } else {
        _savedTactics.add(tactic);
      }
      _activeTacticName = trimmedName;
    });
    await _persist();
  }

  Future<void> _showTactics() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _savedTactics.isEmpty
            ? const SizedBox(
                height: 128,
                child: Center(child: Text('Noch keine Taktiken gespeichert.')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final tactic in _savedTactics)
                    ListTile(
                      leading: const Icon(Icons.sports_volleyball),
                      title: Text(tactic.name),
                      subtitle: Text(
                          '${tactic.points.length} Punkte • ${tactic.lines.length} Linien'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _loadTactic(tactic);
                      },
                      trailing: IconButton(
                        tooltip: 'Taktik löschen',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTactic(tactic),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _loadTactic(_SavedTactic tactic) {
    setState(() {
      _points
        ..clear()
        ..addAll(tactic.points);
      _lines
        ..clear()
        ..addAll(tactic.lines);
      _selection = null;
      _activeTacticName = tactic.name;
    });
    _persist();
  }

  void _deleteTactic(_SavedTactic tactic) {
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
    if (_tool == _Tool.point) {
      final pointIndex = _findPointAt(position, size);
      if (pointIndex == null) return;
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
    final lineIndex = _findLineAt(position, size);
    setState(() {
      _lastDragPosition = position;
      if (lineIndex != null) {
        _movingLineIndex = lineIndex;
        _selection = _BoardSelection(
          kind: _SelectionKind.line,
          index: lineIndex,
        );
      } else {
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
      _activeLine!.add(position);
    });
  }

  void _finishDrag(DragEndDetails details) {
    final line = _activeLine;
    setState(() {
      if (line != null && line.length > 1) {
        _lines.add(_BoardLine(points: line, color: _selectedColor));
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
      if (_tool == _Tool.line && _lines.isNotEmpty) {
        _lines.removeLast();
      } else if (_points.isNotEmpty) {
        _points.removeLast();
      } else if (_lines.isNotEmpty) {
        _lines.removeLast();
      }
    });
    _persist();
  }

  void _deleteSelection() {
    final selection = _selection;
    if (selection == null) return;
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

  void _clear() {
    setState(() {
      _points.clear();
      _lines.clear();
      _selection = null;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroidLandscape =
        Theme.of(context).platform == TargetPlatform.android &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: isAndroidLandscape
          ? null
          : AppBar(
              title: const Text('Taktiktafel'),
              actions: [
                IconButton(
                  tooltip: 'Taktik laden',
                  onPressed: _showTactics,
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: 'Taktik speichern',
                  onPressed: _saveTactic,
                  icon: const Icon(Icons.save),
                ),
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
                  tooltip: 'Rückgängig',
                  onPressed: _points.isEmpty && _lines.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Alles löschen',
                  onPressed: _points.isEmpty && _lines.isEmpty ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                ),
                if (_selection != null)
                  IconButton(
                    tooltip: 'Ausgewähltes Objekt löschen',
                    onPressed: _deleteSelection,
                    icon: const Icon(Icons.delete_forever),
                  ),
              ],
            ),
      body: !_isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight =
                      constraints.maxHeight - (isAndroidLandscape ? 0 : 76);
                  final availableWidth = constraints.maxWidth - 24;
                  final boardHeight = _isRotated
                      ? (availableWidth / 2 < availableHeight
                          ? availableWidth / 2
                          : availableHeight)
                      : (availableHeight / 2 < availableWidth
                              ? availableHeight / 2
                              : availableWidth) *
                          2;
                  final boardWidth =
                      _isRotated ? boardHeight * 2 : boardHeight / 2;
                  final size = Size(boardWidth, boardHeight);
                  return Column(
                    children: [
                      if (!isAndroidLandscape)
                        SizedBox(
                          height: 76,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SegmentedButton<_Tool>(
                                segments: const [
                                  ButtonSegment(
                                    value: _Tool.point,
                                    icon: Icon(Icons.circle),
                                    tooltip: 'Punkte platzieren',
                                  ),
                                  ButtonSegment(
                                    value: _Tool.line,
                                    icon: Icon(Icons.gesture),
                                    tooltip: 'Linien zeichnen',
                                  ),
                                ],
                                selected: <_Tool>{_tool},
                                onSelectionChanged: (selected) =>
                                    setState(() => _tool = selected.first),
                              ),
                              const SizedBox(width: 12),
                              for (final color in _colors)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: IconButton(
                                    tooltip: 'Farbe auswählen',
                                    onPressed: () =>
                                        setState(() => _selectedColor = color),
                                    icon: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedColor == color
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child:
                                          const SizedBox(width: 20, height: 20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Center(
                          child: Semantics(
                            label: 'Volleyballfeld',
                            child: GestureDetector(
                              key: const ValueKey('tactics-board'),
                              onTapUp: (details) => _handleTap(details, size),
                              onPanStart: (details) =>
                                  _startDrag(details, size),
                              onPanUpdate: (details) =>
                                  _updateDrag(details, size),
                              onPanEnd: _finishDrag,
                              child: CustomPaint(
                                size: size,
                                painter: _VolleyballCourtPainter(
                                  points: _points,
                                  lines: _lines,
                                  activeLine: _activeLine,
                                  activeColor: _selectedColor,
                                  selection: _selection,
                                  isRotated: _isRotated,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _VolleyballCourtPainter extends CustomPainter {
  const _VolleyballCourtPainter({
    required this.points,
    required this.lines,
    required this.activeLine,
    required this.activeColor,
    required this.selection,
    required this.isRotated,
  });

  final List<_BoardPoint> points;
  final List<_BoardLine> lines;
  final List<Offset>? activeLine;
  final Color activeColor;
  final _BoardSelection? selection;
  final bool isRotated;

  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
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
        isSelected:
            selection?.kind == _SelectionKind.line && selection?.index == index,
      );
    }
    if (activeLine != null) {
      _drawLine(canvas, size, _rotatePoints(activeLine!), activeColor);
    }
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
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
          17,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      canvas.drawCircle(position, 12, Paint()..color = point.color);
      canvas.drawCircle(
        position,
        12,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color, {
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
