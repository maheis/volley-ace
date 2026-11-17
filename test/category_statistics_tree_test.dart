import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/backup/app_backup_service.dart';

void main() {
  final start = DateTime(2026, 11, 16, 18);
  final players = const <MatchPlayer>[
    MatchPlayer(id: 1, name: 'Ada', number: 7),
    MatchPlayer(id: 2, name: 'Berta', number: 8),
    MatchPlayer(id: -2, name: 'Mannschaft', number: 0),
  ];
  final events = <MatchEvent>[
    MatchEvent(
      id: 1,
      playerId: 1,
      playerName: 'Ada',
      playerNumber: 7,
      kind: 'point',
      category: 'Aufschlag · Ass',
      occurredAt: start,
    ),
    MatchEvent(
      id: 2,
      playerId: 1,
      playerIds: const [1, 2],
      playerName: 'Ada, Berta',
      playerNumber: 7,
      kind: 'point',
      category: 'Aufschlag · Ass',
      occurredAt: start.add(const Duration(minutes: 1)),
    ),
    MatchEvent(
      id: 3,
      playerId: 2,
      playerName: 'Berta',
      playerNumber: 8,
      kind: 'error',
      category: 'Aufschlag · Ball ins Netz',
      occurredAt: start.add(const Duration(minutes: 2)),
    ),
    MatchEvent(
      id: 4,
      playerId: -2,
      playerName: 'Mannschaft',
      playerNumber: 0,
      kind: 'point',
      category: 'Angriff',
      occurredAt: start.add(const Duration(minutes: 3)),
    ),
    MatchEvent(
      id: 5,
      playerId: null,
      playerName: 'Unbekannt',
      playerNumber: 0,
      kind: 'error',
      category: 'Sonstiges: Ball verloren',
      occurredAt: start.add(const Duration(minutes: 4)),
    ),
  ];

  test('category tree sums events to parents and tracks players separately',
      () {
    final tree = categoryStatisticsTree(events, players);
    final total = tree.single;
    final serve =
        total.children.singleWhere((node) => node.label == 'Aufschlag');
    final ace = serve.children.singleWhere((node) => node.label == 'Ass');
    final other =
        total.children.singleWhere((node) => node.label == 'Sonstiges');

    expect(total.label, 'Gesamt');
    expect(total.pointsCount, 3);
    expect(total.errorsCount, 2);
    expect(total.pointsByPlayer[1], 2);
    expect(total.pointsByPlayer[2], 1);
    expect(total.pointsByPlayer[-2], 1);
    expect(total.errorsByPlayer[2], 1);
    expect(total.errorsByPlayer[null], 1);
    expect(serve.pointsCount, 2);
    expect(serve.errorsCount, 1);
    expect(ace.pointsCount, 2);
    expect(ace.pointsByPlayer[1], 2);
    expect(ace.pointsByPlayer[2], 1);
    expect(other.children.single.label, 'Ball verloren');
    expect(other.children.single.depth, 2);

    final pointsTree = categoryStatisticsTree(events, players, kind: 'point');
    expect(
      pointsTree.single.children.map((node) => node.label),
      ['Aufschlag', 'Angriff'],
    );
    expect(
      pointsTree.single.children.first.children.map((node) => node.label),
      ['Ass'],
    );
    final errorsTree = categoryStatisticsTree(events, players, kind: 'error');
    expect(
      errorsTree.single.children.map((node) => node.label),
      ['Aufschlag', 'Sonstiges'],
    );
  });

  test('custom Sonstiges details remain under their selected parent', () {
    final customEvents = [
      ...events,
      MatchEvent(
        id: 6,
        playerId: 1,
        playerName: 'Ada',
        playerNumber: 7,
        kind: 'point',
        category: 'Aufschlag · Sonstiges: Netzroller',
        occurredAt: start.add(const Duration(minutes: 5)),
      ),
      MatchEvent(
        id: 7,
        playerId: 2,
        playerName: 'Berta',
        playerNumber: 8,
        kind: 'point',
        category: 'Angriff · Sonstiges: Glück',
        occurredAt: start.add(const Duration(minutes: 6)),
      ),
    ];
    final tree = categoryStatisticsTree(customEvents, players, kind: 'point');
    final roots = tree.single.children;
    final serve = roots.firstWhere((node) => node.label == 'Aufschlag');
    final attack = roots.firstWhere((node) => node.label == 'Angriff');
    expect(
      serve.children
          .singleWhere((node) => node.label == 'Sonstiges')
          .children
          .single
          .label,
      'Netzroller',
    );
    expect(
      attack.children
          .singleWhere((node) => node.label == 'Sonstiges')
          .children
          .single
          .label,
      'Glück',
    );
  });

  test('export location summary uses selected match locations', () {
    final match = MatchGame(
      id: 1,
      createdAt: start,
      location: 'Halle Nord',
      opponentTeam: 'Team Blau',
      matchDateTime: start,
      matchTag: '',
      matchType: 'Liga',
      players: const [],
      events: const [],
    );
    expect(
      matchLocationSummary(match, sourceMatches: [
        match,
        match.copyWith(id: 2, location: 'Halle Süd'),
        match.copyWith(id: 3, location: 'Halle Nord'),
      ]),
      'Halle Nord · Halle Süd',
    );
    expect(matchLocationSummary(match), 'Halle Nord');
    expect(
      matchLocationSummary(match.copyWith(location: ''), sourceMatches: [
        match.copyWith(location: ''),
      ]),
      'Ort offen',
    );
  });

  testWidgets('statistics show separate overall and player category tables',
      (tester) async {
    final database =
        await databaseFactoryMemory.openDatabase('category-tree-ui');
    addTearDown(database.close);
    final match = MatchGame(
      id: 1,
      createdAt: start,
      location: 'Halle',
      opponentTeam: 'Team Blau',
      matchDateTime: start,
      matchTag: '',
      matchType: 'Liga',
      players: players,
      events: events,
    );
    await tester.runAsync(() => MatchStatsRepository(database).save(
          MatchStatsState(matches: [match]),
        ));
    await tester.pumpWidget(MaterialApp(
      home: MatchStatsPage(
        database: database,
        initialMatchId: match.id,
        initialSection: 'stats',
      ),
    ));
    await tester.pumpAndSettle();
    final pointsTotalCard =
        find.byKey(const ValueKey('statistics-total-points'));
    final errorsTotalCard =
        find.byKey(const ValueKey('statistics-total-errors'));
    final totalPointsCard =
        find.byKey(const ValueKey('category-tree-stats-point-Punkte gesamt'));
    final totalErrorsCard =
        find.byKey(const ValueKey('category-tree-stats-error-Fehler gesamt'));
    expect(totalPointsCard, findsOneWidget);
    expect(totalErrorsCard, findsOneWidget);
    expect(pointsTotalCard, findsOneWidget);
    expect(errorsTotalCard, findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-total-value-Punkte gesamt')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-total-value-Fehler gesamt')),
        findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(
            const ValueKey('statistics-total-value-Punkte gesamt'),
          ))
          .data,
      '3',
    );
    expect(
      tester
          .widget<Text>(find.byKey(
            const ValueKey('statistics-total-value-Fehler gesamt'),
          ))
          .data,
      '2',
    );
    expect(
      tester.getTopLeft(totalPointsCard).dx,
      lessThan(tester.getTopLeft(totalErrorsCard).dx),
    );
    expect(find.text('Punkte gesamt'), findsWidgets);
    expect(find.text('Fehler gesamt'), findsWidgets);
    expect(find.text('Punkte und Fehler nach Art'), findsNothing);

    final totalPointsTable = tester.widget<DataTable>(find.descendant(
      of: totalPointsCard,
      matching: find.byType(DataTable),
    ));
    expect(totalPointsTable.columns, hasLength(2));
    expect(
      (totalPointsTable.columns.last.label as Text).data,
      'Gesamt',
    );
    expect(
      (totalPointsTable.rows.first.cells.last.child as Text).data,
      '3',
    );
    final totalPointRows = totalPointsTable.rows
        .map((row) => (row.cells.first.child as SizedBox).child as Padding)
        .map((padding) => (padding.child as Text).data)
        .toList();
    expect(totalPointRows, contains('Gesamt · Punkte'));
    expect(totalPointRows, contains('Aufschlag · Punkte'));
    expect(totalPointRows, isNot(contains('Fehler')));
    final totalErrorsTable = tester.widget<DataTable>(find.descendant(
      of: totalErrorsCard,
      matching: find.byType(DataTable),
    ));
    expect(totalErrorsTable.columns, hasLength(2));
    expect((totalErrorsTable.columns.last.label as Text).data, 'Gesamt');
    expect((totalErrorsTable.rows.first.cells.last.child as Text).data, '2');

    final playerPointsCard = find.byKey(
      const ValueKey('category-tree-stats-point-Punkte pro Spieler'),
    );
    await tester.scrollUntilVisible(
      playerPointsCard,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final playerPointsTable = tester.widget<DataTable>(find.descendant(
      of: playerPointsCard,
      matching: find.byType(DataTable),
    ));
    final pointRowLabels = playerPointsTable.rows
        .map((row) => (row.cells.first.child as SizedBox).child as Padding)
        .map((padding) => (padding.child as Text).data)
        .toList();
    expect(pointRowLabels, contains('Gesamt · Punkte'));
    expect(pointRowLabels, contains('Aufschlag · Punkte'));
    expect(pointRowLabels, contains('Ass · Punkte'));
    expect(pointRowLabels, isNot(contains('Fehler')));
    expect(find.text('Ada · 7'), findsOneWidget);
    expect(find.text('Berta · 8'), findsOneWidget);
    expect(find.text('Mannschaft'), findsWidgets);

    final playerErrorsCard = find.byKey(
      const ValueKey('category-tree-stats-error-Fehler pro Spieler'),
    );
    await tester.scrollUntilVisible(
      playerErrorsCard,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final playerErrorsTable = tester.widget<DataTable>(find.descendant(
      of: playerErrorsCard,
      matching: find.byType(DataTable),
    ));
    final errorRowLabels = playerErrorsTable.rows
        .map((row) => (row.cells.first.child as SizedBox).child as Padding)
        .map((padding) => (padding.child as Text).data)
        .toList();
    expect(errorRowLabels, contains('Gesamt · Fehler'));
    expect(errorRowLabels, contains('Aufschlag · Fehler'));
    expect(errorRowLabels, contains('Ball ins Netz · Fehler'));
    expect(errorRowLabels, isNot(contains('Punkte')));
    expect(tester.takeException(), isNull);
  });

  test('complete PDF renders category tables in every layout', () async {
    final match = MatchGame(
      id: 1,
      createdAt: start,
      location: 'Halle',
      opponentTeam: 'Team Blau',
      matchDateTime: start,
      matchTag: '',
      matchType: 'Liga',
      players: players,
      events: events,
    );
    for (final layout in ['portrait', 'continuous', 'tiled']) {
      final bytes = await AppBackupService.buildMatchStatsPdf(
        match,
        title: 'Komplettexport',
        includeFullMatchDetails: true,
        landscape: layout == 'continuous',
        continuous: layout == 'continuous',
        tiled: layout == 'tiled',
      );
      expect(bytes.take(5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(bytes.length, greaterThan(1000));
    }
  });
}
