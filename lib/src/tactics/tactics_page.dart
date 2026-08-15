import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

enum _Tool { point, line }

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
  Color _selectedColor = Colors.red;
  _Tool _tool = _Tool.point;
  List<Offset>? _activeLine;
  int? _movingPointIndex;
  int? _movingLineIndex;
  Offset? _lastDragPosition;
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
      _isLoaded = true;
    });
  }

  Future<void> _persist() => _store.record(_recordKey).put(
        widget.database,
        <String, dynamic>{
          'points': _points.map((point) => point.toJson()).toList(),
          'lines': _lines.map((line) => line.toJson()).toList(),
        },
      );

  Offset _relativePosition(Offset position, Size size) => Offset(
        (position.dx / size.width).clamp(0.0, 1.0),
        (position.dy / size.height).clamp(0.0, 1.0),
      );

  void _handleTap(TapUpDetails details, Size size) {
    if (_tool != _Tool.point) return;
    final position = _relativePosition(details.localPosition, size);
    if (_findPointAt(position, size) != null) return;
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
        _lastDragPosition = position;
      });
      return;
    }
    final lineIndex = _findLineAt(position, size);
    setState(() {
      _lastDragPosition = position;
      if (lineIndex != null) {
        _movingLineIndex = lineIndex;
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

  void _clear() {
    setState(() {
      _points.clear();
      _lines.clear();
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taktiktafel'),
        actions: [
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
        ],
      ),
      body: !_isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardHeight = (constraints.maxHeight - 94)
                      .clamp(260.0, 760.0)
                      .toDouble();
                  final boardWidth = (boardHeight * 0.56)
                      .clamp(220.0, constraints.maxWidth - 24)
                      .toDouble();
                  final size = Size(boardWidth, boardHeight);
                  return Column(
                    children: [
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
  });

  final List<_BoardPoint> points;
  final List<_BoardLine> lines;
  final List<Offset>? activeLine;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRect(court, Paint()..color = const Color(0xFFD89A58));
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRect(court, linePaint);
    final netY = court.center.dy;
    canvas.drawLine(
        Offset(court.left, netY), Offset(court.right, netY), linePaint);
    final threeMeter = court.height / 6;
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

    for (final line in lines) {
      _drawLine(canvas, size, line.points, line.color);
    }
    if (activeLine != null) _drawLine(canvas, size, activeLine!, activeColor);
    for (final point in points) {
      final position = Offset(
          point.position.dx * size.width, point.position.dy * size.height);
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

  void _drawLine(Canvas canvas, Size size, List<Offset> points, Color color) {
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
  }

  @override
  bool shouldRepaint(covariant _VolleyballCourtPainter oldDelegate) => true;
}
