import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:volley_ace/src/scoreboard/scoreboard_page.dart';
import 'package:volley_ace/src/settings/app_settings.dart';
import 'package:volley_ace/src/settings/settings_page.dart';

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
    await tester.pumpWidget(const MaterialApp(home: ScoreboardPage()));

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
    await tester.pumpWidget(const MaterialApp(home: ScoreboardPage()));

    final setScoreArea = find.byKey(const ValueKey('set-score-area'));
    await tester.fling(setScoreArea, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rot-set-panel')), findsOneWidget);
  });

  testWidgets('Undoing a set restores the previous point score', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScoreboardPage()));

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
