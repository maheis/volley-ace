import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

const double windowWidth = 1024.0;
const double windowHeight = 600.0;

const double courtMinX = 0.0;
const double courtMaxX = windowWidth;
const double netX = 512.0;
const double netTopY = 320.0;
const double floorY = 560.0;

const double playerW = 26.0;
const double playerH = 160.0;
const double headRadius = 20.0;
const double handHitRadius = 10.0;
const double armThickness = 12.0;
const double handOvalRx = 12.0;
const double handOvalRy = 8.0;
const double playerSpeed = 300.0;
const double playerBlockTime = 0.16;
const double playerBlockTimeMin = 0.08;
const double playerJumpSpeed = -525.0;
const double playerGravity = 1080.0;
const double playerJumpHoldTime = 0.16;
const double playerJumpHoldGravityMult = 0.46;
const double playerJumpReleaseGravityMult = 1.72;
const double blockJumpNetDistance = 50.0;
const double cpuBlockTime = 0.14;
const double cpuJumpSpeed = -430.0;
const double cpuSpeed = 260.0;
const double cpuHitCooldown = 0.12;

const double ballRadius = 20.0;
const double gravity = 860.0;
const double returnSpeedX = 270.0;
const double returnSpeedY = -520.0;
const int pointsToWinSet = 25;
const int minLeadToWinSet = 2;
const int maxTouchesPerSide = 3;
const double touchMinInterval = 0.5;
const double touchMinRisePx = 30.0;
const double serveChargeMaxTime = 1.2;
const double startBannerFadeTime = 1.2;
const int maxHighscores = 7;
const int highscoreNameLen = 10;

final StoreRef<String, Map<String, Object?>> arcadeStore =
    StoreRef<String, Map<String, Object?>>('arcade');

enum ArcadeScene { start, playing, paused, nameEntry }

enum ArcadeDifficulty { easy, normal, hard }

class ArcadeVec2 {
  const ArcadeVec2(this.x, this.y);

  final double x;
  final double y;

  ArcadeVec2 copyWith({double? x, double? y}) =>
      ArcadeVec2(x ?? this.x, y ?? this.y);
}

class ArcadeBall {
  const ArcadeBall({required this.position, required this.velocity});

  final ArcadeVec2 position;
  final ArcadeVec2 velocity;

  ArcadeBall copyWith({ArcadeVec2? position, ArcadeVec2? velocity}) {
    return ArcadeBall(
        position: position ?? this.position,
        velocity: velocity ?? this.velocity);
  }
}

class ArcadePlayer {
  const ArcadePlayer({
    required this.x,
    required this.y,
    required this.vy,
    required this.jumpHoldTimer,
    required this.onGround,
    required this.isBlocking,
    required this.blockTimer,
  });

  final double x;
  final double y;
  final double vy;
  final double jumpHoldTimer;
  final bool onGround;
  final bool isBlocking;
  final double blockTimer;

  ArcadePlayer copyWith({
    double? x,
    double? y,
    double? vy,
    double? jumpHoldTimer,
    bool? onGround,
    bool? isBlocking,
    double? blockTimer,
  }) {
    return ArcadePlayer(
      x: x ?? this.x,
      y: y ?? this.y,
      vy: vy ?? this.vy,
      jumpHoldTimer: jumpHoldTimer ?? this.jumpHoldTimer,
      onGround: onGround ?? this.onGround,
      isBlocking: isBlocking ?? this.isBlocking,
      blockTimer: blockTimer ?? this.blockTimer,
    );
  }
}

class ArcadeHighscoreEntry {
  ArcadeHighscoreEntry({
    required this.name,
    required this.setsFor,
    required this.setsAgainst,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  final String name;
  final int setsFor;
  final int setsAgainst;
  final int pointsFor;
  final int pointsAgainst;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'setsFor': setsFor,
      'setsAgainst': setsAgainst,
      'pointsFor': pointsFor,
      'pointsAgainst': pointsAgainst,
    };
  }

