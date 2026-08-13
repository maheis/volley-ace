import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:volleyace/src/scoreboard/scoreboard_page.dart';
import 'package:volleyace/src/settings/app_settings.dart';
import 'package:volleyace/src/settings/settings_page.dart';

void main() {
  testWidgets('Settings page shows typography controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(initial: AppSettings.defaults)),
    );

    expect(find.text('settings'), findsOneWidget);
    expect(find.text('font'), findsOneWidget);
    expect(find.text('save'), findsOneWidget);
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
}
