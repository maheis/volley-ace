import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/backup/app_backup_service.dart';
import 'package:volleyace/src/scoreboard/scoreboard_page.dart';
import 'package:volleyace/src/scoreboard/scoreboard_state.dart';
import 'package:volleyace/src/scoreboard/rotation_state.dart';
import 'package:volleyace/src/scoreboard/rotation_setup_page.dart';
import 'package:volleyace/src/arcade/arcade_page.dart';
import 'package:volleyace/src/scoreboard/scoreboard_repository.dart';
import 'package:volleyace/src/settings/app_settings.dart';
import 'package:volleyace/src/settings/settings_repository.dart';
import 'package:volleyace/src/settings/settings_page.dart';
import 'package:volleyace/src/teams/teams_page.dart';
import 'package:volleyace/src/tactics/tactics_page.dart';
import 'package:volleyace/src/training/training_page.dart';

Future<void> _pumpUi(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('legacy opponent-error category is normalized', () {
    final event = MatchEvent.fromJson({
      'id': 1,
      'category': 'Gegner Fehler',
    });

    expect(event.category, 'Gegnerfehler');
  });

  test('rotation follows the selected youth and senior rules', () {
    RotationTeamState team(String prefix) => RotationTeamState(
          players: List<RotationPlayer>.generate(
            6,
            (index) =>
                RotationPlayer(id: '$prefix$index', name: 'Spieler $index'),
          ),
          positions: List<String>.generate(6, (index) => '$prefix$index'),
        );
    final youth = ScoreboardRotationState(
      league: 'U13',
      left: team('l'),
      right: team('r'),
      servingSide: 0,
    );
    final seniors = ScoreboardRotationState(
      league: 'Damen',
      left: team('l'),
      right: team('r'),
      servingSide: 0,
    );

    expect(rotationPlayerCount('U12'), 3);
    expect(rotationPlayerCount('U15'), 4);
    expect(rotationPlayerCount('Herren'), 6);
    expect(youth.afterPoint(0).left.positions, youth.left.positions);
    expect(youth.afterPoint(0).afterPoint(0).left.positions, [
      'l1',
      'l2',
      'l3',
      'l4',
      'l5',
      'l0',
    ]);
    expect(youth.afterPoint(1).servingSide, 1);
    expect(youth.afterPoint(1).right.positions.first, 'r1');
    expect(seniors.afterPoint(0).left.positions, seniors.left.positions);
    expect(seniors.afterPoint(1).left.positions, seniors.left.positions);
    expect(seniors.afterPoint(1).right.positions.first, 'r1');
  });

  test('a team league selects league match type', () {
    expect(matchTypeForTeamLeague('U14'), 'Liga');
    expect(matchTypeForTeamLeague(''), 'Freundschaftsspiel');
  });

  test('rotation court positions follow each league formation', () {
    final threePlayerPositions = rotationCourtPositions('U13');
    expect(threePlayerPositions.map((position) => position.depth), [
      0.22,
      0.76,
      0.22,
    ]);
    expect(threePlayerPositions.map((position) => position.lateral), [
      0.82,
      0.5,
      0.18,
    ]);

    final fourPlayerPositions = rotationCourtPositions('U14');
    expect(fourPlayerPositions.map((position) => position.depth), [
      0.22,
      0.76,
      0.22,
      0.22,
    ]);
    expect(fourPlayerPositions.map((position) => position.lateral), [
      0.82,
      0.5,
      0.18,
      0.5,
    ]);
    expect(fourPlayerPositions[3].backOffsetPixels, 3);
    const courtWidth = 420.0;
    final leftPositionFour = rotationCourtScreenPosition(
      fourPlayerPositions[3],
      showOnLeft: true,
      courtWidth: courtWidth,
    );
    final rightPositionFour = rotationCourtScreenPosition(
      fourPlayerPositions[3],
      showOnLeft: false,
      courtWidth: courtWidth,
    );
    expect((0.22 - leftPositionFour.x) * courtWidth, closeTo(3, 0.001));
    expect((rightPositionFour.x - 0.78) * courtWidth, closeTo(3, 0.001));

    final sixPlayerPositions = rotationCourtPositions('Damen');
    expect(sixPlayerPositions.map((position) => position.depth), [
      0.22,
      0.76,
      0.76,
      0.76,
      0.22,
      0.22,
    ]);

    final leftPositionTwo = rotationCourtScreenPosition(
      sixPlayerPositions[1],
      showOnLeft: true,
    );
    final rightPositionTwo = rotationCourtScreenPosition(
      sixPlayerPositions[1],
      showOnLeft: false,
    );
    expect(leftPositionTwo.x + rightPositionTwo.x, 1);
    expect(leftPositionTwo.y + rightPositionTwo.y, 1);
  });

  test('rotation advances our playable team without opponent positions', () {
    const rotation = ScoreboardRotationState(
      league: 'U13',
      left: RotationTeamState(
        players: [
          RotationPlayer(id: 'one', name: 'Ada'),
          RotationPlayer(id: 'two', name: 'Berta'),
          RotationPlayer(id: 'three', name: 'Mara'),
        ],
        positions: ['one', 'two', 'three'],
      ),
      right: RotationTeamState(),
      servingSide: 1,
    );

    final next = rotation.afterPoint(0);

    expect(next.left.positions, ['two', 'three', 'one']);
    expect(next.right.positions, isEmpty);
    expect(next.servingSide, 0);
  });

  testWidgets('rotation setup opens on the court with info as a second page', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database =
        await databaseFactoryMemory.openDatabase('rotation-setup-flow.db');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: RotationSetupPage(database: database),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Aufstellung'), findsOneWidget);
    expect(find.byKey(const ValueKey('rotation-court')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-rotation-setup')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-rotation-setup')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-lineup-button')), findsNothing);

    await tester.tap(find.byTooltip('Spielinfos'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Spielinfos'), findsOneWidget);
    expect(find.byKey(const ValueKey('rotation-court')), findsNothing);
    expect(
        find.byKey(const ValueKey('rotation-league-select')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rotation-team-select-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-rotation-setup')), findsOneWidget);

    await tester.tap(find.byTooltip('Zur Aufstellung'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aufstellung'), findsOneWidget);
    expect(find.byKey(const ValueKey('rotation-court')), findsOneWidget);
    expect(find.text('Bank Blau · 0'), findsOneWidget);
  });

  testWidgets('tap a court position to select or bench a player', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database =
        await databaseFactoryMemory.openDatabase('rotation-pick-player.db');
    const starter = RotationPlayer(id: 'starter', name: 'Ada', number: 7);
    const reserve = RotationPlayer(id: 'reserve', name: 'Berta', number: 3);
    const back = RotationPlayer(id: 'back', name: 'Mara', number: 5);
    final initial = ScoreboardRotationState(
      league: 'U13',
      left: const RotationTeamState(
        name: 'Blau',
        players: [starter, reserve, back],
        positions: ['starter', null, 'back'],
      ),
      right: const RotationTeamState(),
      servingSide: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: RotationSetupPage(database: database, initial: initial),
      ),
    );
    await _pumpUi(tester);

    final courtCenterY =
        tester.getRect(find.byKey(const ValueKey('rotation-court'))).center.dy;
    final courtRect =
        tester.getRect(find.byKey(const ValueKey('rotation-court')));
    final leftPositionTwo = tester.getCenter(
      find.byKey(const ValueKey('rotation-position-0-1')),
    );
    final rightPositionTwo = tester.getCenter(
      find.byKey(const ValueKey('rotation-position-1-1')),
    );
    expect(
      leftPositionTwo.dx,
      greaterThan(courtRect.left + courtRect.width * 0.25),
    );
    expect(
      rightPositionTwo.dx,
      lessThan(courtRect.left + courtRect.width * 0.75),
    );
    expect(
      leftPositionTwo.dy + rightPositionTwo.dy,
      closeTo(courtRect.top + courtRect.bottom, 1),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('rotation-position-1-0'))).dy,
      lessThan(courtCenterY),
    );

    await tester.tap(find.byKey(const ValueKey('rotation-position-0-0')));
    await _pumpUi(tester);
    final reserveTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('choose-player-0-0-reserve')),
    );
    expect(
      reserveTile.tileColor,
      Theme.of(tester.element(find.byType(RotationSetupPage)))
          .colorScheme
          .secondaryContainer,
    );
    await tester.tap(find.byKey(const ValueKey('choose-player-0-0-back')));
    await _pumpUi(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rotation-position-0-0')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rotation-position-0-2')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rotation-position-0-1')));
    await _pumpUi(tester);
    expect(find.text('Position 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('choose-player-0-1-reserve')),
    );
    await _pumpUi(tester);
    expect(find.text('Berta'), findsOneWidget);
    expect(find.text('Bank Blau · 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rotation-position-0-1')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('edit-rotation-number-0-reserve')),
    );
    await _pumpUi(tester);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('rotation-number-input-0-reserve')),
          )
          .initialValue,
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rotation-number-input-0-reserve')),
      '10',
    );
    await tester.tap(
      find.byKey(const ValueKey('save-rotation-number-0-reserve')),
    );
    await _pumpUi(tester);
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rotation-position-0-1')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('send-to-bank-0-1')));
    await _pumpUi(tester);
    expect(find.text('Bank Blau · 1'), findsOneWidget);

    final bankPlayer = find.byKey(
      const ValueKey('rotation-bank-player-0-reserve'),
    );
    final courtPosition = find.byKey(
      const ValueKey('rotation-position-0-0'),
    );
    final dragStart = tester.getCenter(bankPlayer);
    final dragEnd = tester.getCenter(courtPosition);
    await tester.timedDragFrom(
      dragStart,
      dragEnd - dragStart,
      const Duration(milliseconds: 500),
    );
    await _pumpUi(tester);
    expect(find.text('Bank Blau · 1'), findsOneWidget);
    expect(
      find.descendant(of: courtPosition, matching: find.text('10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rotation-bank-player-0-back')),
      findsOneWidget,
    );
  });

  test('scoreboard persists the rotation setup and its progress', () async {
    final database =
        await databaseFactoryMemory.openDatabase('rotation-score.db');
    RotationTeamState team(String prefix) => RotationTeamState(
          players: List<RotationPlayer>.generate(
            3,
            (index) =>
                RotationPlayer(id: '$prefix$index', name: '$prefix$index'),
          ),
          positions: List<String>.generate(3, (index) => '$prefix$index'),
        );
    final rotation = ScoreboardRotationState(
      league: 'U13',
      left: team('l'),
      right: team('r'),
      servingSide: 0,
    );
    final state = ScoreboardState.fromJson(
      <String, dynamic>{
        ...ScoreboardState.initial.toJson(),
        'rotationState': rotation.toJson()
      },
    );
    await ScoreboardRepository(database).save(
      state,
    );
    final loaded = (await ScoreboardRepository(database).load()).rotationState!;
    expect(loaded.left.positions, ['l0', 'l1', 'l2']);
    final afterTwoPoints = loaded.afterPoint(0).afterPoint(0);
    await ScoreboardRepository(database).save(
      ScoreboardState.fromJson(
        <String, dynamic>{
          ...state.toJson(),
          'leftPoints': 2,
          'rotationState': afterTwoPoints.toJson(),
        },
      ),
    );
    final progressed =
        (await ScoreboardRepository(database).load()).rotationState!;
    expect(progressed.left.positions, ['l1', 'l2', 'l0']);
    expect(progressed.consecutiveServePoints, 0);
    expect(loaded.left.positions, ['l0', 'l1', 'l2']);
  });

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

  test('team bundle includes linked records and app-wide board data', () async {
    final database = await databaseFactoryMemory.openDatabase('team-bundle.db');
    const team = Team(
      id: 7,
      name: 'SV Beispiel',
      players: [
        TeamPlayer(
          id: 1,
          name: 'Ada',
          number: 7,
          birthDate: null,
          position: 'Zuspiel',
          profile: '',
          personId: 100,
        ),
      ],
      coaches: [],
    );
    const otherTeam = Team(id: 8, name: 'Team Fremd', players: [], coaches: []);
    await TeamsRepository(database).save([team, otherTeam]);
    await PeopleRepository(database).save(const [
      LocalPerson(id: 100, memberNumber: 1, name: 'Ada'),
      LocalPerson(id: 101, memberNumber: 2, name: 'Gast'),
      LocalPerson(id: 102, memberNumber: 3, name: 'Nicht dabei'),
    ]);
    await MatchStatsRepository(database).save(
      MatchStatsState(
        matches: [
          MatchGame(
            id: 1,
            createdAt: DateTime(2026),
            location: 'Halle',
            opponentTeam: 'Team Rot',
            matchDateTime: DateTime(2026),
            matchTag: '',
            matchType: 'Liga',
            teamId: 7,
            players: const [],
            events: const [],
          ),
          MatchGame(
            id: 2,
            createdAt: DateTime(2026),
            location: 'Halle',
            opponentTeam: 'Team Blau',
            matchDateTime: DateTime(2026),
            matchTag: '',
            matchType: 'Liga',
            teamId: 8,
            players: const [],
            events: const [],
          ),
        ],
      ),
    );
    await StoreRef<String, Map<String, dynamic>>('training')
        .record('sessions')
        .put(database, {
      'sessions': [
        {
          'id': 11,
          'teamId': 7,
          'teamIds': [7],
          'trainingPlanIds': [21],
          'guests': ['Gast'],
          'exercises': [
            {'id': 31},
          ],
        },
        {
          'id': 12,
          'teamId': 8,
          'teamIds': [8],
          'trainingPlanIds': [22],
          'exercises': [
            {'id': 32},
          ],
        },
      ],
    });
    await StoreRef<String, Map<String, dynamic>>('training_plans')
        .record('plans')
        .put(database, {
      'plans': [
        {'id': 21, 'topic': 'Aufschlag'},
        {'id': 22, 'topic': 'Fremder Plan'},
      ],
    });
    await StoreRef<String, Map<String, dynamic>>('training_exercises')
        .record('exercises')
        .put(database, {
      'exercises': [
        {'id': 31, 'title': 'Annahme'},
        {'id': 32, 'title': 'Andere Übung'},
      ],
    });
    await StoreRef<String, Map<String, dynamic>>('scoreboard')
        .record('current')
        .put(database, {'leftPoints': 5});
    await StoreRef<String, Map<String, dynamic>>('scoreboard')
        .record('snapshots')
        .put(database, {
      'items': [
        {'id': 'snapshot-1', 'name': 'Spielstand'},
      ],
    });
    await StoreRef<String, Map<String, dynamic>>('tactics')
        .record('board')
        .put(database, {
      'pages': [
        {'note': 'Aufstellung'},
      ],
      'tactics': [
        {'id': 41, 'name': 'Block'},
      ],
    });

    final bundle = await AppBackupService.buildTeamBundle(database, team);
    List<Map> records(Object? section, String key) =>
        ((section as Map<String, dynamic>)[key] as List).cast<Map>();

    expect(bundle['type'], 'team-bundle');
    expect(bundle['teams'], hasLength(1));
    expect(records(bundle['matchStats'], 'matches').map((item) => item['id']),
        [1]);
    expect(records(bundle['training'], 'sessions').map((item) => item['id']),
        [11]);
    expect(records(bundle['trainingPlans'], 'plans').map((item) => item['id']),
        [21]);
    expect(
        records(bundle['trainingExercises'], 'exercises')
            .map((item) => item['id']),
        [31]);
    expect(records(bundle['people'], 'people').map((item) => item['id']),
        [100, 101]);
    expect(bundle['scoreboard'], isA<Map<String, dynamic>>());
    expect(bundle['tactics'], isA<Map<String, dynamic>>());
  });

  testWidgets('import merge prefers newer records and asks on unknown dates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ready'))),
    );
    final context = tester.element(find.text('ready'));
    final newer = await AppBackupService.mergeImportRecords(
      context,
      [
        {'id': 1, 'name': 'Local', 'updatedAtMillis': 10},
      ],
      [
        {'id': 1, 'name': 'Import', 'updatedAtMillis': 20},
      ],
      kind: 'Testdaten',
    );
    expect(newer.single['name'], 'Import');
    final older = await AppBackupService.mergeImportRecords(
      context,
      [
        {'id': 1, 'name': 'Neu', 'updatedAtMillis': 20},
      ],
      [
        {'id': 1, 'name': 'Alt', 'updatedAtMillis': 10},
      ],
      kind: 'Testdaten',
    );
    expect(older.single['name'], 'Neu');

    final unresolved = AppBackupService.mergeImportRecords(
      context,
      [
        {'id': 1, 'name': 'Vorhanden'},
      ],
      [
        {'id': 1, 'name': 'Import'},
      ],
      kind: 'Team',
    );
    await tester.pumpAndSettle();
    expect(find.text('Doppelte Daten: Team'), findsOneWidget);
    await tester.tap(find.text('Import übernehmen'));
    await tester.pumpAndSettle();
    expect((await unresolved).single['name'], 'Import');
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
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('new-tactic-button')));
    await _pumpUi(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tactic-name-input')),
      'Aufschlag',
    );
    await tester.tap(find.text('Erstellen'));
    await _pumpUi(tester);
    final board = find.byKey(const ValueKey('tactics-board'));
    expect(board, findsOneWidget);
    await tester.tap(board);
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Feld ins Querformat drehen'));
    await _pumpUi(tester);
    expect(find.byTooltip('Feld ins Hochformat drehen'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await _pumpUi(tester);
    await tester.dragFrom(const Offset(200, 300), const Offset(80, 40));
    await _pumpUi(tester);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _pumpUi(tester);
    await tester.dragFrom(const Offset(240, 420), const Offset(-70, 30));
    await _pumpUi(tester);
    await tester.drag(board, const Offset(32, 24));
    await _pumpUi(tester);
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
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('new-tactic-button')));
    await _pumpUi(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tactic-name-input')),
      'Löschen',
    );
    await tester.tap(find.text('Erstellen'));
    await _pumpUi(tester);
    final board = find.byKey(const ValueKey('tactics-board'));
    await tester.tap(find.byIcon(Icons.circle));
    await tester.tap(board, warnIfMissed: false);
    await _pumpUi(tester);
    await tester.tap(find.byIcon(Icons.pan_tool_outlined));
    await tester.tap(board, warnIfMissed: false);
    await _pumpUi(tester);

    expect(
      find.byTooltip('Ausgewähltes Objekt löschen'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _pumpUi(tester);
    await tester.tap(find.text('Löschen').last);
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    expect(blueScore, findsOneWidget);

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.fling(blueScore, const Offset(0, -300), 1000);
    await _pumpUi(tester);
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
    await _pumpUi(tester);

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    expect(
      find.descendant(of: blueScore, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('save-scoreboard-button')));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField), 'Erster Stand');
    await tester.tap(find.text('Speichern'));
    await _pumpUi(tester);

    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    expect(
      find.descendant(of: blueScore, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('load-scoreboard-button')));
    await _pumpUi(tester);
    final savedSnapshot = find.text('Erster Stand');
    await tester.scrollUntilVisible(
      savedSnapshot,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(savedSnapshot);
    await _pumpUi(tester);
    await tester.tap(find.text('Laden'));
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    final setScoreArea = find.byKey(const ValueKey('set-score-area'));
    await tester.fling(setScoreArea, const Offset(300, 0), 1000);
    await _pumpUi(tester);

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
    await _pumpUi(tester);

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
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await _pumpUi(tester);

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    await tester.tap(find.text('Satz beenden'));
    await _pumpUi(tester);

    expect(
      find.descendant(of: blueScore, matching: find.text('0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: blueSet, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.fling(blueSet, const Offset(0, -300), 1000);
    await _pumpUi(tester);

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
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    expect(find.text('Auszeit beenden?'), findsOneWidget);
    await tester.tap(find.text('Zurücknehmen'));
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    expect(find.text('Auszeit beenden?'), findsOneWidget);
    await tester.tap(find.text('Beenden'));
    await _pumpUi(tester);

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
    await _pumpUi(tester);
    await tester.tap(find.text('Beenden'));
    await _pumpUi(tester);

    expect(
      find.descendant(
        of: blueTimeout,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(blueTimeout);
    await _pumpUi(tester);
    expect(find.text('Auszeit beenden?'), findsNothing);

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    await tester.tap(find.text('Satz beenden'));
    await _pumpUi(tester);

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
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ScoreboardPage(database: database),
      ),
    );
    await _pumpUi(tester);

    final setupButton = find.byKey(const ValueKey('rotation-setup-button'));
    expect(setupButton, findsOneWidget);
    expect(tester.getCenter(setupButton).dy, lessThan(60));

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

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUi(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: ScoreboardPage(database: database),
      ),
    );
    await _pumpUi(tester);
    final androidSetupButton =
        find.byKey(const ValueKey('rotation-setup-button'));
    expect(androidSetupButton, findsOneWidget);
    expect(tester.getCenter(androidSetupButton).dy, lessThan(100));
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
    await _pumpUi(tester);

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
    await _pumpUi(tester);

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
    await _pumpUi(tester);

    final blueScore = find.byKey(const ValueKey('blau-score-panel'));
    await tester.fling(blueScore, const Offset(0, 300), 1000);
    await _pumpUi(tester);

    final blueSet = find.byKey(const ValueKey('blau-set-panel'));
    await tester.fling(blueSet, const Offset(0, 300), 1000);
    await _pumpUi(tester);
    await tester.tap(find.text('Satz beenden'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('history-appbar-button')));
    await _pumpUi(tester);

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

  testWidgets('long press selects multiple scorers in the player picker', (
    WidgetTester tester,
  ) async {
    List<MatchPlayer>? selectedPlayers;
    var multiSelectStarted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MatchScorerSelectionView(
          players: const [
            MatchPlayer(id: 1, name: 'Ada', number: 7),
            MatchPlayer(id: 2, name: 'Berta', number: 8),
          ],
          countdownProgress: 0.5,
          displayPlayerName: (player) => player.name,
          onBack: () {},
          onBookUnknown: () {},
          onSelectSpecial: (_) {},
          onSelectPlayer: (_) {},
          onSelectPlayers: (players) => selectedPlayers = players,
          onMultiSelectStarted: () => multiSelectStarted = true,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );

    await tester.longPress(find.byKey(const ValueKey('select-player-1')));
    await tester.pump();
    expect(multiSelectStarted, isTrue);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('select-multiple-player-1')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('select-player-2')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('select-multiple-player-2')),
          )
          .value,
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('continue-multi-scorer-selection')),
    );
    await tester.pump();
    expect(selectedPlayers?.map((player) => player.id), [1, 2]);
  });

  test('one scoring event can credit multiple players', () {
    final event = MatchEvent(
      id: 1,
      playerId: 1,
      playerIds: const [1, 2],
      playerName: 'Ada, Berta',
      playerNumber: 7,
      kind: 'point',
      category: 'Block',
      occurredAt: DateTime(2026, 10, 1, 18),
    );
    final restored = MatchEvent.fromJson(event.toJson());

    expect(restored.scorerIds, [1, 2]);
    final match = MatchGame(
      id: 42,
      createdAt: DateTime(2026, 10, 1),
      location: '',
      opponentTeam: 'Team Blau',
      matchDateTime: DateTime(2026, 10, 1, 18),
      matchTag: '',
      matchType: 'Liga',
      players: const [
        MatchPlayer(id: 1, name: 'Ada', number: 7),
        MatchPlayer(id: 2, name: 'Berta', number: 8),
      ],
      events: [restored],
    );
    final combined = combineMatchesForStatistics([match]);

    expect(combined.events, hasLength(1));
    expect(combined.events.single.scorerIds, [1, 2]);
  });

  test('substitution events retain both player identities', () {
    final event = MatchEvent(
      id: 3,
      playerId: 2,
      playerName: 'Berta',
      playerNumber: 8,
      kind: 'substitution',
      category: 'Spielerwechsel',
      occurredAt: DateTime(2026, 10, 1, 18),
      rotationPosition: 3,
      replacedPlayerId: 1,
      replacedPlayerName: 'Ada',
      replacedPlayerNumber: 7,
    );
    final restored = MatchEvent.fromJson(event.toJson());
    final match = MatchGame(
      id: 43,
      createdAt: DateTime(2026, 10, 1),
      location: '',
      opponentTeam: 'Team Blau',
      matchDateTime: DateTime(2026, 10, 1, 18),
      matchTag: '',
      matchType: 'Liga',
      players: const [
        MatchPlayer(id: 1, name: 'Ada', number: 7),
        MatchPlayer(id: 2, name: 'Berta', number: 8),
      ],
      events: [restored],
    );

    expect(restored.replacedPlayerId, 1);
    expect(restored.replacedPlayerName, 'Ada');
    expect(restored.replacedPlayerNumber, 7);
    final combined = combineMatchesForStatistics([match]);
    expect(combined.events.single.replacedPlayerName, 'Ada');
    expect(combined.events.single.replacedPlayerNumber, 7);
  });

  testWidgets(
      'Match statistics page allows creating a match and recording a point', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test4.db');
    await tester
        .pumpWidget(MaterialApp(home: MatchStatsPage(database: database)));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('new-game-button')));
    await _pumpUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('match-location-input')),
      'Halle A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('match-opponent-input')),
      'Team B',
    );
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _pumpUi(tester);
    await tester.tap(find.text('Spielbericht'));
    await _pumpUi(tester);
    final matchReport = find.byKey(const ValueKey('match-report-input'));
    await tester.enterText(matchReport, 'Starker Auftakt, hart umkämpft.');
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Zur Spielübersicht'));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await _pumpUi(tester);
    expect(find.text('Export'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await _pumpUi(tester);
    await tester.tap(find.text('Punktewertung'));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('scoring-more-menu')));
    await _pumpUi(tester);
    await tester.tap(find.text('Spielbericht'));
    await _pumpUi(tester);
    expect(
      tester.widget<TextField>(matchReport).controller?.text,
      'Starker Auftakt, hart umkämpft.',
    );
    await tester.tap(find.byTooltip('Zur Punktewertung'));
    await _pumpUi(tester);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _pumpUi(tester);
    await tester.tap(find.text('Spielinfos'));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await _pumpUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('player-name-input')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('player-number-input')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('add-player-button')));
    await _pumpUi(tester);
    final editPlayerButton = find.byTooltip('Spieler bearbeiten');
    await tester.ensureVisible(editPlayerButton);
    await tester.tap(editPlayerButton);
    await _pumpUi(tester);
    await tester.enterText(
      find.byKey(const ValueKey('player-name-input')),
      'Ada Neu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('player-number-input')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('add-player-button')));
    await _pumpUi(tester);
    expect(find.text('Ada Neu'), findsOneWidget);
    expect(find.text('Trikot 9'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await _pumpUi(tester);
    await tester.tap(find.text('Punktewertung'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('select-category-Aufschlag')),
    );
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('select-category-Aufschlag-Ass')),
    );
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('player-name-input')), findsNothing);
    final redoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('redo-last-match-action')),
    );
    expect(redoButton.onPressed, isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpUi(tester);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('redo-last-match-action')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpUi(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('redo-last-match-action')));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-category-Block')));
    await tester.pump(const Duration(seconds: 7));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('record-error-button')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('select-category-Annahme')),
    );
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await tester.pump(const Duration(seconds: 7));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-error-button')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('select-category-Annahme')),
    );
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-scorer-team')));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('select-category-Annahme-Absprache'),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-category-Sonstiges')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Punkt nach Abwehr');
    await tester.tap(find.text('Weiter'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-category-Sonstiges')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await _pumpUi(tester);
    final recentDetail = find.byKey(
      const ValueKey('recent-other-detail-Punkt nach Abwehr'),
    );
    expect(recentDetail, findsOneWidget);
    await tester.tap(recentDetail);
    await _pumpUi(tester);
    expect(find.text('Sonstiges beschreiben'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('record-error-button')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-category-Aufschlag')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-scorer-team')));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('select-category-Aufschlag-Sonstiges')),
    );
    await _pumpUi(tester);
    expect(find.text('Sonstiges beschreiben'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).last, 'Fehler beim Aufschlag');
    await tester.tap(find.text('Weiter'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-error-button')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-category-Zuspiel')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('select-scorer-team')));
    await _pumpUi(tester);
    expect(find.byKey(const ValueKey('select-category-Zuspiel-Absprache')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('select-category-Zuspiel-Unteres Zuspiel')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('select-category-Zuspiel-Oberes Zuspiel')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('select-category-Zuspiel-Oberes Zuspiel')));
    await _pumpUi(tester);

    final finishSet = find.byKey(const ValueKey('finish-set-button'));
    await tester.ensureVisible(finishSet);
    await tester.tap(finishSet);
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('match-history-appbar-button')));
    await _pumpUi(tester);

    expect(find.text('Verlauf'), findsOneWidget);
    expect(
      find.text('Mannschaft  •  Zuspiel · Oberes Zuspiel'),
      findsOneWidget,
    );
    expect(find.text('Ada Neu  •  Annahme'), findsOneWidget);
    expect(find.text('1 abgeschlossene Sätze'), findsOneWidget);
    expect(find.text('Satzende'), findsOneWidget);
    final editPoint = find.byKey(const ValueKey('edit-match-event-1'));
    await tester.ensureVisible(editPoint);
    await tester.tap(editPoint);
    await _pumpUi(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'Aufschlag · Scharf',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await _pumpUi(tester);
    await tester.tap(find.text('Mannschaft').last);
    await _pumpUi(tester);
    await tester.tap(find.text('Speichern'));
    await _pumpUi(tester);
    expect(
      find.text('Mannschaft  •  Aufschlag · Scharf'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('edit-last-booking')));
    await _pumpUi(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'Letzte Buchung angepasst',
    );
    await tester.tap(find.text('Speichern'));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('match-history-appbar-button')));
    await _pumpUi(tester);
    expect(
        find.text('Mannschaft  •  Letzte Buchung angepasst'), findsOneWidget);
  });

  testWidgets('statistics export button is named Export', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('pdf-option.db');
    await tester.pumpWidget(
      MaterialApp(home: MatchStatsPage(database: database)),
    );
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('new-game-button')));
    await _pumpUi(tester);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _pumpUi(tester);
    await tester.tap(find.text('Statistik'));
    await _pumpUi(tester);
    final exportButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('export-match-stats-pdf')),
    );
    expect(exportButton.tooltip, 'Export');
    expect(exportButton.onPressed, isNotNull);
    expect(find.text('Hochformat'), findsNothing);
    expect(find.text('Querformat'), findsNothing);
    expect(find.text('Fortlaufend im Querformat'), findsNothing);
  });

  testWidgets('Point scoring can record opponent error without player', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('test5.db');
    await tester
        .pumpWidget(MaterialApp(home: MatchStatsPage(database: database)));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('new-game-button')));
    await _pumpUi(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.tap(find.text('Punktewertung'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('record-point-button')));
    await _pumpUi(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await _pumpUi(tester);
    await tester
        .tap(find.byKey(const ValueKey('select-category-Gegnerfehler')));
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('select-player-1')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.tap(find.text('Statistik'));
    await _pumpUi(tester);

    expect(find.text('Gegnerfehler'), findsWidgets);
    final zoomIn = find.byTooltip('Zeitachse nach rechts erweitern');
    expect(zoomIn, findsOneWidget);
    const viewportKey = ValueKey('trend-chart-scroll-Zeitverlauf gesamt');
    const contentKey = ValueKey('trend-chart-content-Zeitverlauf gesamt');
    final viewportWidth = tester.getSize(find.byKey(viewportKey)).width;
    final initialContentSize = tester.getSize(find.byKey(contentKey));
    for (var step = 0; step < 5; step++) {
      await tester.tap(zoomIn);
      await tester.pump();
    }
    final expandedContentSize = tester.getSize(find.byKey(contentKey));
    expect(initialContentSize.width, closeTo(viewportWidth, 1));
    expect(expandedContentSize.width, greaterThan(viewportWidth * 4));
    expect(expandedContentSize.height, initialContentSize.height);

    final chartScrollable = find.descendant(
      of: find.byKey(viewportKey),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(chartScrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.ensureVisible(find.byKey(viewportKey));
    await tester.pump();
    await tester.drag(find.byKey(viewportKey), const Offset(-120, 0));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(chartScrollable).position.pixels,
      greaterThan(0),
    );
  });

  test('multiselect trend charts allow more time-axis expansion', () {
    expect(trendChartMaxTimeScale(2), 16);
    expect(trendChartMaxTimeScale(100), 25);
    expect(trendChartMaxTimeScale(1000), 64);
  });

  test('multiselect trend timeline removes gaps between match ranges', () {
    final firstStart = DateTime(2026, 9, 1, 18);
    final firstEnd = DateTime(2026, 9, 1, 18, 30);
    final secondStart = DateTime(2026, 9, 8, 22);
    final secondEnd = DateTime(2026, 9, 8, 22, 45);
    final ranges = [
      MatchTimeRange(start: firstStart, end: firstEnd),
      MatchTimeRange(start: secondStart, end: secondEnd),
    ];

    expect(
      compressedMatchTimelinePosition(firstEnd, ranges),
      compressedMatchTimelinePosition(secondStart, ranges),
    );
    expect(
      compressedMatchTimelinePosition(secondEnd, ranges) -
          compressedMatchTimelinePosition(firstStart, ranges),
      const Duration(minutes: 75).inMilliseconds,
    );
  });

  test('multiselect player trend stays flat during matches they did not score',
      () {
    MatchEvent point(int id, int playerId, DateTime time) => MatchEvent(
          id: id,
          playerId: playerId,
          playerName: playerId == 1 ? 'Ada' : 'Berta',
          playerNumber: playerId == 1 ? 7 : 8,
          kind: 'point',
          category: 'Block',
          occurredAt: time,
        );
    MatchGame match({
      required int id,
      required DateTime date,
      required List<MatchPlayer> players,
      required List<MatchEvent> events,
    }) =>
        MatchGame(
          id: id,
          createdAt: date,
          location: '',
          opponentTeam: 'Team $id',
          matchDateTime: date,
          matchTag: '',
          matchType: 'Liga',
          players: players,
          events: events,
        );

    final firstMatchTime = DateTime(2026, 10, 1, 18);
    final secondMatchTime = DateTime(2026, 10, 8, 20);
    final matches = [
      match(
        id: 1,
        date: firstMatchTime,
        players: const [MatchPlayer(id: 1, name: 'Ada', number: 7)],
        events: [point(1, 1, firstMatchTime)],
      ),
      match(
        id: 2,
        date: secondMatchTime,
        players: const [MatchPlayer(id: 2, name: 'Berta', number: 8)],
        events: [point(1, 2, secondMatchTime)],
      ),
    ];
    final combined = combineMatchesForStatistics(matches);
    final ada = combined.players.singleWhere((player) => player.name == 'Ada');

    final samples = matchPlayerTrendSamples(combined, matches, ada.id);

    expect(samples, hasLength(6));
    expect(samples.map((sample) => sample.points), [0, 1, 1, 1, 1, 1]);
    expect(samples.map((sample) => sample.matchIndex), [0, 0, 0, 1, 1, 1]);
    expect(samples.map((sample) => sample.beginsMatch), [
      true,
      false,
      false,
      true,
      false,
      false,
    ]);
    expect(samples[3].time, secondMatchTime);
    expect(samples.last.time, secondMatchTime.add(const Duration(minutes: 1)));
  });

  test('legacy receive error categories load without the word error', () {
    final event = MatchEvent.fromJson({
      'id': 1,
      'playerId': 1,
      'playerName': 'Ada',
      'playerNumber': 7,
      'kind': 'error',
      'category': 'Annahmefehler · Obere Annahme',
      'occurredAtMillis': DateTime(2026).millisecondsSinceEpoch,
    });

    expect(event.category, 'Annahme · Obere Annahme');
  });

  test('match set results include auto, manual, and ongoing sets', () {
    var eventId = 0;
    final events = <MatchEvent>[];
    void addScoringEvents(String kind, int count) {
      for (var index = 0; index < count; index++) {
        eventId++;
        events.add(
          MatchEvent(
            id: eventId,
            playerId: null,
            playerName: '',
            playerNumber: 0,
            kind: kind,
            category: '',
            occurredAt: DateTime(2026, 10, 1).add(
              Duration(seconds: eventId),
            ),
          ),
        );
      }
    }

    addScoringEvents('error', 20);
    addScoringEvents('point', 25);
    addScoringEvents('error', 19);
    addScoringEvents('point', 15);
    eventId++;
    events.add(
      MatchEvent(
        id: eventId,
        playerId: null,
        playerName: 'Satzende',
        playerNumber: 0,
        kind: 'manual_set_end',
        category: 'Manuell',
        occurredAt: DateTime(2026, 10, 1).add(Duration(seconds: eventId)),
      ),
    );
    addScoringEvents('error', 1);
    addScoringEvents('point', 4);
    final match = MatchGame(
      id: 61,
      createdAt: DateTime(2026, 10, 1),
      location: 'Halle',
      opponentTeam: 'Team Beispiel',
      matchDateTime: DateTime(2026, 10, 1, 18),
      matchTag: '',
      matchType: 'Liga',
      players: const [],
      events: events,
    );

    final sets = computeMatchSetResults(match);

    expect(sets.map((set) => '${set.us}:${set.opponent}'), [
      '25:20',
      '15:19',
      '4:1',
    ]);
    expect(sets.map((set) => set.isFinished), [true, true, false]);
    expect(
      sets.where((set) => set.isFinished && set.us > set.opponent).length,
      1,
    );
    expect(
      sets.where((set) => set.isFinished && set.opponent > set.us).length,
      1,
    );
  });

  test('recent Other details are deduplicated and newest first', () {
    MatchEvent otherDetail(int id, String detail, int minute) => MatchEvent(
          id: id,
          playerId: -1,
          playerName: 'Unbekannt',
          playerNumber: 0,
          kind: 'point',
          category: 'Sonstiges: $detail',
          occurredAt: DateTime(2026, 9, 1, 12, minute),
        );
    MatchGame game(List<MatchEvent> events) => MatchGame(
          id: 1,
          createdAt: DateTime(2026, 9, 1),
          location: '',
          opponentTeam: '',
          matchDateTime: DateTime(2026, 9, 1),
          matchTag: '',
          matchType: 'Liga',
          players: const [],
          events: events,
        );

    final recent = recentOtherCategoryDetails([
      game([
        otherDetail(1, 'Erster Ball', 1),
        otherDetail(2, 'Kurzer Ball', 2),
        MatchEvent(
          id: 5,
          playerId: -1,
          playerName: 'Unbekannt',
          playerNumber: 0,
          kind: 'point',
          category: 'Angriff · Sonstiges: Glück',
          occurredAt: DateTime(2026, 9, 1, 12, 5),
        ),
      ]),
      game([
        otherDetail(3, 'erster ball', 3),
        otherDetail(4, 'Punkt nach Rally', 4),
      ]),
    ]);

    expect(recent, ['Glück', 'Punkt nach Rally', 'erster ball', 'Kurzer Ball']);

    final lastTen = recentOtherCategoryDetails([
      game([
        for (var minute = 0; minute < 12; minute++)
          otherDetail(minute, 'Text $minute', minute),
      ]),
    ]);
    expect(lastTen, hasLength(10));
    expect(lastTen.first, 'Text 11');
    expect(lastTen.last, 'Text 2');
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
      matchReport: 'Starker Start, knappes Ende.',
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
    expect(restored.matchReport, 'Starker Start, knappes Ende.');
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

  test('Match persists its starting rotation setup', () {
    final match = MatchGame(
      id: 2,
      createdAt: DateTime(2026),
      location: '',
      opponentTeam: '',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      league: 'U13',
      rotationIsOnLeft: false,
      players: const [],
      events: const [],
      rotationSetup: const ScoreboardRotationState(
        league: 'U13',
        left: RotationTeamState(
          players: [RotationPlayer(id: 'match-1', name: 'Ada', number: 7)],
          positions: ['match-1', null, null],
        ),
        right: RotationTeamState(),
        servingSide: 1,
      ),
    );

    final restored = MatchGame.fromJson(match.toJson());

    expect(restored.rotationSetup?.league, 'U13');
    expect(restored.rotationSetup?.left.positions, ['match-1', null, null]);
    expect(restored.rotationSetup?.servingSide, 1);
    expect(restored.rotationIsOnLeft, isFalse);
  });

  test('scoring only offers players currently on court', () {
    final match = MatchGame(
      id: 9,
      createdAt: DateTime(2026),
      location: '',
      opponentTeam: '',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      league: 'U13',
      players: const [
        MatchPlayer(id: 1, name: 'Ada', number: 7),
        MatchPlayer(id: 2, name: 'Berta', number: 4),
        MatchPlayer(id: 3, name: 'Mara', number: 5),
        MatchPlayer(id: 4, name: 'Eva', number: 12),
      ],
      events: const [],
      rotationSetup: const ScoreboardRotationState(
        league: 'U13',
        left: RotationTeamState(
          players: [
            RotationPlayer(id: 'match-1', name: 'Ada', number: 7),
            RotationPlayer(id: 'match-2', name: 'Berta', number: 4),
            RotationPlayer(id: 'match-3', name: 'Mara', number: 5),
            RotationPlayer(id: 'match-4', name: 'Eva', number: 12),
          ],
          positions: ['match-1', 'match-2', 'match-3'],
        ),
        right: RotationTeamState(),
        servingSide: 0,
      ),
    );

    expect(fieldPlayersForScoring(match).map((player) => player.id), [1, 2, 3]);
  });

  test('team jersey number sync updates match and rotation roster', () {
    final match = MatchGame(
      id: 10,
      createdAt: DateTime(2026),
      location: '',
      opponentTeam: '',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      teamId: 3,
      players: const [
        MatchPlayer(
          id: 1,
          name: 'Ada',
          number: 7,
          teamPlayerId: 4,
          sourceTeamId: 3,
        ),
        MatchPlayer(id: 2, name: 'Manual', number: 9),
      ],
      events: const [],
      rotationSetup: const ScoreboardRotationState(
        league: 'U13',
        left: RotationTeamState(
          players: [
            RotationPlayer(id: 'match-1', name: 'Ada', number: 7),
            RotationPlayer(id: 'match-2', name: 'Manual', number: 9),
          ],
          positions: ['match-1', 'match-2', null],
        ),
        right: RotationTeamState(),
        servingSide: 0,
      ),
    );
    const team = Team(
      id: 3,
      name: 'Team',
      players: [
        TeamPlayer(
          id: 4,
          name: 'Ada',
          number: 15,
          birthDate: null,
          position: '',
          profile: '',
        ),
      ],
      coaches: [],
    );

    final synced = syncMatchPlayerNumbersFromTeam(match, team);

    expect(synced.players.map((player) => player.number), [15, 9]);
    expect(synced.rotationSetup?.left.players.first.number, 15);
    expect(synced.rotationSetup?.left.players.last.number, 9);
  });

  test('match statistics export builds a PDF with chart data', () async {
    final match = MatchGame(
      id: 7,
      createdAt: DateTime(2026, 6, 1),
      location: 'Halle',
      opponentTeam: 'Team Rot',
      matchDateTime: DateTime(2026, 6, 1, 18),
      matchTag: '',
      matchType: 'Liga',
      matchReport: 'Schneller Start und starke Abwehr.',
      players: const [MatchPlayer(id: 1, name: 'Ada', number: 7)],
      events: [
        MatchEvent(
          id: 1,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'point',
          category: 'Aufschlag · Ass',
          occurredAt: DateTime(2026, 6, 1, 18),
        ),
        MatchEvent(
          id: 2,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'error',
          category: 'Annahme · Zugeschaut',
          occurredAt: DateTime(2026, 6, 1, 18, 5),
        ),
        MatchEvent(
          id: 3,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'point',
          category: 'Angriff',
          occurredAt: DateTime(2026, 6, 1, 18, 6),
        ),
        MatchEvent(
          id: 4,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'error',
          category: 'Aufschlag · Ball ins Netz',
          occurredAt: DateTime(2026, 6, 1, 18, 7),
        ),
      ],
    );
    final secondMatch = MatchGame(
      id: 8,
      createdAt: DateTime(2026, 6, 2),
      location: 'Halle B',
      opponentTeam: 'Team Blau',
      matchDateTime: DateTime(2026, 6, 2, 19),
      matchTag: '',
      matchType: 'Turnier',
      matchReport: 'Entscheidung im letzten Satz.',
      players: const [MatchPlayer(id: 2, name: 'Berta', number: 8)],
      events: [
        MatchEvent(
          id: 1,
          playerId: null,
          playerName: 'Gegner',
          playerNumber: 0,
          kind: 'point',
          category: 'Gegnerfehler',
          occurredAt: DateTime(2026, 6, 2, 19),
        ),
      ],
    );
    final selectedMatches = [secondMatch, match];
    final combinedMatch = combineMatchesForStatistics(selectedMatches);

    final bytes = await AppBackupService.buildMatchStatsPdf(
      combinedMatch,
      title: 'Statistik · 2 Spiele',
      sourceMatches: selectedMatches,
    );
    final summaryOnlyBytes = await AppBackupService.buildMatchStatsPdf(
      combinedMatch,
      title: 'Statistik · 2 Spiele',
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    final exportedMatches =
        AppBackupService.buildMatchesBackup(selectedMatches)['matches'] as List;
    expect(
      exportedMatches
          .map((entry) => (entry as Map<String, dynamic>)['opponentTeam']),
      ['Team Rot', 'Team Blau'],
    );
    int pageCount(List<int> pdfBytes) => RegExp(r'/Type\s*/Page\b')
        .allMatches(String.fromCharCodes(pdfBytes))
        .length;
    expect(pageCount(bytes), greaterThan(pageCount(summaryOnlyBytes)));
    final continuousBytes = await AppBackupService.buildMatchStatsPdf(
      combinedMatch,
      title: 'Statistik · 2 Spiele',
      sourceMatches: selectedMatches,
      landscape: true,
      continuous: true,
    );
    expect(pageCount(continuousBytes), 1);
    final continuousPageBox = RegExp(
      r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
    ).firstMatch(String.fromCharCodes(continuousBytes));
    expect(continuousPageBox, isNotNull);
    expect(
      double.parse(continuousPageBox!.group(1)!),
      greaterThan(800),
    );
    expect(
      double.parse(continuousPageBox.group(2)!),
      greaterThan(double.parse(continuousPageBox.group(1)!)),
    );

    final singleMatchBytes = await AppBackupService.buildMatchStatsPdf(
      match,
      title: 'Statistik · Team Rot',
    );
    expect(singleMatchBytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    final landscapeBytes = await AppBackupService.buildMatchStatsPdf(
      match,
      title: 'Statistik · Team Rot',
      landscape: true,
    );
    expect(landscapeBytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(landscapeBytes, isNot(singleMatchBytes));

    final historyMatch = match.copyWith(
      matchReport: 'Starker Auftakt, hart umkämpft.',
      events: [
        ...match.events,
        MatchEvent(
          id: 5,
          playerId: 2,
          playerName: 'Berta',
          playerNumber: 8,
          kind: 'substitution',
          category: 'Spielerwechsel',
          occurredAt: DateTime(2026, 6, 1, 18, 8),
          rotationPosition: 3,
          replacedPlayerId: 1,
          replacedPlayerName: 'Ada',
          replacedPlayerNumber: 7,
        ),
      ],
    );
    final historyBytes =
        await AppBackupService.buildMatchHistoryPdf(historyMatch);
    expect(historyBytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(historyBytes.length, greaterThan(1000));
    expect(pageCount(historyBytes), 1);
    final historyPageBox = RegExp(
      r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
    ).firstMatch(String.fromCharCodes(historyBytes));
    expect(historyPageBox, isNotNull);
    expect(
      double.parse(historyPageBox!.group(1)!),
      greaterThan(double.parse(historyPageBox.group(2)!)),
    );
    final completeBytes = await AppBackupService.buildMatchStatsPdf(
      historyMatch,
      title: 'Gesamtexport · Team Rot',
      includeFullMatchDetails: true,
      landscape: true,
      continuous: true,
    );
    final continuousStatsBytes = await AppBackupService.buildMatchStatsPdf(
      match,
      title: 'Statistik · Team Rot',
      landscape: true,
      continuous: true,
    );
    expect(completeBytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(completeBytes.length, greaterThan(continuousStatsBytes.length));
    expect(pageCount(completeBytes), 1);
    final completeMultiBytes = await AppBackupService.buildMatchStatsPdf(
      combinedMatch,
      title: 'Gesamtexport · 2 Spiele',
      sourceMatches: selectedMatches,
      includeFullMatchDetails: true,
      landscape: true,
      continuous: true,
    );
    expect(pageCount(completeMultiBytes), 1);
    expect(completeMultiBytes.length, greaterThan(continuousBytes.length));
  });

  test('match rotation follows scored point events', () {
    final match = MatchGame(
      id: 4,
      createdAt: DateTime(2026),
      location: 'Halle',
      opponentTeam: 'Team Rot',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      league: 'U13',
      players: const [
        MatchPlayer(id: 1, name: 'Ada', number: 7),
        MatchPlayer(id: 2, name: 'Berta', number: 4),
        MatchPlayer(id: 3, name: 'Mara', number: 5),
      ],
      events: [
        MatchEvent(
          id: 1,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'point',
          category: 'Ass',
          occurredAt: DateTime(2026, 1, 1, 12),
        ),
      ],
      rotationSetup: const ScoreboardRotationState(
        league: 'U13',
        left: RotationTeamState(
          name: 'Eigenes Team',
          players: [
            RotationPlayer(id: 'match-1', name: 'Ada', number: 7),
            RotationPlayer(id: 'match-2', name: 'Berta', number: 4),
            RotationPlayer(id: 'match-3', name: 'Mara', number: 5),
          ],
          positions: ['match-1', 'match-2', 'match-3'],
        ),
        right: RotationTeamState(),
        servingSide: 1,
      ),
    );
    final currentRotation = rotationAfterMatchEvents(match);

    expect(currentRotation?.left.positions, [
      'match-2',
      'match-3',
      'match-1',
    ]);
    expect(currentRotation?.servingSide, 0);
  });

  test('undo replays match points and substitutions back to prior rotation',
      () {
    final match = MatchGame(
      id: 8,
      createdAt: DateTime(2026),
      location: '',
      opponentTeam: 'Team Rot',
      matchDateTime: DateTime(2026),
      matchTag: '',
      matchType: 'Liga',
      league: 'U13',
      players: const [],
      events: [
        MatchEvent(
          id: 1,
          playerId: 1,
          playerName: 'Ada',
          playerNumber: 7,
          kind: 'point',
          category: 'Ass',
          occurredAt: DateTime(2026, 7, 1, 12),
        ),
        MatchEvent(
          id: 2,
          playerId: 4,
          playerName: 'Eva',
          playerNumber: 12,
          kind: 'substitution',
          category: 'Spielerwechsel',
          occurredAt: DateTime(2026, 7, 1, 12, 1),
          rotationPosition: 0,
        ),
      ],
      rotationSetup: const ScoreboardRotationState(
        league: 'U13',
        left: RotationTeamState(
          players: [
            RotationPlayer(id: 'match-1', name: 'Ada', number: 7),
            RotationPlayer(id: 'match-2', name: 'Berta', number: 4),
            RotationPlayer(id: 'match-3', name: 'Mara', number: 5),
            RotationPlayer(id: 'match-4', name: 'Eva', number: 12),
          ],
          positions: ['match-1', 'match-2', 'match-3'],
        ),
        right: RotationTeamState(),
        servingSide: 1,
      ),
    );

    final afterSubstitution = rotationAfterMatchEvents(match);
    final afterUndoSubstitution =
        rotationAfterMatchEvents(undoLastMatchAction(match));
    final afterUndoPoint = rotationAfterMatchEvents(
        undoLastMatchAction(undoLastMatchAction(match)));

    expect(afterSubstitution?.left.positions, [
      'match-4',
      'match-3',
      'match-1',
    ]);
    expect(afterUndoSubstitution?.left.positions, [
      'match-2',
      'match-3',
      'match-1',
    ]);
    expect(afterUndoPoint?.left.positions, ['match-1', 'match-2', 'match-3']);
    expect(undoLastMatchAction(undoLastMatchAction(match)).events, isEmpty);
  });

  testWidgets('match rotation view mirrors its single team court', (
    WidgetTester tester,
  ) async {
    const teamColor = Color(0xFF008577);
    const rotation = ScoreboardRotationState(
      league: 'U13',
      left: RotationTeamState(
        players: [
          RotationPlayer(id: 'one', name: 'Ada', number: 7),
          RotationPlayer(id: 'two', name: 'Berta', number: 4),
          RotationPlayer(id: 'three', name: 'Mara', number: 5),
        ],
        positions: ['one', 'two', 'three'],
      ),
      right: RotationTeamState(),
      servingSide: 0,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: MatchRotationView(
                rotation: rotation,
                teamName: 'SV Beispiel',
                teamColor: teamColor,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('match-rotation-court')), findsOneWidget);
    final courtSize = tester.getSize(
      find.byKey(const ValueKey('match-rotation-court')),
    );
    expect(courtSize.width, courtSize.height);
    expect(find.byKey(const ValueKey('match-rotation-position-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('match-rotation-position-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('match-rotation-position-2')),
        findsOneWidget);
    final playerDecoration = tester
        .widget<Container>(
          find.byKey(const ValueKey('match-rotation-player-0')),
        )
        .decoration as BoxDecoration;
    expect(playerDecoration.shape, BoxShape.circle);
    expect(playerDecoration.color, teamColor);
    expect(
      (tester
              .widget<Container>(
                find.byKey(const ValueKey('match-rotation-position-badge-0')),
              )
              .decoration as BoxDecoration)
          .color,
      teamColor,
    );
    final courtRect = tester.getRect(
      find.byKey(const ValueKey('match-rotation-court')),
    );
    final positionTwoBefore = tester.getCenter(
      find.byKey(const ValueKey('match-rotation-player-1')),
    );
    expect(positionTwoBefore.dx,
        greaterThan(courtRect.left + courtRect.width * 2 / 3));
    final playerBefore = tester.getCenter(
      find.byKey(const ValueKey('match-rotation-player-0')),
    );

    await tester.tap(find.text('Rechts'));
    await tester.pump();
    final playerAfter = tester.getCenter(
      find.byKey(const ValueKey('match-rotation-player-0')),
    );
    expect(
      (playerBefore.dx + playerAfter.dx) / 2,
      closeTo(courtRect.center.dx, 1),
    );
    expect(playerBefore.dy, greaterThan(courtRect.center.dy));
    expect(playerAfter.dy, lessThan(courtRect.center.dy));
    final positionTwoAfter = tester.getCenter(
      find.byKey(const ValueKey('match-rotation-player-1')),
    );
    expect(positionTwoAfter.dx, lessThan(courtRect.left + courtRect.width / 3));
    expect(find.byKey(const ValueKey('match-rotation-court')), findsOneWidget);
  });

  test('selected matches combine player and event totals', () {
    final matches = [
      MatchGame(
        id: 1,
        createdAt: DateTime(2026, 5, 1),
        location: 'Halle A',
        opponentTeam: 'Team Eins',
        matchDateTime: DateTime(2026, 5, 1),
        matchTag: '',
        matchType: 'Liga',
        players: const [MatchPlayer(id: 1, name: 'Ada', number: 7)],
        events: [
          MatchEvent(
            id: 1,
            playerId: 1,
            playerName: 'Ada',
            playerNumber: 7,
            kind: 'point',
            category: 'Ass',
            occurredAt: DateTime(2026, 5, 1, 12),
          ),
        ],
      ),
      MatchGame(
        id: 2,
        createdAt: DateTime(2026, 5, 2),
        location: 'Halle B',
        opponentTeam: 'Team Zwei',
        matchDateTime: DateTime(2026, 5, 2),
        matchTag: '',
        matchType: 'Turnier',
        players: const [MatchPlayer(id: 1, name: 'Ada', number: 7)],
        events: [
          MatchEvent(
            id: 1,
            playerId: 1,
            playerName: 'Ada',
            playerNumber: 7,
            kind: 'error',
            category: 'Aufschlag',
            occurredAt: DateTime(2026, 5, 2, 12),
          ),
        ],
      ),
    ];
    final combined = combineMatchesForStatistics(matches);

    expect(combined.opponentTeam, '2 Spiele');
    expect(combined.players, hasLength(1));
    expect(combined.players.single.name, 'Ada');
    expect(combined.events, hasLength(2));
    expect(combined.events.map((event) => event.kind), ['point', 'error']);
    expect(combined.events.map((event) => event.playerId), [1, 1]);

    final backup = AppBackupService.buildMatchesBackup(matches);
    expect(backup['type'], 'matches');
    expect(backup['matches'], hasLength(2));

    final unrelated = MatchGame(
      id: 3,
      createdAt: DateTime(2026, 4, 1),
      location: '',
      opponentTeam: 'Unverändert',
      matchDateTime: DateTime(2026, 4, 1),
      matchTag: '',
      matchType: 'Liga',
      players: const [],
      events: const [],
    );
    final merged = AppBackupService.mergeMatchesById(
      [unrelated, matches.first.copyWith(opponentTeam: 'Alter Stand')],
      matches,
    );
    expect(merged, hasLength(3));
    expect(
        merged.firstWhere((match) => match.id == 1).opponentTeam, 'Team Eins');
    expect(merged.firstWhere((match) => match.id == 3).opponentTeam,
        'Unverändert');
  });

  test('Unknown and team scorers stay separate in combined statistics', () {
    MatchGame matchWithScorers(int id) => MatchGame(
          id: id,
          createdAt: DateTime(2026, 8, id),
          location: '',
          opponentTeam: 'Team $id',
          matchDateTime: DateTime(2026, 8, id),
          matchTag: '',
          matchType: 'Liga',
          players: const [],
          events: [
            MatchEvent(
              id: 1,
              playerId: -1,
              playerName: 'Unbekannt',
              playerNumber: 0,
              kind: 'point',
              category: 'Sonstiges',
              occurredAt: DateTime(2026, 8, id, 12),
            ),
            MatchEvent(
              id: 2,
              playerId: -2,
              playerName: 'Mannschaft',
              playerNumber: 0,
              kind: 'point',
              category: 'Gegnerfehler',
              occurredAt: DateTime(2026, 8, id, 12, 1),
            ),
          ],
        );

    final combined = combineMatchesForStatistics([
      matchWithScorers(1),
      matchWithScorers(2),
    ]);

    expect(combined.players.map((player) => player.name), [
      'Unbekannt',
      'Mannschaft',
    ]);
    expect(combined.events.map((event) => event.playerId), [1, 2, 1, 2]);
  });

  test('match list ordering uses scheduled game date and time', () {
    MatchGame match(int id, DateTime createdAt, DateTime matchDateTime) =>
        MatchGame(
          id: id,
          createdAt: createdAt,
          location: '',
          opponentTeam: 'Team $id',
          matchDateTime: matchDateTime,
          matchTag: '',
          matchType: 'Liga',
          players: const [],
          events: const [],
        );

    final newerGame = match(
      1,
      DateTime(2026, 5, 1),
      DateTime(2026, 6, 10, 20),
    );
    final laterCreated = match(
      2,
      DateTime(2026, 6, 12),
      DateTime(2026, 6, 10, 18),
    );

    expect(compareMatchesByGameTime(newerGame, laterCreated), lessThan(0));
    expect(compareMatchesByGameTime(laterCreated, newerGame), greaterThan(0));
  });

  testWidgets('Teams with players and coaches are persisted', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await databaseFactoryMemory.openDatabase('teams.db');
    await tester.pumpWidget(MaterialApp(home: TeamsPage(database: database)));
    await _pumpUi(tester);
    expect(find.byKey(const ValueKey('export-all-team-data')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new-team-button')));
    await _pumpUi(tester);
    await tester.enterText(
      find.byKey(const ValueKey('team-name-input')),
      'SV Beispiel',
    );
    await _pumpUi(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.tap(find.text('Spieler'));
    await _pumpUi(tester);
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
    await _pumpUi(tester);
    expect(find.textContaining('Trikot 7'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Spieler bearbeiten'));
    await tester.tap(find.byTooltip('Spieler bearbeiten'));
    await _pumpUi(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('team-player-number-input')),
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('team-player-number-input')),
          )
          .controller
          ?.text,
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-player-number-input')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-player-button')));
    await _pumpUi(tester);
    expect(find.textContaining('Trikot 9'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.tap(find.text('Trainer'));
    await _pumpUi(tester);
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
    await _pumpUi(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUi(tester);
    await tester.pumpWidget(MaterialApp(home: TeamsPage(database: database)));
    await _pumpUi(tester);

    expect(find.text('SV Beispiel'), findsOneWidget);
    expect(find.text('1 Spieler • 1 Trainer'), findsOneWidget);
    expect(find.byTooltip('Team mit Daten teilen'), findsNothing);
    await tester.tap(find.text('SV Beispiel'));
    await _pumpUi(tester);
    expect(find.text('Team teilen'), findsOneWidget);
    await tester.tap(find.text('Spieler'));
    await _pumpUi(tester);
    expect(find.textContaining('Ada'), findsOneWidget);
    expect(find.textContaining('Trikot 9'), findsOneWidget);
    expect(find.textContaining('Schnelle Mittelblockerin.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpUi(tester);
    await tester.tap(find.text('Trainer'));
    await _pumpUi(tester);
    expect(find.textContaining('Mara'), findsOneWidget);
    expect(find.textContaining('Trainiert die Mittelblocker.'), findsOneWidget);
    expect(find.textContaining('Cheftrainerin'), findsOneWidget);
  });

  test('player statistics maps linked games and trend events', () {
    const team = Team(
      id: 7,
      name: 'SV Beispiel',
      players: [
        TeamPlayer(
          id: 1,
          name: 'Ada',
          number: 7,
          birthDate: null,
          position: 'Zuspiel',
          profile: '',
          personId: 100,
        ),
      ],
      coaches: [],
    );
    const linkedTeam = Team(
      id: 8,
      name: 'SV Beispiel U18',
      players: [
        TeamPlayer(
          id: 2,
          name: 'Ada',
          number: 3,
          birthDate: null,
          position: 'Zuspiel',
          profile: '',
          personId: 100,
        ),
      ],
      coaches: [],
    );
    MatchGame match(int id, int teamId, int teamPlayerId, int scorerId) =>
        MatchGame(
          id: id,
          createdAt: DateTime(2026, 6, id),
          location: 'Halle',
          opponentTeam: 'Team $id',
          matchDateTime: DateTime(2026, 6, id, 18),
          matchTag: '',
          matchType: 'Liga',
          teamId: teamId,
          players: [
            MatchPlayer(
              id: scorerId,
              name: 'Ada',
              number: 7,
              teamPlayerId: teamPlayerId,
              sourceTeamId: teamId,
            ),
          ],
          events: [
            MatchEvent(
              id: 1,
              playerId: scorerId,
              playerName: 'Ada',
              playerNumber: 7,
              kind: 'point',
              category: 'Angriff',
              occurredAt: DateTime(2026, 6, id, 18, 1),
            ),
          ],
        );

    final matches = playerMatchRecordsForTeamPlayer(
      matches: [match(1, 7, 1, 22), match(2, 8, 2, 33), match(3, 9, 3, 44)],
      team: team,
      player: team.players.single,
      linkedTeams: [team, linkedTeam],
    );
    final combined = combineMatchesForStatistics(matches);
    final samples = matchPlayerTrendSamples(combined, matches, 1);

    expect(matches.map((entry) => entry.id), [1, 2]);
    expect(matches.every((entry) => entry.players.single.teamPlayerId == 1),
        isTrue);
    expect(samples.last.points, 2);
  });

  testWidgets('Training shows team attendance matrix sorted by player number', (
    WidgetTester tester,
  ) async {
    final database = await databaseFactoryMemory.openDatabase('training.db');
    final teamsRepository = TeamsRepository(database);
    await tester.runAsync(
      () => teamsRepository.save([
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
      ]),
    );
    final savedTeams = await tester.runAsync(() => teamsRepository.load());
    expect(savedTeams?.single.name, 'SV Beispiel');

    await tester
        .pumpWidget(MaterialApp(home: TrainingPage(database: database)));
    await _pumpUi(tester);

    expect(find.text('Noch keine Trainings angelegt.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('new-training-content-button')),
    );
    await _pumpUi(tester);

    expect(find.text('Trainingsinfo'), findsOneWidget);
    expect(find.text('Team auswählen'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await _pumpUi(tester);
    expect(find.text('SV Beispiel'), findsOneWidget);
    await tester.tap(find.text('SV Beispiel'));
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Zurück'));
    await _pumpUi(tester);
    await tester.tap(find.text('Training').last);
    await _pumpUi(tester);
    await tester.tap(find.text('Teilnahme'));
    await _pumpUi(tester);

    expect(find.text('Trainer'), findsOneWidget);
    expect(find.text('Spieler'), findsOneWidget);
    final bertaName = find.text('Berta  3', findRichText: true);
    final adaName = find.text('Ada  12', findRichText: true);
    expect(bertaName, findsOneWidget);
    expect(adaName, findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    final guestNameInput = find.byKey(const ValueKey('guest-name-input'));
    await tester.ensureVisible(guestNameInput);
    await tester.enterText(
      guestNameInput,
      'Gast Anna',
    );
    await tester.tap(find.byKey(const ValueKey('add-guest-button')));
    await _pumpUi(tester);
    expect(find.text('Gäste'), findsOneWidget);
    expect(
        find.textContaining('Gast Anna', findRichText: true), findsOneWidget);

    final guestParticipation = find.byKey(
      const ValueKey('attendance-guest:0-participating'),
    );
    await tester.tap(guestParticipation);
    await _pumpUi(tester);
    expect(tester.widget<Checkbox>(guestParticipation).value, isTrue);

    final adaPosition = tester.getTopLeft(adaName);
    final bertaPosition = tester.getTopLeft(bertaName);
    expect(adaPosition.dy, lessThan(bertaPosition.dy));

    final bertaParticipation = find.byKey(
      const ValueKey('attendance-player:2-participating'),
    );
    await tester.tap(bertaParticipation);
    await _pumpUi(tester);
    expect(tester.widget<Checkbox>(bertaParticipation).value, isTrue);

    await tester.tap(find.byTooltip('Zurück'));
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Zurück'));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey('new-training-content-button')),
    );
    await _pumpUi(tester);
    expect(find.text('Trainingsinfo'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
