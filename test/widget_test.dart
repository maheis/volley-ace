import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/backup/app_backup_service.dart';
import 'package:volleyace/src/arcade/arcade_page.dart';
import 'package:volleyace/src/settings/settings_repository.dart';
import 'package:volleyace/src/scoreboard/scoreboard_repository.dart';
import 'package:volleyace/src/scoreboard/scoreboard_page.dart';
import 'package:volleyace/src/scoreboard/scoreboard_state.dart';
import 'package:volleyace/src/settings/app_settings.dart';
import 'package:volleyace/src/settings/settings_page.dart';
import 'package:volleyace/src/teams/teams_page.dart';
import 'package:volleyace/src/tactics/tactics_page.dart';
import 'package:volleyace/src/training/training_page.dart';

void main() {
  testWidgets('Settings page shows typography controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(initial: AppSettings.defaults)),
    );

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Schriftart'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
  });

  test('Settings repository migrates the default font once', () async {
    final database = await databaseFactoryMemory.openDatabase(
      'settings-migration.db',
    );
    final repository = SettingsRepository(database);

    final migratedSettings = await repository.load();

    expect(migratedSettings.fontFamily, 'Ubuntu');
  });

  test('Team export payload contains one team', () {
    final team = Team(
      id: 7,
      name: 'SV Beispiel',
      players: const [
        TeamPlayer(
          id: 1,
          name: 'Ada',
          number: 12,
          birthDate: null,
          position: 'Mitte',
          profile: 'Stark am Netz',
        ),
      ],
      coaches: const [
        TeamCoach(
          id: 2,
          name: 'Mara',
          profile: 'Cheftrainerin',
          birthDate: null,
          position: 'Trainerin',
        ),
      ],
    );

    final payload = AppBackupService.buildTeamBackup(team);

    expect(payload['type'], 'team');
    expect(payload['team'], isA<Map<String, dynamic>>());
    expect((payload['team'] as Map<String, dynamic>)['name'], 'SV Beispiel');
  });

  test('Match export payload contains one match', () {
    final match = MatchGame(
      id: 11,
      createdAt: DateTime(2026),
      location: 'Halle A',
      opponentTeam: 'Team B',
      matchDateTime: DateTime(2026),
      matchTag: 'Finale',
      matchType: 'Liga',
      teamId: null,
      coaches: const [],
      players: const [],
      events: const [],
    );

    final payload = AppBackupService.buildMatchBackup(match);

    expect(payload['type'], 'match');
    expect(payload['match'], isA<Map<String, dynamic>>());
    expect(
        (payload['match'] as Map<String, dynamic>)['opponentTeam'], 'Team B');
  });

  testWidgets('Arcade page moves the player on drag', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('arcade.db');
    await tester.pumpWidget(
      MaterialApp(home: ArcadePage(database: database)),
    );
    await tester.pump(const Duration(milliseconds: 150));

    final state = tester.state(find.byType(ArcadePage)) as dynamic;
    state.model.startGame();
    await tester.pump(const Duration(milliseconds: 150));

    final before = state.model.player.x as double;
    await tester.drag(
      find.byKey(const ValueKey('arcade-court-gesture')),
      const Offset(140, 0),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(state.model.player.x as double, greaterThan(before));
  });

  testWidgets('Tactics board adds a colored point',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await databaseFactoryMemory.openDatabase('tactics.db');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: TacticsPage(database: database),
      ),
    );
    await tester.pumpAndSettle();

    final board = find.byKey(const ValueKey('tactics-board'));
    expect(board, findsOneWidget);
    await tester.tap(board);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Taktik speichern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tactic-name-input')),
      'Aufschlag',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Taktik laden'));
    await tester.pumpAndSettle();
    expect(find.text('Aufschlag'), findsOneWidget);
    await tester.tap(find.text('Aufschlag'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Feld ins Querformat drehen'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Feld ins Hochformat drehen'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(80, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(240, 420), const Offset(-70, 30));
    await tester.pumpAndSettle();
    await tester.drag(board, const Offset(32, 24));
    await tester.pumpAndSettle();
    expect(find.text('Taktiktafel'), findsOneWidget);
  });

  testWidgets('Tactics board deletes the selected object with delete key', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await databaseFactoryMemory.openDatabase('tactics-del.db');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: TacticsPage(database: database),
      ),
    );
    await tester.pumpAndSettle();

    final board = find.byKey(const ValueKey('tactics-board'));
    await tester.tap(board);
    await tester.pumpAndSettle();
    await tester.tap(board);
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Ausgewähltes Objekt löschen'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Ausgewähltes Objekt löschen'),
      findsNothing,
    );
  });

  testWidgets('Scoreboard awards and undoes a point with vertical swipes', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test1.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    expect(blueScore, findsOneWidget);

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.fling(blueScore, const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: blueScore, matching: find.text('0')),
      findsOneWidget,
    );
  });

  testWidgets('Scoreboard starts stopwatch automatically on first point', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('stopwatch.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final persisted = await ScoreboardRepository(database).load();
    expect(persisted.leftPoints, 1);
    expect(persisted.stopwatchRunning, isTrue);
    expect(persisted.stopwatchStartedAt, isNotNull);
    expect(persisted.stopwatchElapsed, Duration.zero);
  });

  testWidgets('Scoreboard can save and reload an old point state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = await databaseFactoryMemory.openDatabase('snapshot.db');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ScoreboardPage(database: database),
      ),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('save-scoreboard-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Erster Stand');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: blueScore, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('load-scoreboard-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erster Stand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laden'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );
  });

  test('Scoreboard can delete a saved point state', () async {
    final database =
        await databaseFactoryMemory.openDatabase('snapshot-del.db');
    final repository = ScoreboardRepository(database);

    await repository.saveSnapshot(
      ScoreboardSnapshot(
        id: '1',
        name: 'Loeschtest',
        savedAt: DateTime(2026),
        state: ScoreboardState.initial,
      ),
    );

    expect((await repository.loadSnapshots()).length, 1);

    await repository.deleteSnapshot('1');

    expect(await repository.loadSnapshots(), isEmpty);
  });

  testWidgets('Scoreboard swaps sides with a horizontal swipe', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test2.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final setScoreArea = find.byKey(const ValueKey('set-score-area'));
    await tester.fling(setScoreArea, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rot-set-panel')), findsOneWidget);
  });

  testWidgets('Scoreboard keeps match points square', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = await databaseFactoryMemory.openDatabase('test2-score.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    final redScore = find.byKey(const ValueKey('rot-score-panel'));

    final blueRect = tester.getRect(blueScore);
    final redRect = tester.getRect(redScore);

    expect((blueRect.width - blueRect.height).abs(), lessThan(1.0));
    expect((redRect.width - redRect.height).abs(), lessThan(1.0));
  });

  testWidgets('Scoreboard keeps set points centered and square', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database =
        await databaseFactoryMemory.openDatabase('test2-layout.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final setArea = find.byKey(const ValueKey('set-score-area'));
    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    final redSet = find.byKey(const ValueKey('rot-set-panel'));

    final blueRect = tester.getRect(blueSet);
    final redRect = tester.getRect(redSet);
    final areaRect = tester.getRect(setArea);

    expect((blueRect.width - blueRect.height).abs(), lessThan(1.0));
    expect((redRect.width - redRect.height).abs(), lessThan(1.0));
    expect((areaRect.center.dx - 640).abs(), lessThan(45.0));
  });

  testWidgets('Undoing a set restores the previous point score', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test3.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz beenden'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: blueScore, matching: find.text('0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: blueSet, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.fling(blueSet, const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: blueSet, matching: find.text('0')),
      findsOneWidget,
    );
  });

  testWidgets('Scoreboard starts a 30 second timeout and counts it down', (
    WidgetTester tester,
  ) async {
    final database =
        await databaseFactoryMemory.openDatabase('test-timeout.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueTimeout = find.byKey(const ValueKey('blue-timeout-button'));
    expect(blueTimeout, findsOneWidget);

    await tester.tap(blueTimeout);
    await tester.pump();

    expect(find.byKey(const ValueKey('blue-timeout-count')), findsOneWidget);
    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.textContaining('00:30'),
      ),
      findsOneWidget,
    );

    await tester.tap(blueTimeout);
    await tester.pumpAndSettle();

    expect(find.text('Auszeit beenden?'), findsOneWidget);
    await tester.tap(find.text('Zurücknehmen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('00:30'), findsNothing);
    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.tap(blueTimeout);
    await tester.pump();
    await tester.tap(blueTimeout);
    await tester.pumpAndSettle();

    expect(find.text('Auszeit beenden?'), findsOneWidget);
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(blueTimeout);
    await tester.pump();
    await tester.tap(blueTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(blueTimeout);
    await tester.pumpAndSettle();
    expect(find.text('Auszeit beenden?'), findsNothing);

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz beenden'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blue-timeout-count')), findsOneWidget);
    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.byKey(const ValueKey('blue-timeout-count')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Scoreboard timeout buttons are taller in landscape', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = await databaseFactoryMemory.openDatabase('landscape.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueTimeout = find.byKey(const ValueKey('blue-timeout-button'));
    expect(blueTimeout, findsOneWidget);

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    expect(blueScore, findsOneWidget);
    expect(blueSet, findsOneWidget);

    final scoreSize = tester.getSize(blueScore);
    final setSize = tester.getSize(blueSet);
    expect(scoreSize.width, greaterThan(setSize.width));
    expect(
      tester.getTopLeft(blueSet).dx - tester.getTopRight(blueScore).dx,
      lessThan(36),
    );

    final size = tester.getSize(blueTimeout);
    expect(size.height, greaterThan(40));
    expect((size.width - size.height).abs(), lessThan(1.0));
  });

  testWidgets('Scoreboard timeout buttons stay fixed-size squares', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database =
        await databaseFactoryMemory.openDatabase('timeout-square.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueTimeout = find.byKey(const ValueKey('blue-timeout-button'));
    final redTimeout = find.byKey(const ValueKey('red-timeout-button'));

    final blueSize = tester.getSize(blueTimeout);
    final redSize = tester.getSize(redTimeout);
    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    final setSize = tester.getSize(blueSet);

    expect((blueSize.width - blueSize.height).abs(), lessThan(1.0));
    expect((redSize.width - redSize.height).abs(), lessThan(1.0));
    expect((blueSize.width - setSize.width).abs(), lessThan(1.0));
    expect((redSize.width - setSize.width).abs(), lessThan(1.0));
  });

  testWidgets('Scoreboard stacks the score panels vertically in portrait', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = await databaseFactoryMemory.openDatabase('portrait.db');
    await tester.pumpWidget(
      MaterialApp(home: ScoreboardPage(database: database)),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    final redScore = find.byKey(const ValueKey('rot-score-panel'));
    final setArea = find.byKey(const ValueKey('set-score-area'));

    final blueRect = tester.getRect(blueScore);
    final redRect = tester.getRect(redScore);
    final setRect = tester.getRect(setArea);

    expect(blueRect.center.dy, lessThan(setRect.top));
    expect(setRect.bottom, lessThan(redRect.center.dy));
    expect(blueRect.width, greaterThan(blueRect.height * 0.8));
    expect(redRect.width, greaterThan(redRect.height * 0.8));
  });

  testWidgets('Scoreboard opens set history on a separate page', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = await databaseFactoryMemory.openDatabase('history.db');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ScoreboardPage(database: database),
      ),
    );
    await tester.pumpAndSettle();

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz beenden'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-appbar-button')));
    await tester.pumpAndSettle();

    expect(find.text('Satzpunkte'), findsOneWidget);
    expect(find.text('Verlauf'), findsOneWidget);
    expect(find.text('Zeit'), findsOneWidget);
    expect(find.text('Aktion'), findsOneWidget);
    expect(find.text('Punkt blau'), findsOneWidget);
    expect(find.text('Satz beendet blau'), findsOneWidget);
    expect(find.text('1:0'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('Satzpunkte')).dy,
      lessThan(tester.getTopLeft(find.text('Verlauf')).dy),
    );
  });

  test('Scoreboard reset clears history entries', () async {
    final database = await databaseFactoryMemory.openDatabase('reset.db');
    final repository = ScoreboardRepository(database);

    await repository.save(
      ScoreboardState(
        leftPoints: 3,
        rightPoints: 2,
        leftSets: 1,
        rightSets: 0,
        leftTimeouts: 1,
        rightTimeouts: 2,
        leftColor: ScoreboardState.defaultLeftColor,
        rightColor: ScoreboardState.defaultRightColor,
        stopwatchElapsed: Duration(seconds: 12),
        stopwatchRunning: true,
        stopwatchStartedAt: null,
        timeoutSide: null,
        timeoutStartedAt: null,
        completedSets: <SetResult>[
          SetResult(
            leftPoints: 25,
            rightPoints: 18,
            winnerColor: ScoreboardState.defaultLeftColor,
            wonAt: DateTime.fromMillisecondsSinceEpoch(1),
            stopwatchAt: Duration(seconds: 31),
          ),
        ],
        historyEntries: <ScoreboardHistoryEntry>[
          ScoreboardHistoryEntry(
            action: 'Punkt blau',
            occurredAt: DateTime.fromMillisecondsSinceEpoch(2),
            stopwatchAt: Duration(seconds: 3),
            color: ScoreboardState.defaultLeftColor,
          ),
        ],
      ),
    );

    await repository.save(ScoreboardState.initial);

    final persisted = await repository.load();
    expect(persisted.historyEntries, isEmpty);
    expect(persisted.completedSets, isEmpty);
    expect(persisted.leftPoints, 0);
    expect(persisted.rightPoints, 0);
  });

  testWidgets(
      'Match statistics page allows creating a match and recording a point', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test4.db');
    await tester
        .pumpWidget(MaterialApp(home: MatchStatsPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-game-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('match-location-input')),
      'Halle A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('match-opponent-input')),
      'Team B',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spielinfos'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('player-name-input')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('player-number-input')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('add-player-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punktewertung'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-category-Ass')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-name-input')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('match-history-appbar-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verlauf'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Ass'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Zeitverlauf gesamt'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Zeitverlauf pro Spieler'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Zeitverlauf pro Spieler'), findsOneWidget);
    expect(find.text('Ass'), findsWidgets);
  });

  testWidgets('Point scoring can record opponent error without player', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test5.db');
    await tester
        .pumpWidget(MaterialApp(home: MatchStatsPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-game-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punktewertung'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('select-category-Gegner Fehler')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('select-player-1')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Gegner Fehler'), findsWidgets);
  });

  test('Match stores selected team players with match-specific numbers', () {
    final match = MatchGame(
      id: 1,
      createdAt: DateTime(2026),
      location: '',
      opponentTeam: '',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      teamId: 3,
      coaches: const [
        MatchCoach(id: 5, name: 'Mara Mustermann'),
        MatchCoach(id: 6, name: 'Kai Beispiel'),
      ],
      players: const [
        MatchPlayer(
          id: 1,
          name: 'Ada',
          number: 12,
          teamPlayerId: 4,
          sourceTeamId: 3,
        ),
        MatchPlayer(id: 2, name: 'Manuell', number: 9),
      ],
      events: const [],
    );

    final restored = MatchGame.fromJson(match.toJson());

    expect(restored.teamId, 3);
    expect(restored.coaches.map((coach) => coach.id), [5, 6]);
    expect(restored.coaches.map((coach) => coach.name), [
      'Mara Mustermann',
      'Kai Beispiel',
    ]);
    expect(restored.players[0].number, 12);
    expect(restored.players[0].teamPlayerId, 4);
    expect(restored.players[0].sourceTeamId, 3);
    expect(restored.players[1].teamPlayerId, isNull);
  });

  testWidgets('Teams with players and coaches are persisted', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('teams.db');
    await tester.pumpWidget(MaterialApp(home: TeamsPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-team-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-name-input')),
      'SV Beispiel',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spieler'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-player-name-input')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-player-number-input')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-player-profile-input')),
      'Schnelle Mittelblockerin.',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-player-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trainer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-name-input')),
      'Mara',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-position-input')),
      'Cheftrainerin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-profile-input')),
      'Trainiert die Mittelblocker.',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-coach-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trainer bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-name-input')),
      'Mara Mustermann',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Mara Mustermann'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: TeamsPage(database: database)));
    await tester.pumpAndSettle();

    expect(find.text('SV Beispiel'), findsOneWidget);
    expect(find.text('1 Spieler • 1 Trainer'), findsOneWidget);
    await tester.tap(find.text('SV Beispiel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spieler'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('Schnelle Mittelblockerin.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trainer'));
    await tester.pumpAndSettle();
    expect(find.text('Mara Mustermann'), findsOneWidget);
    expect(find.textContaining('Trainiert die Mittelblocker.'), findsOneWidget);
    expect(find.textContaining('Cheftrainerin'), findsOneWidget);
  });

  testWidgets('Training shows team attendance matrix sorted by player number', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('training.db');
    final teamsRepository = TeamsRepository(database);
    await teamsRepository.save([
      const Team(
        id: 1,
        name: 'SV Beispiel',
        coaches: [
          TeamCoach(
            id: 1,
            name: 'Mara',
            profile: '',
            birthDate: null,
            position: 'Trainerin',
          ),
        ],
        players: [
          TeamPlayer(
            id: 1,
            name: 'Ada',
            number: 12,
            birthDate: null,
            position: '',
            profile: '',
          ),
          TeamPlayer(
            id: 2,
            name: 'Berta',
            number: 3,
            birthDate: null,
            position: '',
            profile: '',
          ),
        ],
      ),
    ]);

    await tester
        .pumpWidget(MaterialApp(home: TrainingPage(database: database)));
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Trainings angelegt.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('new-training-content-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trainingsinfo'), findsOneWidget);
    expect(find.text('Team auswählen'), findsOneWidget);
    await tester.tap(find.text('SV Beispiel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teilnahme'));
    await tester.pumpAndSettle();

    expect(find.text('Trainer'), findsOneWidget);
    expect(find.text('Spieler'), findsOneWidget);
    expect(find.text('3  Berta'), findsOneWidget);
    expect(find.text('12  Ada'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('guest-name-input')),
      'Gast Anna',
    );
    await tester.tap(find.byKey(const ValueKey('add-guest-button')));
    await tester.pumpAndSettle();
    expect(find.text('Gäste'), findsOneWidget);
    expect(find.text('Gast Anna'), findsOneWidget);

    final guestParticipation = find.byKey(
      const ValueKey('attendance-guest:0-participating'),
    );
    await tester.tap(guestParticipation);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(guestParticipation).value, isTrue);

    final adaPosition = tester.getTopLeft(find.text('12  Ada'));
    final bertaPosition = tester.getTopLeft(find.text('3  Berta'));
    expect(adaPosition.dy, lessThan(bertaPosition.dy));

    final bertaParticipation = find.byKey(
      const ValueKey('attendance-player:2-participating'),
    );
    await tester.tap(bertaParticipation);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(bertaParticipation).value, isTrue);

    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('new-training-content-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trainingsinfo'), findsOneWidget);
  });
}