  factory ArcadeHighscoreEntry.fromMap(Map<String, Object?> map) {
    return ArcadeHighscoreEntry(
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'PLAYER',
      setsFor: _toInt(map['setsFor']),
      setsAgainst: _toInt(map['setsAgainst']),
      pointsFor: _toInt(map['pointsFor']),
      pointsAgainst: _toInt(map['pointsAgainst']),
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class ArcadeModel extends ChangeNotifier {
  ArcadeModel(this.database);

  final Database database;
  final List<ArcadeHighscoreEntry> highscores = [];

  ArcadeScene scene = ArcadeScene.start;
  ArcadeDifficulty startDifficulty = ArcadeDifficulty.normal;
  bool startTwoPlayer = false;
  bool audioMuted = false;
  bool loaded = false;

  String lastPlayerName = 'PLAYER';
  String nameInput = 'PLAYER';
  int nameInputLen = 6;
  int nameSetsFor = 0;
  int nameSetsAgainst = 0;
  int namePointsFor = 0;
  int namePointsAgainst = 0;

  ArcadeBall ball = const ArcadeBall(
    position: ArcadeVec2(0, 0),
    velocity: ArcadeVec2(0, 0),
  );
  ArcadePlayer player = const ArcadePlayer(
    x: 40,
    y: floorY - playerH,
    vy: 0,
    jumpHoldTimer: 0,
    onGround: true,
    isBlocking: false,
    blockTimer: 0,
  );
  ArcadePlayer cpu = const ArcadePlayer(
    x: courtMaxX - playerW - 24,
    y: floorY - playerH,
    vy: 0,
    jumpHoldTimer: 0,
    onGround: true,
    isBlocking: false,
    blockTimer: 0,
  );

  double elapsedSeconds = 0;
  double blockWindow = playerBlockTime;
  double cpuSpeedScale = 1;
  int level = 1;
  int playerPoints = 0;
  int cpuPoints = 0;
  int playerSets = 0;
  int cpuSets = 0;
  int highscoreSets = 0;
  int touchesLeft = 0;
  int touchesRight = 0;
  int cpuServeVariant = 0;
  int lastTouchSide = 0;
  int ballSide = 0;
  int serverSide = 1;
  bool waitingServe = true;
  double cpuServeTimer = 0.55;
  bool serveCharging = false;
  double serveCharge = 0;
  bool serveOutOnMax = false;
  bool touchGateActive = false;
  bool touchRiseReached = true;
  double touchTimer = touchMinInterval;
  double touchStartY = 0;
  double startBannerFade = startBannerFadeTime;
  double cpuHitCooldownTimer = 0;
  String status = 'Bereit';
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  Size viewport = Size.zero;
  Duration? _lastTick;

  Future<void> load() async {
    final record = await arcadeStore.record('state').get(database);
    if (record != null) {
      final storedName = (record['lastPlayerName'] as String?)?.trim();
      if (storedName != null && storedName.isNotEmpty) {
        lastPlayerName = _sanitizeName(storedName);
      }

      final storedHighscores = record['highscores'];
      if (storedHighscores is List) {
        highscores
          ..clear()
          ..addAll(
            storedHighscores
                .whereType<Map>()
                .map((item) =>
                    ArcadeHighscoreEntry.fromMap(item.cast<String, Object?>()))
                .toList(),
          );
      }
    }

    resetGame(startTwoPlayer: startTwoPlayer, difficulty: startDifficulty);
    loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    await arcadeStore.record('state').put(database, {
      'lastPlayerName': lastPlayerName,
      'highscores': highscores.map((entry) => entry.toMap()).toList(),
    });
  }

  void setViewport(Size size) {
    viewport = size;
  }

  void toggleAudio() {
    audioMuted = !audioMuted;
    notifyListeners();
  }

  void setDifficulty(ArcadeDifficulty difficulty) {
    startDifficulty = difficulty;
    status = switch (difficulty) {
      ArcadeDifficulty.easy => 'Schwierigkeit: leicht',
      ArcadeDifficulty.normal => 'Schwierigkeit: normal',
      ArcadeDifficulty.hard => 'Schwierigkeit: schwer',
    };
    notifyListeners();
  }

  void toggleTwoPlayer() {
    startTwoPlayer = !startTwoPlayer;
    notifyListeners();
  }

  void startGame() {
    resetGame(startTwoPlayer: startTwoPlayer, difficulty: startDifficulty);
    scene = ArcadeScene.playing;
    notifyListeners();
  }

  void pauseOrResume() {
    if (scene == ArcadeScene.playing) {
      scene = ArcadeScene.paused;
      status = 'Pausiert';
    } else if (scene == ArcadeScene.paused) {
      scene = ArcadeScene.playing;
      status = 'Spiel läuft';
    }
    notifyListeners();
  }

  void resetToMenu() {
    resetGame(startTwoPlayer: startTwoPlayer, difficulty: startDifficulty);
    scene = ArcadeScene.start;
    notifyListeners();
  }

  void enterNameEntry() {
    scene = ArcadeScene.nameEntry;
    nameSetsFor = playerSets;
    nameSetsAgainst = cpuSets;
    namePointsFor = playerPoints;
    namePointsAgainst = cpuPoints;
    nameInput = lastPlayerName;
    nameInputLen = nameInput.length;
    notifyListeners();
  }

  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      return _handleKeyDown(event);
    }
    if (event is KeyUpEvent) {
      return _handleKeyUp(event);
    }
    return false;
  }

  bool _handleKeyDown(KeyDownEvent event) {
    final key = event.logicalKey;
    _pressedKeys.add(key);

    if (scene == ArcadeScene.nameEntry) {
      if (key == LogicalKeyboardKey.backspace) {
        if (nameInputLen > 0) {
          nameInputLen -= 1;
          nameInput = nameInput.substring(0, nameInputLen);
          notifyListeners();
        }
        return true;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _saveNameEntry();
        return true;
      }
      if (key == LogicalKeyboardKey.escape) {
        scene = ArcadeScene.start;
        notifyListeners();
        return true;
      }

      final typed = event.character;
      if (typed != null &&
          typed.isNotEmpty &&
          nameInputLen < highscoreNameLen) {
        final ch = typed.toUpperCase();
        final allowed = RegExp(r'[A-Z0-9]');
        if (allowed.hasMatch(ch)) {
          nameInput += ch;
          nameInputLen += 1;
          notifyListeners();
        }
      }
      return true;
    }

    if (scene == ArcadeScene.start) {
      if (key == LogicalKeyboardKey.arrowUp) {
        startTwoPlayer = false;
        notifyListeners();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        startTwoPlayer = true;
        notifyListeners();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (startDifficulty.index > 0) {
          startDifficulty = ArcadeDifficulty.values[startDifficulty.index - 1];
          notifyListeners();
        }
        return true;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        if (startDifficulty.index < ArcadeDifficulty.values.length - 1) {
          startDifficulty = ArcadeDifficulty.values[startDifficulty.index + 1];
          notifyListeners();
        }
        return true;
      }
      if (key == LogicalKeyboardKey.space) {
        toggleAudio();
        return true;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        startGame();
        return true;
      }
      return false;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (scene == ArcadeScene.playing && !startTwoPlayer) {
        enterNameEntry();
      } else {
        scene = ArcadeScene.start;
        notifyListeners();
      }
      return true;
    }

    if (key == LogicalKeyboardKey.keyM) {
      toggleAudio();
      return true;
    }
    if (key == LogicalKeyboardKey.keyR) {
      resetToMenu();
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      pauseOrResume();
      return true;
    }

    if (scene != ArcadeScene.playing) {
      return false;
    }

    if (_playerJumpKey(key)) {
      if (player.onGround) {
        player = player.copyWith(
            vy: playerJumpSpeed,
            jumpHoldTimer: playerJumpHoldTime,
            onGround: false);
      }
      if (!waitingServe) {
        player = player.copyWith(isBlocking: true, blockTimer: blockWindow);
      }
      notifyListeners();
      return true;
    }

    if (_cpuJumpKey(key) && startTwoPlayer) {
      if (cpu.onGround) {
        cpu = cpu.copyWith(
            vy: playerJumpSpeed,
            jumpHoldTimer: playerJumpHoldTime,
            onGround: false);
      }
      if (!waitingServe) {
        cpu = cpu.copyWith(isBlocking: true, blockTimer: blockWindow);
      }
      notifyListeners();
      return true;
    }

    if (_serveChargeKeyLeft(key)) {
      if (waitingServe && serverSide < 0) {
        serveCharging = true;
        notifyListeners();
        return true;
      }
    }

    if (_serveChargeKeyRight(key) && startTwoPlayer) {
      if (waitingServe && serverSide > 0) {
        serveCharging = true;
        notifyListeners();
        return true;
      }
    }

    return _moveKeyDown(key);
  }

  bool _handleKeyUp(KeyUpEvent event) {
    final key = event.logicalKey;
    _pressedKeys.remove(key);

    if (scene != ArcadeScene.playing) {
      return false;
    }

    if (_playerJumpKey(key)) {
      player = player.copyWith(jumpHoldTimer: 0);
      notifyListeners();
      return true;
    }
    if (_cpuJumpKey(key) && startTwoPlayer) {
      cpu = cpu.copyWith(jumpHoldTimer: 0);
      notifyListeners();
      return true;
    }

    if (_serveChargeKeyLeft(key) &&
        waitingServe &&
        serverSide < 0 &&
        serveCharging) {
      _startHumanChargedServe(-1);
      return true;
    }
    if (_serveChargeKeyRight(key) &&
        startTwoPlayer &&
        waitingServe &&
        serverSide > 0 &&
        serveCharging) {
      _startHumanChargedServe(1);
      return true;
    }

    return _moveKeyUp(key);
  }

  bool _moveKeyDown(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyA ||
        (!startTwoPlayer && key == LogicalKeyboardKey.arrowLeft)) {
      return true;
    }
    if (key == LogicalKeyboardKey.keyD ||
        (!startTwoPlayer && key == LogicalKeyboardKey.arrowRight)) {
      return true;
    }
    if (startTwoPlayer && key == LogicalKeyboardKey.arrowLeft) {
      return true;
    }
    if (startTwoPlayer && key == LogicalKeyboardKey.arrowRight) {
      return true;
    }
    if (_serveChargeKeyLeft(key) || _serveChargeKeyRight(key)) {
      return true;
    }
    return false;
  }

