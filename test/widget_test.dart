import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/scoreboard/scoreboard_page.dart';
import 'package:volleyace/src/settings/app_settings.dart';
import 'package:volleyace/src/settings/settings_page.dart';
import 'package:volleyace/src/teams/teams_page.dart';
import 'package:volleyace/src/tactics/tactics_page.dart';

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
    await tester.tap(find.byKey(const ValueKey('select-player-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-category-Ass')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-name-input')), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Ass'), findsWidgets);
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
}
