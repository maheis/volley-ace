import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'scoreboard_repository.dart';
import 'scoreboard_state.dart';

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key, required this.database});

  final Database database;

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreSnapshot {
  const _ScoreSnapshot({
    required this.leftPoints,
    required this.rightPoints,
    required this.leftSets,
    required this.rightSets,
    required this.leftTimeouts,
    required this.rightTimeouts,
    required this.leftColor,
    required this.rightColor,
    required this.completedSets,
    required this.stopwatchElapsed,
    required this.stopwatchRunning,
    required this.stopwatchStartedAt,
    required this.timeoutSide,
    required this.timeoutStartedAt,
  });

  final int leftPoints;
  final int rightPoints;
  final int leftSets;
  final int rightSets;
  final int leftTimeouts;
  final int rightTimeouts;
  final Color leftColor;
  final Color rightColor;
  final List<SetResult> completedSets;
  final Duration stopwatchElapsed;
  final bool stopwatchRunning;
  final DateTime? stopwatchStartedAt;
  final int? timeoutSide;
  final DateTime? timeoutStartedAt;
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  static const Color _blue = Color(0xff1976d2);
  static const Color _red = Color(0xffe53935);

  int _leftPoints = 0;
  int _rightPoints = 0;
  int _leftSets = 0;
  int _rightSets = 0;
  int _leftTimeouts = 2;
  int _rightTimeouts = 2;
  Color _leftColor = _blue;
  Color _rightColor = _red;
  final List<_ScoreSnapshot> _history = <_ScoreSnapshot>[];
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  bool _stopwatchRunning = false;
  Duration _stopwatchElapsed = Duration.zero;
  DateTime? _stopwatchStartedAt;
  int? _timeoutSide;
  DateTime? _timeoutStartedAt;
  List<SetResult> _completedSets = <SetResult>[];
  late final ScoreboardRepository _repository = ScoreboardRepository(
    widget.database,
  );
  bool _isLoaded = false;

  String get _clockText {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Duration get _stopwatchDuration {
    if (_stopwatchRunning && _stopwatchStartedAt != null) {
      return _stopwatchElapsed + _now.difference(_stopwatchStartedAt!);
    }
    return _stopwatchElapsed;
  }

  String get _stopwatchText {
    final total = _stopwatchDuration;
    final mm = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  bool get _timeoutRunning => _timeoutSide != null && _timeoutStartedAt != null;

  Duration get _timeoutDuration {
    if (_timeoutRunning && _timeoutStartedAt != null) {
      final remaining =
          const Duration(seconds: 30) - _now.difference(_timeoutStartedAt!);
      return remaining.isNegative ? Duration.zero : remaining;
    }
    return Duration.zero;
  }

  String get _timeoutText {
    final total = _timeoutDuration;
    final mm = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _syncTimeoutState() {
    if (!_timeoutRunning || _timeoutStartedAt == null) return;
    if (_now.difference(_timeoutStartedAt!) >= const Duration(seconds: 30)) {
      _timeoutSide = null;
      _timeoutStartedAt = null;
    }
  }

  void _toggleStopwatch() {
    setState(() {
      if (_stopwatchRunning) {
        _stopwatchElapsed += _now.difference(_stopwatchStartedAt!);
        _stopwatchRunning = false;
        _stopwatchStartedAt = null;
      } else {
        _stopwatchStartedAt = DateTime.now();
        _stopwatchRunning = true;
      }
    });
    _persist();
  }

  Future<void> _resetStopwatch() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stoppuhr zurücksetzen?'),
        content: const Text('Die Stoppuhr wird auf 00:00 zurückgesetzt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    setState(() {
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
    });
    _persist();
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _syncTimeoutState();
      });
    });
    unawaited(_loadPersistedState());
  }

  Future<void> _loadPersistedState() async {
    final state = await _repository.load();
    if (!mounted) return;
    setState(() {
      _leftPoints = state.leftPoints;
      _rightPoints = state.rightPoints;
      _leftSets = state.leftSets;
      _rightSets = state.rightSets;
      _leftTimeouts = state.leftTimeouts;
      _rightTimeouts = state.rightTimeouts;
      _leftColor = state.leftColor;
      _rightColor = state.rightColor;
      _stopwatchElapsed = state.stopwatchElapsed;
      _stopwatchRunning = state.stopwatchRunning;
      _stopwatchStartedAt = state.stopwatchStartedAt;
      _timeoutSide = state.timeoutSide;
      _timeoutStartedAt = state.timeoutStartedAt;
      _completedSets = state.completedSets;
      _isLoaded = true;
    });
  }

  void _persist() {
    unawaited(
      _repository.save(
        ScoreboardState(
          leftPoints: _leftPoints,
          rightPoints: _rightPoints,
          leftSets: _leftSets,
          rightSets: _rightSets,
          leftTimeouts: _leftTimeouts,
          rightTimeouts: _rightTimeouts,
          leftColor: _leftColor,
          rightColor: _rightColor,
          stopwatchElapsed: _stopwatchElapsed,
          stopwatchRunning: _stopwatchRunning,
          stopwatchStartedAt: _stopwatchStartedAt,
          timeoutSide: _timeoutSide,
          timeoutStartedAt: _timeoutStartedAt,
          completedSets: _completedSets,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  _ScoreSnapshot get _snapshot => _ScoreSnapshot(
        leftPoints: _leftPoints,
        rightPoints: _rightPoints,
        leftSets: _leftSets,
        rightSets: _rightSets,
        leftTimeouts: _leftTimeouts,
        rightTimeouts: _rightTimeouts,
        leftColor: _leftColor,
        rightColor: _rightColor,
        completedSets: List<SetResult>.from(_completedSets),
        stopwatchElapsed: _stopwatchElapsed,
        stopwatchRunning: _stopwatchRunning,
        stopwatchStartedAt: _stopwatchStartedAt,
        timeoutSide: _timeoutSide,
        timeoutStartedAt: _timeoutStartedAt,
      );

  void _addPoint({required bool left}) {
    _history.add(_snapshot);
    setState(() {
      if (left) {
        _leftPoints++;
      } else {
        _rightPoints++;
      }
      _finishSetIfNeeded();
    });
    _persist();
  }

  void _undoPoint({required bool left}) {
    if (_history.isNotEmpty) {
      _restorePrevious();
      return;
    }

    setState(() {
      if (left && _leftPoints > 0) _leftPoints--;
      if (!left && _rightPoints > 0) _rightPoints--;
    });
    _persist();
  }

  void _addSet({required bool left}) async {
    final side = left ? 'blau' : 'rot';
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Satz beenden?'),
        content: Text('Möchtest du den Satz für $side wirklich beenden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Satz beenden'),
          ),
        ],
      ),
    );

    if (shouldFinish != true || !mounted) return;

    _history.add(_snapshot);
    setState(() {
      _completedSets = List<SetResult>.from(_completedSets)
        ..add(
          SetResult(
            leftPoints: _leftPoints,
            rightPoints: _rightPoints,
            winnerColor: left ? _leftColor : _rightColor,
            wonAt: DateTime.now(),
            stopwatchAt: _stopwatchDuration,
          ),
        );
      if (left) {
        _leftSets++;
      } else {
        _rightSets++;
      }
      _leftPoints = 0;
      _rightPoints = 0;
      _resetTimeoutsForNewSet();
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
    });
    _persist();
  }

  void _undoSet() {
    if (_history.isNotEmpty) _restorePrevious();
  }

  void _restorePrevious() {
    final previous = _history.removeLast();
    setState(() {
      _leftPoints = previous.leftPoints;
      _rightPoints = previous.rightPoints;
      _leftSets = previous.leftSets;
      _rightSets = previous.rightSets;
      _leftTimeouts = previous.leftTimeouts;
      _rightTimeouts = previous.rightTimeouts;
      _leftColor = previous.leftColor;
      _rightColor = previous.rightColor;
      _completedSets = previous.completedSets;
      _stopwatchElapsed = previous.stopwatchElapsed;
      _stopwatchRunning = previous.stopwatchRunning;
      _stopwatchStartedAt = previous.stopwatchStartedAt;
      _timeoutSide = previous.timeoutSide;
      _timeoutStartedAt = previous.timeoutStartedAt;
    });
    _persist();
  }

  void _startTimeout({required bool left}) {
    if (_timeoutRunning) return;

    final remaining = left ? _leftTimeouts : _rightTimeouts;
    if (remaining <= 0) return;

    setState(() {
      if (left) {
        _leftTimeouts--;
        _timeoutSide = 0;
      } else {
        _rightTimeouts--;
        _timeoutSide = 1;
      }
      _timeoutStartedAt = _now;
    });
    _persist();
  }

  void _toggleTimeout({required bool left}) {
    final side = left ? 0 : 1;

    if (_timeoutRunning) {
      if (_timeoutSide == side) {
        unawaited(_showActiveTimeoutDialog(left: left));
      }
      return;
    }

    _startTimeout(left: left);
  }

  Future<void> _showActiveTimeoutDialog({required bool left}) async {
    final side = left ? 0 : 1;
    if (!_timeoutRunning || _timeoutSide != side) return;

    final takeBackTimeout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auszeit beenden?'),
        content: const Text(
          'Du kannst die laufende Auszeit nur beenden oder sie vollständig zurücknehmen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Beenden'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zurücknehmen'),
          ),
        ],
      ),
    );

    if (!mounted || takeBackTimeout == null) return;

    setState(() {
      if (takeBackTimeout) {
        if (left) {
          _leftTimeouts = math.min(2, _leftTimeouts + 1);
        } else {
          _rightTimeouts = math.min(2, _rightTimeouts + 1);
        }
      }
      _timeoutSide = null;
      _timeoutStartedAt = null;
    });
    _persist();
  }

  void _resetTimeoutsForNewSet() {
    _leftTimeouts = 2;
    _rightTimeouts = 2;
    _timeoutSide = null;
    _timeoutStartedAt = null;
  }

  void _finishSetIfNeeded() {
    final leftWon = _leftPoints >= 25 && _leftPoints - _rightPoints >= 2;
    final rightWon = _rightPoints >= 25 && _rightPoints - _leftPoints >= 2;

    if (leftWon) {
      _completedSets = List<SetResult>.from(_completedSets)
        ..add(
          SetResult(
            leftPoints: _leftPoints,
            rightPoints: _rightPoints,
            winnerColor: _leftColor,
            wonAt: DateTime.now(),
            stopwatchAt: _stopwatchDuration,
          ),
        );
      _leftSets++;
      _leftPoints = 0;
      _rightPoints = 0;
      _resetTimeoutsForNewSet();
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
    } else if (rightWon) {
      _completedSets = List<SetResult>.from(_completedSets)
        ..add(
          SetResult(
            leftPoints: _leftPoints,
            rightPoints: _rightPoints,
            winnerColor: _rightColor,
            wonAt: DateTime.now(),
            stopwatchAt: _stopwatchDuration,
          ),
        );
      _rightSets++;
      _leftPoints = 0;
      _rightPoints = 0;
      _resetTimeoutsForNewSet();
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
    }
  }

  void _swapSides() {
    setState(() {
      final points = _leftPoints;
      final sets = _leftSets;
      final color = _leftColor;
      _leftPoints = _rightPoints;
      _rightPoints = points;
      _leftSets = _rightSets;
      _rightSets = sets;
      _leftColor = _rightColor;
      _rightColor = color;
      _history.clear();
    });
    _persist();
  }

  Future<void> _reset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Punktetafel zurücksetzen?'),
        content: const Text(
          'Punkte, Sätze und die Stoppuhr werden auf den Anfangszustand zurückgesetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    setState(() {
      _leftPoints = 0;
      _rightPoints = 0;
      _leftSets = 0;
      _rightSets = 0;
      _resetTimeoutsForNewSet();
      _leftColor = _blue;
      _rightColor = _red;
      _history.clear();
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
      _timeoutSide = null;
      _timeoutStartedAt = null;
      _completedSets = <SetResult>[];
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
              title: const Text('Punktetafel'),
              actions: [
                IconButton(
                  tooltip: 'Reset',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
      body: SafeArea(
        child: !_isLoaded
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 650;
                  const padding = 8.0;
                  final availableWidth = math
                      .max(
                        0.0,
                        math.min(1100, constraints.maxWidth - padding * 2),
                      )
                      .toDouble();
                  final boardRatio = isWide ? 2.2 : 0.92;
                  var boardWidth = availableWidth;
                  var boardHeight = boardWidth / boardRatio;

                  if (isWide && constraints.hasBoundedHeight) {
                    final availableHeight = math
                        .max(
                          0.0,
                          constraints.maxHeight - padding * 2,
                        )
                        .toDouble();
                    if (boardHeight > availableHeight) {
                      boardHeight = availableHeight;
                      boardWidth = boardHeight * boardRatio;
                    }
                  }

                  return Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(padding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: boardWidth,
                            height: boardHeight,
                            child: _buildBoard(context),
                          ),
                          if (_completedSets.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _SetHistoryTable(sets: _completedSets),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final scale = math
            .min(
              constraints.maxWidth / 1100,
              constraints.maxHeight / 500,
            )
            .clamp(0.35, 1.0);
        final gap = (isLandscape ? 6 : 10) * scale;
        final timeoutTileHeight = 74 * scale * (isLandscape ? 1.3 : 1.0);

        Widget buildCenterPanel() {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: gap * 0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Uhrzeit $_clockText',
                        child: Text(
                          _clockText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: (56 * scale).clamp(24, 84),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap * 0.8),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.center,
                    child: _SetWins(
                      leftSets: _leftSets,
                      rightSets: _rightSets,
                      leftColor: _leftColor,
                      rightColor: _rightColor,
                      tileWidth: 120 * scale,
                      tileHeight: 120 * scale,
                      fontSize: 150 * scale,
                      gap: gap * 0.8,
                      borderRadius: 12 * scale,
                      onLeftSwipeDown: () => _addSet(left: true),
                      onRightSwipeDown: () => _addSet(left: false),
                      onSwipeUp: _undoSet,
                      onHorizontalSwipe: _swapSides,
                    ),
                  ),
                ),
                SizedBox(height: gap * 0.8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GestureDetector(
                    onTap: _toggleStopwatch,
                    onLongPress: _resetStopwatch,
                    child: Semantics(
                      label:
                          'Stoppuhr $_stopwatchText, ${_stopwatchRunning ? 'läuft' : 'gestoppt'}. Tippen zum ${_stopwatchRunning ? 'stoppen' : 'starten'}, lange drücken zum Zurücksetzen.',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _stopwatchRunning
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                            size: (56 * scale).clamp(24, 74),
                          ),
                          SizedBox(width: gap * 0.5),
                          Text(
                            _stopwatchText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: (56 * scale).clamp(24, 74),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: gap * 0.8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: gap * 0.8,
                  runSpacing: gap * 0.8,
                  children: [
                    _TimeoutButton(
                      key: const ValueKey('blue-timeout-button'),
                      teamKeyPrefix: 'blue',
                      color: _leftColor,
                      remaining: _leftTimeouts,
                      active: _timeoutRunning && _timeoutSide == 0,
                      countdown: _timeoutText,
                      tileWidth: 110 * scale,
                      tileHeight: timeoutTileHeight,
                      fontSize: 44 * scale,
                      borderRadius: 12 * scale,
                      onPressed: _timeoutRunning && _timeoutSide == 0
                          ? () => _showActiveTimeoutDialog(left: true)
                          : (_leftTimeouts > 0
                              ? () => _toggleTimeout(left: true)
                              : null),
                      onLongPress: _timeoutRunning && _timeoutSide == 0
                          ? () => _showActiveTimeoutDialog(left: true)
                          : null,
                    ),
                    _TimeoutButton(
                      key: const ValueKey('red-timeout-button'),
                      teamKeyPrefix: 'red',
                      color: _rightColor,
                      remaining: _rightTimeouts,
                      active: _timeoutRunning && _timeoutSide == 1,
                      countdown: _timeoutText,
                      tileWidth: 110 * scale,
                      tileHeight: timeoutTileHeight,
                      fontSize: 44 * scale,
                      borderRadius: 12 * scale,
                      onPressed: _timeoutRunning && _timeoutSide == 1
                          ? () => _showActiveTimeoutDialog(left: false)
                          : (_rightTimeouts > 0
                              ? () => _toggleTimeout(left: false)
                              : null),
                      onLongPress: _timeoutRunning && _timeoutSide == 1
                          ? () => _showActiveTimeoutDialog(left: false)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        if (isLandscape) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: _ScorePanel(
                        score: _leftPoints,
                        color: _leftColor,
                        label: 'blau',
                        fontSize: 300 * scale,
                        borderRadius: 12 * scale,
                        onSwipeDown: () => _addPoint(left: true),
                        onSwipeUp: () => _undoPoint(left: true),
                      ),
                    ),
                    SizedBox(width: gap * 0.2),
                    Expanded(
                      flex: 10,
                      child: buildCenterPanel(),
                    ),
                    SizedBox(width: gap * 0.2),
                    Expanded(
                      flex: 11,
                      child: _ScorePanel(
                        score: _rightPoints,
                        color: _rightColor,
                        label: 'rot',
                        fontSize: 300 * scale,
                        borderRadius: 12 * scale,
                        onSwipeDown: () => _addPoint(left: false),
                        onSwipeUp: () => _undoPoint(left: false),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    flex: 11,
                    child: _ScorePanel(
                      score: _leftPoints,
                      color: _leftColor,
                      label: 'blau',
                      fontSize: 300 * scale,
                      borderRadius: 12 * scale,
                      onSwipeDown: () => _addPoint(left: true),
                      onSwipeUp: () => _undoPoint(left: true),
                    ),
                  ),
                  SizedBox(height: gap * 0.2),
                  Expanded(
                    flex: 10,
                    child: buildCenterPanel(),
                  ),
                  SizedBox(height: gap * 0.2),
                  Expanded(
                    flex: 11,
                    child: _ScorePanel(
                      score: _rightPoints,
                      color: _rightColor,
                      label: 'rot',
                      fontSize: 300 * scale,
                      borderRadius: 12 * scale,
                      onSwipeDown: () => _addPoint(left: false),
                      onSwipeUp: () => _undoPoint(left: false),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap),
          ],
        );
      },
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.score,
    required this.color,
    required this.label,
    required this.fontSize,
    required this.borderRadius,
    required this.onSwipeDown,
    required this.onSwipeUp,
  });

  final int score;
  final Color color;
  final String label;
  final double fontSize;
  final double borderRadius;
  final VoidCallback onSwipeDown;
  final VoidCallback onSwipeUp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize =
            math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanEnd: (details) {
              final velocity = details.velocity.pixelsPerSecond;
              if (velocity.dy > 180) {
                onSwipeDown();
              } else if (velocity.dy < -180) {
                onSwipeUp();
              }
            },
            child: Semantics(
              label: '$label: $score Punkte',
              child: SizedBox(
                width: squareSize,
                height: squareSize,
                child: Container(
                  key: ValueKey('$label-score-panel'),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$score',
                        key: ValueKey('$score-$color'),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetWins extends StatelessWidget {
  const _SetWins({
    required this.leftSets,
    required this.rightSets,
    required this.leftColor,
    required this.rightColor,
    required this.tileWidth,
    required this.tileHeight,
    required this.fontSize,
    required this.gap,
    required this.borderRadius,
    required this.onLeftSwipeDown,
    required this.onRightSwipeDown,
    required this.onSwipeUp,
    required this.onHorizontalSwipe,
  });

  final int leftSets;
  final int rightSets;
  final Color leftColor;
  final Color rightColor;
  final double tileWidth;
  final double tileHeight;
  final double fontSize;
  final double gap;
  final double borderRadius;
  final VoidCallback onLeftSwipeDown;
  final VoidCallback onRightSwipeDown;
  final VoidCallback onSwipeUp;
  final VoidCallback onHorizontalSwipe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('set-score-area'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) => onHorizontalSwipe(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SetNumber(
            value: leftSets,
            color: leftColor,
            label: 'blau',
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            fontSize: fontSize,
            borderRadius: borderRadius,
            onSwipeDown: onLeftSwipeDown,
            onSwipeUp: onSwipeUp,
          ),
          SizedBox(width: gap),
          _SetNumber(
            value: rightSets,
            color: rightColor,
            label: 'rot',
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            fontSize: fontSize,
            borderRadius: borderRadius,
            onSwipeDown: onRightSwipeDown,
            onSwipeUp: onSwipeUp,
          ),
        ],
      ),
    );
  }
}

class _SetNumber extends StatelessWidget {
  const _SetNumber({
    required this.value,
    required this.color,
    required this.label,
    required this.tileWidth,
    required this.tileHeight,
    required this.fontSize,
    required this.borderRadius,
    required this.onSwipeDown,
    required this.onSwipeUp,
  });

  final int value;
  final Color color;
  final String label;
  final double tileWidth;
  final double tileHeight;
  final double fontSize;
  final double borderRadius;
  final VoidCallback onSwipeDown;
  final VoidCallback onSwipeUp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('$label-set-panel'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (velocity.dy > 180) {
          onSwipeDown();
        } else if (velocity.dy < -180) {
          onSwipeUp();
        }
      },
      child: Semantics(
        label: '$label: $value gewonnene Sätze',
        child: Container(
          width: tileWidth,
          height: tileHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                key: ValueKey(value),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetHistoryTable extends StatelessWidget {
  const _SetHistoryTable({required this.sets});

  final List<SetResult> sets;

  String _formatTimestamp(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  String _formatDuration(Duration value) {
    final mm = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Satz', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Datum/Uhrzeit', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Ergebnis', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Stoppuhr', style: headerStyle),
                ),
              ],
            ),
            for (var i = 0; i < sets.length; i++)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: sets[i].winnerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      _formatTimestamp(sets[i].wonAt),
                      style: TextStyle(
                        color: sets[i].winnerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      '${sets[i].leftPoints}:${sets[i].rightPoints}',
                      style: TextStyle(
                        color: sets[i].winnerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      _formatDuration(sets[i].stopwatchAt),
                      style: TextStyle(
                        color: sets[i].winnerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeoutButton extends StatelessWidget {
  const _TimeoutButton({
    super.key,
    required this.teamKeyPrefix,
    required this.color,
    required this.remaining,
    required this.active,
    required this.countdown,
    required this.tileWidth,
    required this.tileHeight,
    required this.fontSize,
    required this.borderRadius,
    required this.onPressed,
    this.onLongPress,
  });

  final String teamKeyPrefix;
  final Color color;
  final int remaining;
  final bool active;
  final String countdown;
  final double tileWidth;
  final double tileHeight;
  final double fontSize;
  final double borderRadius;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  String get _usedText => '${2 - remaining}';

  @override
  Widget build(BuildContext context) {
    final accent = active ? Colors.white : Colors.white70;
    final enabled = active || remaining > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Semantics(
        label: active
            ? 'Auszeit läuft, noch $countdown'
            : 'Auszeiten genommen: $_usedText von 2',
        child: Container(
          width: tileWidth,
          height: tileHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color:
                  active ? Colors.white.withOpacity(0.8) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  top: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      if (active) ...[
                        const SizedBox(width: 4),
                        Text(
                          countdown,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _usedText,
                      key: ValueKey('$teamKeyPrefix-timeout-count'),
                      style: TextStyle(
                        color: accent,
                        fontSize: fontSize * 0.76,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
