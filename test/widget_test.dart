import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/scoreboard/scoreboard_page.dart';
import 'package:volleyace/src/settings/app_settings.dart';
import 'package:volleyace/src/settings/settings_page.dart';
import 'package:volleyace/src/teams/teams_page.dart';

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
      find.byKey(const ValueKey('team-player-position-input')),
      'Mittelblock',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-player-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trainer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-name-input')),
      'Mara',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-coach-button')));
    await tester.pumpAndSettle();
    expect(find.text('Mara'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: TeamsPage(database: database)));
    await tester.pumpAndSettle();

    expect(find.text('SV Beispiel'), findsOneWidget);
    expect(find.text('1 Spieler • 1 Trainer'), findsOneWidget);
  });
}
