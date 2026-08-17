import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import 'arcade_model.dart';

class ArcadePage extends StatefulWidget {
  const ArcadePage({super.key, required this.database});

  final Database database;

  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage>
    with SingleTickerProviderStateMixin {
  late final ArcadeModel model;
  late final Ticker ticker;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    model = ArcadeModel(widget.database);
    focusNode = FocusNode(debugLabel: 'ArcadePage');
    ticker = createTicker(_tick)..start();
    unawaited(model.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    model.tick(elapsed);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final handled = model.handleKeyEvent(event);
    if (!handled &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        model.scene == ArcadeScene.start) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: const Color(0xFF10362E),
            appBar: AppBar(
              title: const Text('Volley-Arcade'),
              actions: [
                IconButton(
                  tooltip: model.audioMuted
                      ? 'Sound einschalten'
                      : 'Sound stummschalten',
                  onPressed: model.toggleAudio,
                  icon: Icon(
                      model.audioMuted ? Icons.volume_off : Icons.volume_up),
                ),
                IconButton(
                  tooltip: 'Zurücksetzen',
                  onPressed: model.resetToMenu,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                model.setViewport(
                    Size(constraints.maxWidth, constraints.maxHeight));

                return DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF123A31), Color(0xFF0B221D)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _StatCard(
                                label: 'Spieler',
                                value: '${model.playerPoints}'),
                            _StatCard(
                                label: 'CPU', value: '${model.cpuPoints}'),
                            _StatCard(
                                label: 'Sätze',
                                value:
                                    '${model.playerSets} : ${model.cpuSets}'),
                            _StatCard(
                                label: 'Highscore',
                                value: '${model.highscoreSets}'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Leicht'),
                              selected: model.startDifficulty ==
                                  ArcadeDifficulty.easy,
                              onSelected: (_) =>
                                  model.setDifficulty(ArcadeDifficulty.easy),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Normal'),
                              selected: model.startDifficulty ==
                                  ArcadeDifficulty.normal,
                              onSelected: (_) =>
                                  model.setDifficulty(ArcadeDifficulty.normal),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Schwer'),
                              selected: model.startDifficulty ==
                                  ArcadeDifficulty.hard,
                              onSelected: (_) =>
                                  model.setDifficulty(ArcadeDifficulty.hard),
                            ),
                            const Spacer(),
                            Text(model.status,
                                style: theme.textTheme.labelLarge),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            key: const ValueKey('arcade-court-gesture'),
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (_) => model.onHitButton(),
                            onPanStart: (details) => _movePlayerFromTouch(
                              details.localPosition.dx,
                              constraints.maxWidth - 32,
                            ),
                            onPanUpdate: (details) => _movePlayerFromTouch(
                              details.localPosition.dx,
                              constraints.maxWidth - 32,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B241F),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF88D6FF)
                                      .withValues(alpha: 0.35),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        painter:
                                            _ArcadeCourtPainter(model: model),
                                        size: Size.infinite,
                                      ),
                                      _buildOverlay(context),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: model.scene == ArcadeScene.playing
                                    ? model.pauseOrResume
                                    : model.startGame,
                                icon: Icon(model.scene == ArcadeScene.playing
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                label: Text(model.scene == ArcadeScene.playing
                                    ? 'Pause'
                                    : 'Start'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: model.onHitButton,
                                icon: const Icon(Icons.sports_volleyball),
                                label: const Text('Schlag'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);

    if (model.scene == ArcadeScene.start) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Volley-Arcade',
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                          'Der SDL2-Kern ist als Dart-Modell portiert: Menü, Start/Spiel/Pause, Aufschlag, CPU, Highscore und Name-Entry.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: model.startGame,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Spiel starten'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: model.toggleTwoPlayer,
                          icon: Icon(model.startTwoPlayer
                              ? Icons.people
                              : Icons.person),
                          label: Text(model.startTwoPlayer
                              ? '2-Spieler-Modus'
                              : 'Singleplayer'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: model.toggleAudio,
                          icon: Icon(model.audioMuted
                              ? Icons.volume_off
                              : Icons.volume_up),
                          label:
                              Text(model.audioMuted ? 'Sound aus' : 'Sound an'),
                        ),
                        const SizedBox(height: 16),
                        if (!model.startTwoPlayer) ...[
                          Text('Highscores',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          for (var i = 0; i < model.highscores.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${i + 1}. ${model.highscores[i].name}  S${model.highscores[i].setsFor}:${model.highscores[i].setsAgainst}  P${model.highscores[i].pointsFor}:${model.highscores[i].pointsAgainst}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (model.scene == ArcadeScene.paused) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pause', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('P oder Enter zum Fortsetzen'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: model.pauseOrResume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Weiter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (model.scene == ArcadeScene.nameEntry) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Neuer Highscore',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                          'Sets ${model.nameSetsFor}:${model.nameSetsAgainst}  Punkte ${model.namePointsFor}:${model.namePointsAgainst}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text('Name: ${model.nameInput}_',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: model.saveNameEntry,
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: model.cancelNameEntry,
                        icon: const Icon(Icons.close),
                        label: const Text('Abbrechen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _movePlayerFromTouch(double localX, double cardWidth) {
    if (cardWidth <= 0) return;
    final worldX = (localX / cardWidth) * windowWidth;
    model.movePlayerTo(worldX);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _ArcadeCourtPainter extends CustomPainter {
  _ArcadeCourtPainter({required this.model});

  final ArcadeModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final paintSand = Paint()..color = const Color(0xFFD8B46A);
    final paintNet = Paint()..color = const Color(0xFFE0E0E0);
    final paintLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final paintBall = Paint()..color = const Color(0xFFFFC56D);
    final paintPlayer = Paint()..color = const Color(0xFF88D6FF);
    final paintCpu = Paint()..color = const Color(0xFFFF7A7A);
    final handColor = Paint()..color = const Color(0xFFFFBC6E);

    final court = Rect.fromLTWH(20, 20, size.width - 40, size.height - 40);
    canvas.drawRRect(
        RRect.fromRectAndRadius(court, const Radius.circular(18)), paintSand);
    canvas.drawRRect(
        RRect.fromRectAndRadius(court, const Radius.circular(18)), paintLine);

    final netX = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(netX - 5, court.top + 20, 10, court.height * 0.48 + 12),
      paintNet,
    );
    canvas.drawLine(Offset(court.left, size.height * 0.5),
        Offset(court.right, size.height * 0.5), paintLine);

    final playerNearNet =
        (netX - (model.player.x + playerW / 2)) <= blockJumpNetDistance;
    final cpuNearNet =
        ((model.cpu.x + playerW / 2) - netX) <= blockJumpNetDistance;
    final playerPose = model.computeArmPose(model.player.x, model.player.y,
        true, !model.player.onGround, playerNearNet);
    final cpuPose = model.computeArmPose(
        model.cpu.x, model.cpu.y, false, !model.cpu.onGround, cpuNearNet);

    _drawActor(canvas, model.player, paintPlayer, handColor, true, playerPose);
    _drawActor(canvas, model.cpu, paintCpu, handColor, false, cpuPose);

    canvas.drawCircle(Offset(model.ball.position.x, model.ball.position.y),
        ballRadius, paintBall);
  }

  void _drawActor(Canvas canvas, ArcadePlayer actor, Paint bodyPaint,
      Paint handPaint, bool towardRight, ArcadeArmPose pose) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(actor.x, actor.y, playerW, playerH),
        const Radius.circular(6));
    canvas.drawRRect(body, bodyPaint);
    canvas.drawCircle(
        Offset(actor.x + playerW / 2, actor.y), headRadius, handPaint);

    final armPaint = Paint()
      ..color = bodyPaint.color
      ..strokeWidth = armThickness
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(pose.shoulderX, pose.shoulderY),
        Offset(pose.handX, pose.handY), armPaint);
    canvas.drawCircle(Offset(pose.handX, pose.handY), handOvalRx, handPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcadeCourtPainter oldDelegate) => true;
}
