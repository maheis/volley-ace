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
  List<ScoreboardHistoryEntry> _historyEntries = <ScoreboardHistoryEntry>[];
  late final ScoreboardRepository _repository = ScoreboardRepository(
    widget.database,
  );
  bool _isLoaded = false;

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
      _historyEntries = state.historyEntries;
      _isLoaded = true;
    });
  }

  void _recordHistory(String action, {Color? color}) {
    setState(() {
      _historyEntries = List<ScoreboardHistoryEntry>.from(_historyEntries)
        ..add(
          ScoreboardHistoryEntry(
            action: action,
            occurredAt: _now,
            stopwatchAt: _stopwatchDuration,
            color: color,
          ),
        );
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
          historyEntries: _historyEntries,
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
      if (!_stopwatchRunning &&
          _stopwatchElapsed == Duration.zero &&
          _leftPoints + _rightPoints == 1) {
        _stopwatchRunning = true;
        _stopwatchStartedAt = _now;
      }
      _finishSetIfNeeded();
    });
    _recordHistory(
      left ? 'Punkt blau' : 'Punkt rot',
      color: left ? _leftColor : _rightColor,
    );
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
    _recordHistory(
      left ? 'Punkt zurückgenommen blau' : 'Punkt zurückgenommen rot',
      color: left ? _leftColor : _rightColor,
    );
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
    _recordHistory(left ? 'Satz beendet blau' : 'Satz beendet rot',
        color: left ? _leftColor : _rightColor);
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
    _recordHistory(left ? 'Auszeit gestartet blau' : 'Auszeit gestartet rot',
        color: left ? _leftColor : _rightColor);
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
    _recordHistory(
      takeBackTimeout
          ? (left
              ? 'Auszeit zurückgenommen blau'
              : 'Auszeit zurückgenommen rot')
          : (left ? 'Auszeit beendet blau' : 'Auszeit beendet rot'),
      color: left ? _leftColor : _rightColor,
    );
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
      _historyEntries = <ScoreboardHistoryEntry>[];
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
      _timeoutSide = null;
      _timeoutStartedAt = null;
      _completedSets = <SetResult>[];
    });
    _persist();
  }

  void _openHistoryPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _SetHistoryPage(
          entries: List<ScoreboardHistoryEntry>.unmodifiable(_historyEntries),
          sets: List<SetResult>.unmodifiable(_completedSets),
        ),
      ),
    );
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
                  key: const ValueKey('history-appbar-button'),
                  tooltip: 'Punkthistorie',
                  onPressed: _openHistoryPage,
                  icon: const Icon(Icons.history),
                ),
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
                  final isLandscapeViewport =
                      constraints.maxWidth >= constraints.maxHeight;
                  const padding = 8.0;
                  final boardWidth = math.max(
                    0.0,
                    constraints.maxWidth - padding * 2,
                  );
                  final boardHeight = math.max(
                    0.0,
                    constraints.maxHeight - padding * 2,
                  );

                  return Center(
                    child: SingleChildScrollView(
                      physics: isLandscapeViewport
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(padding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: boardWidth,
                            height: boardHeight,
                            child: _buildBoard(context),
                          ),
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
        final isLandscape = constraints.maxWidth >= constraints.maxHeight;
        final scale = math
            .min(
              constraints.maxWidth / 1100,
              constraints.maxHeight / 500,
            )
            .clamp(0.35, 1.0);
        final cardScale = isLandscape ? scale * 1.25 : scale;

        Widget buildCenterPanel() {
          return LayoutBuilder(
            builder: (context, centerConstraints) {
              final squareSide = math.min(
                centerConstraints.maxWidth,
                centerConstraints.maxHeight,
              );
              final partSide = squareSide * 5 / 13;

              return Align(
                alignment:
                    isLandscape ? const Alignment(-0.95, 0) : Alignment.center,
                child: SizedBox.square(
                  dimension: squareSide,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (isLandscape)
                        Expanded(
                          flex: 1,
                          child: const SizedBox.shrink(),
                        ),
                      Expanded(
                        flex: 5,
                        child: Align(
                          alignment: Alignment.center,
                          child: _SetWins(
                            leftSets: _leftSets,
                            rightSets: _rightSets,
                            leftColor: _leftColor,
                            rightColor: _rightColor,
                            tileWidth: partSide,
                            tileHeight: partSide,
                            fontSize: partSide * 1.35,
                            gap: partSide * 0.12,
                            borderRadius: 12,
                            onLeftSwipeDown: () => _addSet(left: true),
                            onRightSwipeDown: () => _addSet(left: false),
                            onSwipeUp: _undoSet,
                            onHorizontalSwipe: _swapSides,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: FittedBox(
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
                                      size: (partSide * 0.92).clamp(20, 74),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _stopwatchText,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            (partSide * 0.92).clamp(20, 74),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: partSide * 0.12,
                            runSpacing: partSide * 0.12,
                            children: [
                              _TimeoutButton(
                                key: const ValueKey('blue-timeout-button'),
                                teamKeyPrefix: 'blue',
                                color: _leftColor,
                                remaining: _leftTimeouts,
                                active: _timeoutRunning && _timeoutSide == 0,
                                countdown: _timeoutText,
                                tileWidth: partSide,
                                tileHeight: partSide,
                                fontSize: partSide * 0.42,
                                borderRadius: 12,
                                onPressed: _timeoutRunning && _timeoutSide == 0
                                    ? () => _showActiveTimeoutDialog(left: true)
                                    : (_leftTimeouts > 0
                                        ? () => _toggleTimeout(left: true)
                                        : null),
                                onLongPress: _timeoutRunning &&
                                        _timeoutSide == 0
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
                                tileWidth: partSide,
                                tileHeight: partSide,
                                fontSize: partSide * 0.42,
                                borderRadius: 12,
                                onPressed: _timeoutRunning && _timeoutSide == 1
                                    ? () =>
                                        _showActiveTimeoutDialog(left: false)
                                    : (_rightTimeouts > 0
                                        ? () => _toggleTimeout(left: false)
                                        : null),
                                onLongPress: _timeoutRunning &&
                                        _timeoutSide == 1
                                    ? () =>
                                        _showActiveTimeoutDialog(left: false)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        if (isLandscape) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _ScorePanel(
                        score: _leftPoints,
                        color: _leftColor,
                        label: 'blau',
                        fontSize: 300 * cardScale,
                        borderRadius: 12 * cardScale,
                        onSwipeDown: () => _addPoint(left: true),
                        onSwipeUp: () => _undoPoint(left: true),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: buildCenterPanel(),
                    ),
                    Expanded(
                      flex: 1,
                      child: _ScorePanel(
                        score: _rightPoints,
                        color: _rightColor,
                        label: 'rot',
                        fontSize: 300 * cardScale,
                        borderRadius: 12 * cardScale,
                        onSwipeDown: () => _addPoint(left: false),
                        onSwipeUp: () => _undoPoint(left: false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _ScorePanel(
                      score: _leftPoints,
                      color: _leftColor,
                      label: 'blau',
                      fontSize: 300 * cardScale,
                      borderRadius: 12 * cardScale,
                      onSwipeDown: () => _addPoint(left: true),
                      onSwipeUp: () => _undoPoint(left: true),
                    ),
                  ),
                  Expanded(
                    child: buildCenterPanel(),
                  ),
                  Expanded(
                    child: _ScorePanel(
                      score: _rightPoints,
                      color: _rightColor,
                      label: 'rot',
                      fontSize: 300 * cardScale,
                      borderRadius: 12 * cardScale,
                      onSwipeDown: () => _addPoint(left: false),
                      onSwipeUp: () => _undoPoint(left: false),
                    ),
                  ),
                ],
              ),
            ),
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
        mainAxisSize: MainAxisSize.min,
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

class _ScoreHistoryTable extends StatelessWidget {
  const _ScoreHistoryTable({required this.entries});

  final List<ScoreboardHistoryEntry> entries;

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
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Zeit', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Stoppuhr', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Aktion', style: headerStyle),
                ),
              ],
            ),
            for (var i = 0; i < entries.length; i++)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      _formatTimestamp(entries[i].occurredAt),
                      style: TextStyle(
                        color: entries[i].color ?? Colors.white,
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
                      _formatDuration(entries[i].stopwatchAt),
                      style: TextStyle(
                        color: entries[i].color ?? Colors.white,
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
                      entries[i].action,
                      style: TextStyle(
                        color: entries[i].color ?? Colors.white,
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

class _SetPointsTable extends StatelessWidget {
  const _SetPointsTable({required this.sets});

  final List<SetResult> sets;

  String _formatTimestamp(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute';
  }

  String _winnerLabel(SetResult set) {
    if (set.winnerColor == ScoreboardState.defaultLeftColor) {
      return 'blau';
    }
    if (set.winnerColor == ScoreboardState.defaultRightColor) {
      return 'rot';
    }
    return 'Team';
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
                  child: Text('Gewinner', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Ergebnis', style: headerStyle),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Uhrzeit', style: headerStyle),
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
                      _winnerLabel(sets[i]),
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
                      _formatTimestamp(sets[i].wonAt),
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

class _SetHistoryPage extends StatelessWidget {
  const _SetHistoryPage({required this.entries, required this.sets});

  final List<ScoreboardHistoryEntry> entries;
  final List<SetResult> sets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punkthistorie')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: entries.isEmpty && sets.isEmpty
              ? const Center(
                  child: Text('Noch keine Verlaufseinträge vorhanden.'),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Verlauf',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ScoreHistoryTable(entries: entries),
                      const SizedBox(height: 16),
                      const Text(
                        'Satzpunkte',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SetPointsTable(sets: sets),
                    ],
                  ),
                ),
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
