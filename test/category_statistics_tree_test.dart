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
  });

  testWidgets('statistics show category tree with players as columns',
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
    final tableFinder = find.descendant(
      of: find.byKey(const ValueKey('category-tree-stats-table')),
      matching: find.byType(DataTable),
    );
    final table = tester.widget<DataTable>(tableFinder);
    expect(table.columns.map((column) => column.label).toList(), hasLength(5));
    expect(
      table.rows[0].cells.skip(1).map((cell) => cell.child as Text).map(
            (text) => text.data,
          ),
      ['2', '1', '1', '0'],
    );
    expect(
      table.rows[1].cells.skip(1).map((cell) => cell.child as Text).map(
            (text) => text.data,
          ),
      ['0', '1', '0', '1'],
    );
    expect(
      table.rows[4].cells.skip(1).map((cell) => cell.child as Text).map(
            (text) => text.data,
          ),
      ['2', '1', '0', '0'],
    );
    expect(find.text('Gesamt · Punkte'), findsOneWidget);
    expect(find.text('Aufschlag · Punkte'), findsOneWidget);
    expect(find.text('Ass · Punkte'), findsOneWidget);
    expect(find.text('Sonstiges · Fehler'), findsOneWidget);
    expect(find.text('Ada · 7'), findsOneWidget);
    expect(find.text('Berta · 8'), findsOneWidget);
    expect(find.text('Mannschaft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('complete PDF renders the category tree in every layout', () async {
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