  bool _moveKeyUp(LogicalKeyboardKey key) => _moveKeyDown(key);

  bool _playerJumpKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.keyW ||
        (!startTwoPlayer && key == LogicalKeyboardKey.arrowUp) ||
        (!startTwoPlayer && key == LogicalKeyboardKey.space);
  }

  bool _cpuJumpKey(LogicalKeyboardKey key) {
    return startTwoPlayer && key == LogicalKeyboardKey.arrowUp;
  }

  bool _serveChargeKeyLeft(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        (!startTwoPlayer && key == LogicalKeyboardKey.controlRight);
  }

  bool _serveChargeKeyRight(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.altGraph ||
        key == LogicalKeyboardKey.modeChange;
  }

  void onMoveLeft() {
    if (scene != ArcadeScene.playing) return;
    player = player.copyWith(x: math.max(courtMinX, player.x - 30));
    notifyListeners();
  }

  void onMoveRight() {
    if (scene != ArcadeScene.playing) return;
    player = player.copyWith(x: math.min(netX - playerW - 6.0, player.x + 30));
    notifyListeners();
  }

  void movePlayerTo(double worldX) {
    if (scene != ArcadeScene.playing) return;

    final clamped = _clamp(
      worldX - playerW / 2,
      courtMinX,
      netX - playerW - 6.0,
    );
    player = player.copyWith(x: clamped);
    notifyListeners();
  }

  void onHitButton() {
    if (scene != ArcadeScene.playing || viewport == Size.zero) return;
    final playerFloor = floorY - playerH;
    final close = (ball.position.y - (playerFloor + headRadius)).abs() < 64 &&
        (ball.position.x - (player.x + playerW / 2)).abs() < 72;
    if (!close) return;
    ball = ball.copyWith(
      velocity: ArcadeVec2(
        ball.position.x < windowWidth / 2 ? 320 : -320,
        -780,
      ),
    );
    status = player.x < ball.position.x ? 'Pritschen' : 'Schlag';
    notifyListeners();
  }

  void onStartButton() => startGame();

  void onPauseButton() => pauseOrResume();

  void tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;

    if (!loaded || scene != ArcadeScene.playing || viewport == Size.zero) {
      return;
    }

    final dt = previous == null
        ? 0.0
        : (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    if (dt <= 0) return;

    elapsedSeconds += dt;

    if (startBannerFade > 0) {
      startBannerFade = math.max(0, startBannerFade - dt);
    }

    touchTimer += dt;
    if (touchGateActive && !touchRiseReached) {
      if ((touchStartY - ball.position.y) >= touchMinRisePx) {
        touchRiseReached = true;
      }
    }
    _refreshDifficulty();

    _updateMovement(dt);
    _updateJumpAndBlocks(dt);

    if (waitingServe) {
      _placeBallInServerHand();
      if (serveCharging) {
        serveCharge = math.min(1.0, serveCharge + dt / serveChargeMaxTime);
      }
      if (!startTwoPlayer && serverSide > 0) {
        cpuServeTimer -= dt;
        if (cpuServeTimer <= 0) {
          _startServe(1);
        }
      }
      notifyListeners();
      return;
    }

    _updateCpuAi(dt);

    _updateBall(dt);

    if (ball.position.y + ballRadius >= floorY) {
      _awardPoint(ball.position.x < netX, false);
    }

    notifyListeners();
  }

  void _refreshDifficulty() {
    var computedLevel = 1 + (elapsedSeconds / 60.0).floor();
    if (computedLevel > 8) computedLevel = 8;
    level = computedLevel;
    cpuSpeedScale = 1.0 + 0.08 * (level - 1);
    final tightened = playerBlockTime - 0.01 * (level - 1);
    blockWindow = _clamp(tightened, playerBlockTimeMin, playerBlockTime);
  }

  void _updateMovement(double dt) {
    final playerMoveLeft = _isPressed(LogicalKeyboardKey.keyA) ||
        (!startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowLeft));
    final playerMoveRight = _isPressed(LogicalKeyboardKey.keyD) ||
        (!startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowRight));
    final rightMoveLeft =
        startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowLeft);
    final rightMoveRight =
        startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowRight);

    var pMoveLeft = playerMoveLeft;
    var pMoveRight = playerMoveRight;
    var cMoveLeft = rightMoveLeft;
    var cMoveRight = rightMoveRight;

    if (waitingServe) {
      if (serverSide < 0) {
        pMoveRight = false;
      } else if (serverSide > 0) {
        cMoveLeft = false;
      }
    }

    if (pMoveLeft) {
      player = player.copyWith(x: player.x - playerSpeed * dt);
    }
    if (pMoveRight) {
      player = player.copyWith(x: player.x + playerSpeed * dt);
    }
    if (cMoveLeft) {
      cpu = cpu.copyWith(x: cpu.x - playerSpeed * dt);
    }
    if (cMoveRight) {
      cpu = cpu.copyWith(x: cpu.x + playerSpeed * dt);
    }

    player =
        player.copyWith(x: _clamp(player.x, courtMinX, netX - playerW - 6.0));
    cpu = cpu.copyWith(x: _clamp(cpu.x, netX + 8.0, courtMaxX - playerW));
  }

  void _updateJumpAndBlocks(double dt) {
    player = _updateActorJump(
        player,
        dt,
        _isPressed(LogicalKeyboardKey.keyW) ||
            (!startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowUp)) ||
            (!startTwoPlayer && _isPressed(LogicalKeyboardKey.space)));
    cpu = _updateActorJump(
        cpu, dt, startTwoPlayer && _isPressed(LogicalKeyboardKey.arrowUp));

    player = _updateActorBlock(player, dt);
    cpu = _updateActorBlock(cpu, dt);

    if (cpuHitCooldownTimer > 0) {
      cpuHitCooldownTimer = math.max(0, cpuHitCooldownTimer - dt);
    }
  }

  ArcadePlayer _updateActorJump(ArcadePlayer actor, double dt, bool jumpHeld) {
    var vy = actor.vy;
    var y = actor.y;
    var jumpHold = actor.jumpHoldTimer;
    var onGround = actor.onGround;

    var gravityScale = 1.0;
    if (!onGround && vy < 0) {
      if (jumpHeld && jumpHold > 0) {
        gravityScale = playerJumpHoldGravityMult;
        jumpHold = math.max(0, jumpHold - dt);
      } else {
        gravityScale = playerJumpReleaseGravityMult;
      }
    }

    vy += playerGravity * gravityScale * dt;
    y += vy * dt;
    if (y >= floorY - playerH) {
      y = floorY - playerH;
      vy = 0;
      jumpHold = 0;
      onGround = true;
    }

    return actor.copyWith(
        y: y, vy: vy, jumpHoldTimer: jumpHold, onGround: onGround);
  }

  ArcadePlayer _updateActorBlock(ArcadePlayer actor, double dt) {
    if (!actor.isBlocking) return actor;
    final timer = actor.blockTimer - dt;
    if (timer <= 0) {
      return actor.copyWith(isBlocking: false, blockTimer: 0);
    }
    return actor.copyWith(blockTimer: timer);
  }

  void _updateCpuAi(double dt) {
    final difficultyFactor = 1.0 + 0.15 * (level - 1);
    var aiFactor = 1.0;
    var shouldCpuBlock = false;
    var shouldCpuJump = false;

    final cpuHeadX = cpu.x + playerW * 0.5;
    final cpuHeadY = cpu.y;
    final predictedLandingX =
        _predictBallXAtY(ball, gravity, floorY - ballRadius - 4);
    final predictedNetY =
        _predictBallYAtX(ball, gravity, netX + ballRadius + 6);
    final ballNearNetAttack = ball.velocity.x < -20 &&
        predictedNetY != null &&
        predictedNetY > netTopY - 40 * aiFactor &&
        predictedNetY < netTopY + 120 * aiFactor;
    final defensiveJumpWindow = ball.position.x > netX + 18 &&
        (ball.position.x - cpuHeadX).abs() < 74 * aiFactor &&
        ball.position.y < cpuHeadY + 20 &&
        ball.position.y > cpuHeadY - 130 &&
        ball.velocity.y > -35;
    final emergencySave = predictedLandingX != null &&
        predictedLandingX > netX + 8 &&
        (predictedLandingX - cpuHeadX).abs() < 98 &&
        ball.position.y > floorY - 138 &&
        ball.velocity.y > 150;

    shouldCpuBlock = ballNearNetAttack;
    shouldCpuJump = defensiveJumpWindow || emergencySave;

    if (!startTwoPlayer) {
      var cpuTargetX = cpu.x;
      final interceptY = cpuHeadY + 18;
      final predicted = _predictBallXAtY(ball, gravity, interceptY);
      final landing = _predictBallXAtY(ball, gravity, floorY - ballRadius - 4);
      final predictedAtNet =
          _predictBallYAtX(ball, gravity, netX + ballRadius + 6);
      var tacticalOffset = 10.0;

      if (touchesRight >= 1) tacticalOffset = 14.0;
      if (touchesRight >= 2) tacticalOffset = 6.0;

      if (ball.position.x > netX + 8 && predicted != null) {
        cpuTargetX = predicted - playerW * 0.5 + tacticalOffset;
        if (landing != null &&
            landing > netX + 8 &&
            (landing - cpuHeadX).abs() < 96 &&
            ball.velocity.y > 160) {
          cpuTargetX = predicted - playerW * 0.5 + 4.0;
        }
      } else if (ball.position.x > netX + 8) {
        cpuTargetX = ball.position.x - playerW * 0.5 + tacticalOffset;
      } else {
        cpuTargetX = lastTouchSide > 0 ? (netX + 74.0) : (netX + 122.0);
        if (predictedAtNet != null &&
            predictedAtNet > netTopY - 20 &&
            predictedAtNet < netTopY + 120) {
          cpuTargetX = netX + 42.0;
        }
      }

      cpuTargetX = _clamp(cpuTargetX, netX + 8.0, courtMaxX - playerW);
      var cpuMoveSpeed = cpuSpeed * cpuSpeedScale * aiFactor * difficultyFactor;
      final urgentDefend = ball.position.x > netX + 8 && ball.velocity.y > 130;
      if (urgentDefend) cpuMoveSpeed *= 1.28;

      if (cpu.x < cpuTargetX) {
        cpu = cpu.copyWith(x: math.min(cpuTargetX, cpu.x + cpuMoveSpeed * dt));
      } else if (cpu.x > cpuTargetX) {
        cpu = cpu.copyWith(x: math.max(cpuTargetX, cpu.x - cpuMoveSpeed * dt));
      }
    }

    if (!cpu.isBlocking && shouldCpuBlock) {
      cpu = cpu.copyWith(
          isBlocking: true,
          blockTimer:
              cpuBlockTime * _clamp(difficultyFactor * aiFactor, 0.8, 1.35));
    }
    if (cpu.onGround && (shouldCpuJump || shouldCpuBlock)) {
      cpu = cpu.copyWith(vy: cpuJumpSpeed, jumpHoldTimer: 0, onGround: false);
    }
  }

  void _updateBall(double dt) {
    final prevX = ball.position.x;
    final prevY = ball.position.y;
    final playerHeadX = player.x + playerW * 0.5;
    final playerHeadY = player.y;
    final cpuHeadX = cpu.x + playerW * 0.5;
    final cpuHeadY = cpu.y;
    final playerNearNet = (netX - playerHeadX) <= blockJumpNetDistance;
    final cpuNearNet = (cpuHeadX - netX) <= blockJumpNetDistance;

    final playerPose = computeArmPose(
        player.x, player.y, true, !player.onGround, playerNearNet);
    final cpuPose =
        computeArmPose(cpu.x, cpu.y, false, !cpu.onGround, cpuNearNet);

    ball = ball.copyWith(
      velocity: ArcadeVec2(ball.velocity.x, ball.velocity.y + gravity * dt),
      position: ArcadeVec2(ball.position.x + ball.velocity.x * dt,
          ball.position.y + ball.velocity.y * dt),
    );

    if (ball.position.x - ballRadius < courtMinX) {
      if (_shouldReboundOnBackWall(-1, ball.position.y)) {
        ball = ball.copyWith(
            position: ArcadeVec2(courtMinX + ballRadius, ball.position.y),
            velocity:
                ArcadeVec2(ball.velocity.x.abs() * 0.86, ball.velocity.y));
      } else {
        _awardPoint(lastTouchSide > 0, false);
        return;
      }
    }
    if (ball.position.x + ballRadius > courtMaxX) {
      if (_shouldReboundOnBackWall(1, ball.position.y)) {
        ball = ball.copyWith(
            position: ArcadeVec2(courtMaxX - ballRadius, ball.position.y),
            velocity:
                ArcadeVec2(-ball.velocity.x.abs() * 0.86, ball.velocity.y));
      } else {
        _awardPoint(lastTouchSide > 0, false);
        return;
      }
    }

    if (ball.position.x - ballRadius < netX + 4 &&
        ball.position.x + ballRadius > netX - 4 &&
        ball.position.y + ballRadius > netTopY) {
      if (ball.position.x < netX) {
        ball = ball.copyWith(
            position: ArcadeVec2(netX - ballRadius - 4, ball.position.y),
            velocity:
                ArcadeVec2(-ball.velocity.x.abs() * 0.86, ball.velocity.y));
      } else {
        ball = ball.copyWith(
            position: ArcadeVec2(netX + ballRadius + 4, ball.position.y),
            velocity:
                ArcadeVec2(ball.velocity.x.abs() * 0.86, ball.velocity.y));
      }
    }

    if (!serveOutOnMax && _canTouchBall()) {
      var touched = false;
      if (_reflectBallOnHandZone(
          ball,
          prevX,
          prevY,
          playerPose.shoulderX,
          playerPose.shoulderY,
          playerPose.handX,
          playerPose.handY,
          true,
          player.vy,
          player.onGround)) {
        touched = true;
      } else if (_reflectBallOnHeadZone(ball, prevX, prevY, playerHeadX,
          playerHeadY, true, player.vy, player.onGround, true)) {
        touched = true;
      }

      if (touched) {
        _registerBallTouch();
        lastTouchSide = -1;
        touchesLeft += 1;
        if (touchesLeft > maxTouchesPerSide) {
          _awardPoint(false, false);
          return;
        }
      }
    }

    if (!serveOutOnMax && ball.position.x > netX + 10) {
      if (_canTouchBall()) {
        var touched = false;
        if (_reflectBallOnHandZone(
            ball,
            prevX,
            prevY,
            cpuPose.shoulderX,
            cpuPose.shoulderY,
            cpuPose.handX,
            cpuPose.handY,
            false,
            cpu.vy,
            cpu.onGround)) {
          touched = true;
        } else if (_reflectBallOnHeadZone(ball, prevX, prevY, cpuHeadX,
            cpuHeadY, false, cpu.vy, cpu.onGround, false)) {
          touched = true;
        }

        if (touched) {
          if (ball.velocity.x > -170) {
            ball = ball.copyWith(velocity: ArcadeVec2(-170, ball.velocity.y));
          }
          _registerBallTouch();
          lastTouchSide = 1;
          touchesRight += 1;
          if (touchesRight > maxTouchesPerSide) {
            _awardPoint(true, false);
            return;
          }
          if (cpuHitCooldownTimer <= 0) {
            cpuHitCooldownTimer =
                cpuHitCooldown / _clamp(cpuSpeedScale, 0.6, 2.8);
          }
        }
      }
    }

    final currentSide = ball.position.x < netX ? -1 : 1;
    if (currentSide != ballSide) {
      ballSide = currentSide;
      if (currentSide < 0) {
        touchesLeft = 0;
      } else {
        touchesRight = 0;
      }
    }

    if (serveOutOnMax &&
        startDifficulty.index >= 2 &&
        ball.position.x - ballRadius > courtMaxX) {
      _awardPoint(lastTouchSide > 0, false);
      return;
    }

    if (ball.position.y + ballRadius >= floorY) {
      _awardPoint(ball.position.x >= netX, false);
      return;
    }
  }

  bool _shouldReboundOnBackWall(int wallSide, double ballY) {
    const courtTopY = 40.0;
    final middleY = courtTopY + (floorY - courtTopY) * 0.5;
    final lowerQuarterY = floorY - (floorY - courtTopY) * 0.25;
    final ownSide = lastTouchSide == wallSide;
    final opponentSide = lastTouchSide == -wallSide;

    if (startDifficulty.index <= 0) return true;
    if (startDifficulty.index >= 2) return false;
    if (ownSide && ballY < middleY) return true;
    if (opponentSide && ballY >= lowerQuarterY) return false;
    return false;
  }

  bool _canTouchBall() {
    return !touchGateActive ||
        (touchTimer >= touchMinInterval && touchRiseReached);
  }

  void _registerBallTouch() {
    touchGateActive = true;
    touchRiseReached = false;
    touchTimer = 0;
    touchStartY = ball.position.y;
  }

  void _placeBallInServerHand() {
    if (serverSide < 0) {
      final hx = player.x + playerW * 0.5;
      final hy = player.y;
      ball = ball.copyWith(
          position: ArcadeVec2(hx + headRadius + ballRadius - 3,
              hy - (headRadius + ballRadius - 3)),
          velocity: const ArcadeVec2(0, 0));
    } else {
      final hx = cpu.x + playerW * 0.5;
      final hy = cpu.y;
      ball = ball.copyWith(
          position: ArcadeVec2(hx - (headRadius + ballRadius - 3),
              hy - (headRadius + ballRadius - 3)),
          velocity: const ArcadeVec2(0, 0));
    }
  }

  void _startServe(int side) {
    if (!waitingServe || serverSide != side) return;
    waitingServe = false;
    touchesLeft = 0;
    touchesRight = 0;
    ballSide = side;
    lastTouchSide = side;

    if (side < 0) {
      ball = ball.copyWith(velocity: const ArcadeVec2(360, -430));
    } else {
      final serveScale = _clamp(cpuSpeedScale, 0.90, 1.12);
      final v = cpuServeVariant % 4;
      if (v == 0) {
        ball = ball.copyWith(
            velocity: ArcadeVec2(
                -560.0 * serveScale * 0.90, -430.0 * serveScale * 1.02));
      } else if (v == 1) {
        ball = ball.copyWith(
            velocity: ArcadeVec2(
                -520.0 * serveScale * 0.90, -500.0 * serveScale * 1.02));
      } else if (v == 2) {
        ball = ball.copyWith(
            velocity: ArcadeVec2(
                -620.0 * serveScale * 0.90, -390.0 * serveScale * 1.02));
      } else {
        ball = ball.copyWith(
            velocity: ArcadeVec2(
                -540.0 * serveScale * 0.90, -460.0 * serveScale * 1.02));
      }
      cpuServeVariant = (cpuServeVariant + 1) % 4;
    }

    touchGateActive = false;
    touchRiseReached = true;
    touchTimer = touchMinInterval;
    serveCharging = false;
    serveCharge = 0;
    serveOutOnMax = false;
  }

  void _startHumanChargedServe(int side) {
    if (!waitingServe || serverSide != side) return;
    final c = _clamp(serveCharge, 0, 1);
    waitingServe = false;
    touchesLeft = 0;
    touchesRight = 0;
    ballSide = side;
    lastTouchSide = side;

    final hitterY = side < 0 ? player.y : cpu.y;
    final hitterVy = side < 0 ? player.vy : cpu.vy;
    serveOutOnMax = c >= 0.999;
    if (serveOutOnMax) {
      ball = ball.copyWith(velocity: ArcadeVec2(side < 0 ? 760 : -760, -120));
    } else {
      final jumpHeight = (floorY - playerH) - hitterY;
      final jumpInfluence = _clamp(jumpHeight / 90.0, 0, 1);
      final vx = 300.0 + 340.0 * c + 90.0 * jumpInfluence;
      ball = ball.copyWith(
          velocity: ArcadeVec2(side < 0 ? vx : -vx,
              -(560.0 - 170.0 * c) + 0.25 * hitterVy - 45.0 * jumpInfluence));
    }

    touchGateActive = false;
    touchRiseReached = true;
    touchTimer = touchMinInterval;
    serveCharging = false;
    serveCharge = 0;
  }

  void _resetRally() {
    player = player.copyWith(
        x: 40,
        y: floorY - playerH,
        vy: 0,
        jumpHoldTimer: 0,
        onGround: true,
        isBlocking: false,
        blockTimer: 0);
    cpu = cpu.copyWith(
        x: courtMaxX - playerW - 24,
        y: floorY - playerH,
        vy: 0,
        jumpHoldTimer: 0,
        onGround: true,
        isBlocking: false,
        blockTimer: 0);
    cpuHitCooldownTimer = 0;
    touchesLeft = 0;
    touchesRight = 0;
    ballSide = serverSide;
    lastTouchSide = 0;
    waitingServe = true;
    cpuServeTimer = 0.55;
    serveCharging = false;
    serveCharge = 0;
    serveOutOnMax = false;
    touchGateActive = false;
    touchRiseReached = true;
    touchTimer = touchMinInterval;
    _placeBallInServerHand();
    touchStartY = ball.position.y;
  }

  void resetGame(
      {required bool startTwoPlayer, required ArcadeDifficulty difficulty}) {
    this.startTwoPlayer = startTwoPlayer;
    startDifficulty = difficulty;
    if (difficulty.index < 0) {
      startDifficulty = ArcadeDifficulty.easy;
    }
    playerPoints = 0;
    cpuPoints = 0;
    playerSets = 0;
    cpuSets = 0;
    cpuServeVariant = 0;
    elapsedSeconds = 0;
    level = 1;
    blockWindow = playerBlockTime;
    cpuSpeedScale = 1;
    serverSide = 1;
    startBannerFade = startBannerFadeTime;
    status = 'Bereit';
    _resetRally();
  }

  void _awardPoint(bool playerWon, bool miss) {
    if (playerWon) {
      playerPoints += 1;
      serverSide = -1;
    } else {
      cpuPoints += 1;
      serverSide = 1;
      if (miss) {
        status = 'Fehler';
      }
    }

    if (!audioMuted) {
      SystemSound.play(SystemSoundType.alert);
    }

    if ((playerPoints >= pointsToWinSet || cpuPoints >= pointsToWinSet) &&
        (playerPoints - cpuPoints).abs() >= minLeadToWinSet) {
      if (playerPoints > cpuPoints) {
        playerSets += 1;
        if (playerSets > highscoreSets) {
          highscoreSets = playerSets;
        }
      } else {
        cpuSets += 1;
      }
      playerPoints = 0;
      cpuPoints = 0;
    }

    if (scene == ArcadeScene.playing &&
        !startTwoPlayer &&
        (playerSets > 0 || cpuSets > 0)) {
      // keep match going, just like the C version; name entry is user-triggered on Escape.
    }

    _resetRally();
    notifyListeners();
  }

  void _saveNameEntry() {
    if (nameInput.isEmpty) {
      nameInput = lastPlayerName;
      nameInputLen = nameInput.length;
    }
    lastPlayerName = _sanitizeName(nameInput);
    _insertHighscore(
      ArcadeHighscoreEntry(
        name: lastPlayerName,
        setsFor: nameSetsFor,
        setsAgainst: nameSetsAgainst,
        pointsFor: namePointsFor,
        pointsAgainst: namePointsAgainst,
      ),
    );
    persist();
    scene = ArcadeScene.start;
    notifyListeners();
  }

  void saveNameEntry() {
    _saveNameEntry();
  }

  void cancelNameEntry() {
    scene = ArcadeScene.start;
    notifyListeners();
  }

  void _insertHighscore(ArcadeHighscoreEntry entry) {
    highscores.add(entry);
    highscores.sort((a, b) {
      final setDiffA = a.setsFor - a.setsAgainst;
      final setDiffB = b.setsFor - b.setsAgainst;
      final pointDiffA = a.pointsFor - a.pointsAgainst;
      final pointDiffB = b.pointsFor - b.pointsAgainst;

      if (a.setsFor != b.setsFor) return b.setsFor.compareTo(a.setsFor);
      if (setDiffA != setDiffB) return setDiffB.compareTo(setDiffA);
      if (a.pointsFor != b.pointsFor) return b.pointsFor.compareTo(a.pointsFor);
      return pointDiffB.compareTo(pointDiffA);
    });
    if (highscores.length > maxHighscores) {
      highscores.length = maxHighscores;
    }
  }

  String _sanitizeName(String value) {
    final cleaned = value.trim().toUpperCase();
    if (cleaned.isEmpty) return 'PLAYER';
    return cleaned.substring(0, math.min(cleaned.length, highscoreNameLen));
  }

  double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  bool _isPressed(LogicalKeyboardKey key) => _pressedKeys.contains(key);

  double? _predictBallXAtY(
      ArcadeBall ballState, double gravityValue, double targetY) {
    final a = 0.5 * gravityValue;
    final b = ballState.velocity.y;
    final c = ballState.position.y - targetY;
    final disc = b * b - 4 * a * c;
    if (disc < 0 || a.abs() < 0.0001) return null;

    final sqrtDisc = math.sqrt(disc);
    final t1 = (-b - sqrtDisc) / (2 * a);
    final t2 = (-b + sqrtDisc) / (2 * a);
    final candidates = [t1, t2].where((value) => value > 0).toList();
    if (candidates.isEmpty) return null;
    final t = candidates.reduce(math.min);
    return ballState.position.x + ballState.velocity.x * t;
  }

  double? _predictBallYAtX(
      ArcadeBall ballState, double gravityValue, double targetX) {
    if (ballState.velocity.x.abs() < 0.001) return null;
    final t = (targetX - ballState.position.x) / ballState.velocity.x;
    if (t <= 0) return null;
    return ballState.position.y +
        ballState.velocity.y * t +
        0.5 * gravityValue * t * t;
  }

  ArcadeArmPose computeArmPose(
      double bodyX, double bodyY, bool towardRight, bool armsUp, bool nearNet) {
    final dir = towardRight ? 1.0 : -1.0;
    final sx = bodyX + playerW * 0.5 + dir * 3.0;
    final sy = bodyY + 50.0;
    double hx;
    double hy;

    if (armsUp) {
      if (nearNet) {
        hx = sx + dir * 4.0;
        hy = sy - 100.0;
      } else {
        hx = sx + dir * 16.0;
        hy = sy - 72.0;
      }
    } else {
      hx = sx + dir * 34.0;
      hy = sy + 36.0;
    }

    return ArcadeArmPose(sx, sy, hx, hy);
  }

  bool _reflectBallOnHeadZone(
    ArcadeBall currentBall,
    double prevX,
    double prevY,
    double headX,
    double headY,
    bool towardRight,
    double hitterVy,
    bool hitterOnGround,
    bool allowBackHeadHit,
  ) {
    final sumR = ballRadius + headRadius;
    final dist2 = _pointSegmentDistanceSq(headX, headY, prevX, prevY,
        currentBall.position.x, currentBall.position.y);
    if (dist2 > sumR * sumR) return false;

    var nx = currentBall.position.x - headX;
    var ny = currentBall.position.y - headY;
    final nLen2 = nx * nx + ny * ny;
    final nLen = nLen2 < 0.0001
        ? math.sqrt(
            (towardRight ? 1.0 : -1.0) * (towardRight ? 1.0 : -1.0) + 0.01)
        : math.sqrt(nLen2);
    if (nLen2 < 0.0001) {
      nx = towardRight ? 1.0 : -1.0;
      ny = -0.1;
    }
    nx /= nLen;
    ny /= nLen;

    ball = ball.copyWith(
        position: ArcadeVec2(headX + nx * (sumR + 1), headY + ny * (sumR + 1)));

    var hitT = (ball.position.x - (headX - headRadius)) / (2 * headRadius);
    hitT = _clamp(hitT, 0, 1);
    final frontness = towardRight ? hitT : (1 - hitT);
    var vxMag = 250.0 + 215.0 * frontness;
    var vyMag = 375.0 + 245.0 * frontness;
    if (!hitterOnGround) {
      final upwardFactor = _clamp((-hitterVy) / 560.0, 0, 1);
      final jumpBoost = 1.02 + 0.07 * upwardFactor;
      vxMag *= jumpBoost;
      vyMag *= jumpBoost;
    }
    final backHeadHit = allowBackHeadHit && (frontness < 0.25);
    ball = ball.copyWith(
      velocity: ArcadeVec2(
        backHeadHit
            ? (towardRight ? -vxMag : vxMag)
            : (towardRight ? vxMag : -vxMag),
        -vyMag,
      ),
    );
    return true;
  }

  bool _reflectBallOnHandZone(
    ArcadeBall currentBall,
    double prevX,
    double prevY,
    double shoulderX,
    double shoulderY,
    double handX,
    double handY,
    bool towardRight,
    double hitterVy,
    bool hitterOnGround,
  ) {
    final sumR = ballRadius + handHitRadius;
    final sweepDist2 = _pointSegmentDistanceSq(handX, handY, prevX, prevY,
        currentBall.position.x, currentBall.position.y);
    final armDistNow2 = _pointSegmentDistanceSq(currentBall.position.x,
        currentBall.position.y, shoulderX, shoulderY, handX, handY);
    final armDistPrev2 = _pointSegmentDistanceSq(
        prevX, prevY, shoulderX, shoulderY, handX, handY);
    final handNowDx = currentBall.position.x - handX;
    final handNowDy = currentBall.position.y - handY;
    final handNowDist2 = handNowDx * handNowDx + handNowDy * handNowDy;
    final handHit = sweepDist2 <= sumR * sumR;
    final armHit = armDistNow2 <= sumR * sumR || armDistPrev2 <= sumR * sumR;

    if (!handHit && !armHit) return false;

    double contactX = handX;
    double contactY = handY;
    if (armHit && armDistNow2 < handNowDist2) {
      final closest = _closestPointOnSegment(currentBall.position.x,
          currentBall.position.y, shoulderX, shoulderY, handX, handY);
      contactX = closest.x;
      contactY = closest.y;
    }

    var nx = currentBall.position.x - contactX;
    var ny = currentBall.position.y - contactY;
    final nLen2 = nx * nx + ny * ny;
    final nLen = nLen2 < 0.0001
        ? math.sqrt(
            (towardRight ? 1.0 : -1.0) * (towardRight ? 1.0 : -1.0) + 0.01)
        : math.sqrt(nLen2);
    if (nLen2 < 0.0001) {
      nx = towardRight ? 1.0 : -1.0;
      ny = -0.18;
    }
    nx /= nLen;
    ny /= nLen;
    ball = ball.copyWith(
        position:
            ArcadeVec2(contactX + nx * (sumR + 1), contactY + ny * (sumR + 1)));

    var handHitT =
        (ball.position.y - (contactY - handHitRadius)) / (2 * handHitRadius);
    handHitT = _clamp(handHitT, 0, 1);
    final topHit = 1 - handHitT;
    var vxMag = 250.0 + 215.0 * topHit;
    var vyMag = 375.0 + 245.0 * topHit;
    if (!hitterOnGround) {
      final upwardFactor = _clamp((-hitterVy) / 560.0, 0, 1);
      final jumpBoost = 1.02 + 0.07 * upwardFactor;
      vxMag *= jumpBoost;
      vyMag *= jumpBoost;
    }

    ball = ball.copyWith(
        velocity: ArcadeVec2(towardRight ? vxMag : -vxMag, -vyMag));
    return true;
  }

  _ArcadePoint _closestPointOnSegment(
      double px, double py, double ax, double ay, double bx, double by) {
    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final abLen2 = abx * abx + aby * aby;
    var t = 0.0;
    if (abLen2 > 0.0001) {
      t = _clamp((apx * abx + apy * aby) / abLen2, 0, 1);
    }
    return _ArcadePoint(ax + t * abx, ay + t * aby);
  }

  double _pointSegmentDistanceSq(
      double px, double py, double ax, double ay, double bx, double by) {
    final closest = _closestPointOnSegment(px, py, ax, ay, bx, by);
    final dx = px - closest.x;
    final dy = py - closest.y;
    return dx * dx + dy * dy;
  }
}

class ArcadeArmPose {
  const ArcadeArmPose(this.shoulderX, this.shoulderY, this.handX, this.handY);

  final double shoulderX;
  final double shoulderY;
  final double handX;
  final double handY;
}

class _ArcadePoint {
  const _ArcadePoint(this.x, this.y);

  final double x;
  final double y;
}
