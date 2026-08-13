import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    required this.leftColor,
    required this.rightColor,
    required this.completedSets,
  });

  final int leftPoints;
  final int rightPoints;
  final int leftSets;
  final int rightSets;
  final Color leftColor;
  final Color rightColor;
  final List<SetResult> completedSets;
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  static const Color _blue = Color(0xff1976d2);
  static const Color _red = Color(0xffe53935);

  int _leftPoints = 0;
  int _rightPoints = 0;
  int _leftSets = 0;
  int _rightSets = 0;
  Color _leftColor = _blue;
  Color _rightColor = _red;
  final List<_ScoreSnapshot> _history = <_ScoreSnapshot>[];
  bool _isFullscreen = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  bool _stopwatchRunning = false;
  Duration _stopwatchElapsed = Duration.zero;
  DateTime? _stopwatchStartedAt;
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

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        details.pointerCount < 2) {
      return;
    }

    if (!_isFullscreen && details.scale > 1.12) {
      _setFullscreen(true);
    } else if (_isFullscreen && details.scale < 0.88) {
      _setFullscreen(false);
    }
  }

  void _setFullscreen(bool enabled) {
    if (_isFullscreen == enabled || !mounted) return;
    setState(() => _isFullscreen = enabled);
    SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
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
      _leftColor = state.leftColor;
      _rightColor = state.rightColor;
      _stopwatchElapsed = state.stopwatchElapsed;
      _stopwatchRunning = state.stopwatchRunning;
      _stopwatchStartedAt = state.stopwatchStartedAt;
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
          leftColor: _leftColor,
          rightColor: _rightColor,
          stopwatchElapsed: _stopwatchElapsed,
          stopwatchRunning: _stopwatchRunning,
          stopwatchStartedAt: _stopwatchStartedAt,
          completedSets: _completedSets,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WakelockPlus.disable();
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  _ScoreSnapshot get _snapshot => _ScoreSnapshot(
        leftPoints: _leftPoints,
        rightPoints: _rightPoints,
        leftSets: _leftSets,
        rightSets: _rightSets,
        leftColor: _leftColor,
        rightColor: _rightColor,
        completedSets: List<SetResult>.from(_completedSets),
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
      _leftColor = previous.leftColor;
      _rightColor = previous.rightColor;
      _completedSets = previous.completedSets;
    });
    _persist();
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
      _leftColor = _blue;
      _rightColor = _red;
      _history.clear();
      _stopwatchRunning = false;
      _stopwatchElapsed = Duration.zero;
      _stopwatchStartedAt = null;
      _completedSets = <SetResult>[];
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleUpdate: _handleScaleUpdate,
      child: Scaffold(
        appBar: _isFullscreen
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
          top: !_isFullscreen,
          bottom: !_isFullscreen,
          child: !_isLoaded
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 650;
                    return Center(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.all(_isFullscreen ? 4 : 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isWide
                                  ? _buildWideBoard(context)
                                  : _buildCompactBoard(context),
                              if (_completedSets.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _SetHistoryTable(sets: _completedSets),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildWideBoard(BuildContext context) {
    return AspectRatio(aspectRatio: 2.2, child: _buildBoard(context));
  }

  Widget _buildCompactBoard(BuildContext context) {
    return AspectRatio(aspectRatio: 0.92, child: _buildBoard(context));
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(
              constraints.maxWidth / 1100,
              constraints.maxHeight / 500,
            )
            .clamp(0.35, 1.0);
        final gap = 10 * scale;

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
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
                  SizedBox(width: gap),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      SizedBox(height: gap),
                      _SetWins(
                        leftSets: _leftSets,
                        rightSets: _rightSets,
                        leftColor: _leftColor,
                        rightColor: _rightColor,
                        tileWidth: 110 * scale,
                        tileHeight: 220 * scale,
                        fontSize: 150 * scale,
                        gap: gap,
                        borderRadius: 12 * scale,
                        onLeftSwipeDown: () => _addSet(left: true),
                        onRightSwipeDown: () => _addSet(left: false),
                        onSwipeUp: _undoSet,
                        onHorizontalSwipe: _swapSides,
                      ),
                      SizedBox(height: gap),
                      GestureDetector(
                        onTap: _toggleStopwatch,
                        child: Semantics(
                          label:
                              'Stoppuhr $_stopwatchText, ${_stopwatchRunning ? 'läuft' : 'gestoppt'}. Tippen zum ${_stopwatchRunning ? 'stoppen' : 'starten'}.',
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
                              SizedBox(width: gap * 0.6),
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
                    ],
                  ),
                  SizedBox(width: gap),
                  Expanded(
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
    return GestureDetector(
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
