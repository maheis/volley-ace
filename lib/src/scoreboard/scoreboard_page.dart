import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

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
  });

  final int leftPoints;
  final int rightPoints;
  final int leftSets;
  final int rightSets;
  final Color leftColor;
  final Color rightColor;
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

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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
      if (left) {
        _leftSets++;
      } else {
        _rightSets++;
      }
      _leftPoints = 0;
      _rightPoints = 0;
    });
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
    });
  }

  void _finishSetIfNeeded() {
    final leftWon = _leftPoints >= 25 && _leftPoints - _rightPoints >= 2;
    final rightWon = _rightPoints >= 25 && _rightPoints - _leftPoints >= 2;

    if (leftWon) {
      _leftSets++;
      _leftPoints = 0;
      _rightPoints = 0;
    } else if (rightWon) {
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
  }

  void _reset() {
    setState(() {
      _leftPoints = 0;
      _rightPoints = 0;
      _leftSets = 0;
      _rightSets = 0;
      _leftColor = _blue;
      _rightColor = _red;
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 650;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? _buildWideBoard(context)
                      : _buildCompactBoard(context),
                ),
              ),
            );
          },
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
                  onSwipeDown: () => _addPoint(left: true),
                  onSwipeUp: () => _undoPoint(left: true),
                ),
              ),
              const SizedBox(width: 10),
              _SetWins(
                leftSets: _leftSets,
                rightSets: _rightSets,
                leftColor: _leftColor,
                rightColor: _rightColor,
                onLeftSwipeDown: () => _addSet(left: true),
                onRightSwipeDown: () => _addSet(left: false),
                onSwipeUp: _undoSet,
                onHorizontalSwipe: _swapSides,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScorePanel(
                  score: _rightPoints,
                  color: _rightColor,
                  label: 'rot',
                  onSwipeDown: () => _addPoint(left: false),
                  onSwipeUp: () => _undoPoint(left: false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10)
      ],
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.score,
    required this.color,
    required this.label,
    required this.onSwipeDown,
    required this.onSwipeUp,
  });

  final int score;
  final Color color;
  final String label;
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
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              '$score',
              key: ValueKey('$score-$color'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 300,
                fontWeight: FontWeight.w700,
                height: 1,
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
    required this.onLeftSwipeDown,
    required this.onRightSwipeDown,
    required this.onSwipeUp,
    required this.onHorizontalSwipe,
  });

  final int leftSets;
  final int rightSets;
  final Color leftColor;
  final Color rightColor;
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
            onSwipeDown: onLeftSwipeDown,
            onSwipeUp: onSwipeUp,
          ),
          const SizedBox(width: 10),
          _SetNumber(
            value: rightSets,
            color: rightColor,
            label: 'rot',
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
    required this.onSwipeDown,
    required this.onSwipeUp,
  });

  final int value;
  final Color color;
  final String label;
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
          width: 110,
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 150,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
