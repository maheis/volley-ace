import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:volleyace/src/analytics/match_stats_page.dart';
import 'package:volleyace/src/backup/app_backup_service.dart';

class _MarkerRecordingCanvas implements Canvas {
  final markerColors = <Color>[];

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    markerColors.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  MatchGame game(int day, int playerId, {bool hasPlayer = true}) {
    final time = DateTime(2026, 11, day, 18);
    return MatchGame(
      id: day,
      createdAt: time,
      location: 'Halle',
      opponentTeam: 'Team $day',
      matchDateTime: time,
      matchTag: '',
      matchType: 'Liga',
      players: hasPlayer
          ? [MatchPlayer(id: playerId, name: 'Ada', number: 7)]
          : const [],
      events: [
        for (var index = 0; index < 2; index++)
          MatchEvent(
            id: index + 1,
            playerId: hasPlayer ? playerId : null,
            playerName: hasPlayer ? 'Ada' : 'Mannschaft',
            playerNumber: hasPlayer ? 7 : 0,
            kind: index == 0 ? 'point' : 'error',
            category: day == 1 && index == 0 ? 'Gegnerfehler' : 'Angriff',
            occurredAt: time.add(Duration(minutes: index)),
          ),
      ],
    );
  }

  final matches = [game(3, 0, hasPlayer: false), game(2, 9), game(1, 4)];
  final combined = combineMatchesForStatistics(matches);
  final playerId = combined.players.single.id;

  test('player comparison resets counters and preserves match participation',
      () {
    final samples = matchPlayerTrendSamples(
      combined,
      matches,
      playerId,
      resetPerMatch: true,
    );
    for (var matchIndex = 0; matchIndex < 3; matchIndex++) {
      final segment =
          samples.where((sample) => sample.matchIndex == matchIndex).toList();
      expect(segment.first.beginsMatch, isTrue);
      expect(segment.last.endsMatch, isTrue);
      expect(segment.first.time.day, matchIndex + 1);
      expect(segment.first.points, 0);
      expect(segment.first.errors, 0);
      expect(segment.first.opponentErrors, 0);
      expect(segment.last.points, matchIndex < 2 ? 1 : 0);
      expect(segment.last.errors, matchIndex < 2 ? 1 : 0);
      expect(segment.last.opponentErrors, matchIndex == 0 ? 1 : 0);
      expect(segment.first.playerInMatchRoster, matchIndex < 2);
    }
    final cumulative = matchPlayerTrendSamples(combined, matches, playerId);
    expect(cumulative.last.points, 2);
    expect(cumulative.last.errors, 2);
    expect(cumulative.last.opponentErrors, 1);
  });

  testWidgets('player chart marks only personal and shared scoring actions',
      (tester) async {
    final time = DateTime(2026, 11, 1, 18);
    MatchEvent event(int minute, String kind, int scorerId,
            {List<int> sharedIds = const []}) =>
        MatchEvent(
          id: minute,
          playerId: scorerId,
          playerIds: sharedIds,
          playerName: scorerId == 4 ? 'Ada' : 'Berta',
          playerNumber: scorerId == 4 ? 7 : 9,
          kind: kind,
          category: 'Angriff',
          occurredAt: time.add(Duration(minutes: minute)),
        );
    final source = game(1, 4).copyWith(
      players: const [
        MatchPlayer(id: 4, name: 'Ada', number: 7),
        MatchPlayer(id: 9, name: 'Berta', number: 9),
      ],
      events: [
        event(0, 'point', 4),
        event(1, 'point', 9),
        event(2, 'error', 9),
        event(3, 'point', 9, sharedIds: [4, 9]),
        event(4, 'error', 9, sharedIds: [4, 9]),
        event(5, 'manual_set_end', 9),
      ],
    );
    final sources = [source, game(2, 0, hasPlayer: false)];
    final combined = combineMatchesForStatistics(sources);
    final ada = combined.players.singleWhere((player) => player.name == 'Ada');
    for (final comparisonMode in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchStatsTrendChart(
              title: 'Markierungen',
              samples: matchPlayerTrendSamples(
                combined,
                sources,
                ada.id,
                resetPerMatch: comparisonMode,
              ),
              timeoutMarkers: const [],
              matchRanges: matchTimeRangesFor(sources),
              comparisonMode: comparisonMode,
              matchLabels: const ['Team 1', 'Team 2'],
              height: 220,
            ),
          ),
        ),
      ));
      await tester.pump();
      final chart = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .singleWhere((widget) =>
              widget.painter.runtimeType.toString() == '_TrendChartPainter');
      final canvas = _MarkerRecordingCanvas();
      chart.painter!.paint(canvas, const Size(600, 220));
      expect(
          canvas.markerColors.where(
              (color) => color.toARGB32() == Colors.greenAccent.toARGB32()),
          hasLength(2));
      expect(
          canvas.markerColors.where((color) =>
              color.toARGB32() == const Color(0xFFe57373).toARGB32()),
          hasLength(1));
      expect(canvas.markerColors, hasLength(3));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'player comparison renders with status bands on phone and desktop',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchStatsTrendChart(
              title: 'Ada · Spielvergleich',
              samples: matchPlayerTrendSamples(
                combined,
                matches,
                playerId,
                resetPerMatch: true,
              ),
              timeoutMarkers: const [],
              matchRanges: matchTimeRangesFor(matches),
              comparisonMode: true,
              matchLabels: const ['Team 1', 'Team 2', 'Team 3'],
              height: 220,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Ada · Spielvergleich'), findsOneWidget);
      expect(find.text('Punkte'), findsOneWidget);
      expect(find.text('Fehler'), findsOneWidget);
      expect(find.text('Gegnerfehler'), findsOneWidget);
      expect(find.textContaining('gestrichelt'), findsNothing);
      expect(find.textContaining('durchgezogen'), findsNothing);
      expect(find.textContaining('gepunktet'), findsNothing);
      expect(find.text('Nicht eingesetzt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('multi-match screen places player comparison below total',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await databaseFactoryMemory.openDatabase('comparison.db');
    addTearDown(database.close);
    await tester.runAsync(() => MatchStatsRepository(database).save(
          MatchStatsState(matches: matches),
        ));
    await tester.pumpWidget(MaterialApp(
      home: MatchStatsPage(database: database),
    ));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('match-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('match-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('multi-match-statistics-button')),
    );
    await tester.pumpAndSettle();
    final comparison = find.text('Ada · Spielvergleich · je Partie ab 0');
    await tester.scrollUntilVisible(
      comparison,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(comparison, findsOneWidget);
    final total = find.byKey(const ValueKey('trend-chart-content-Ada'));
    expect(total, findsOneWidget);
    expect(tester.getTopLeft(total).dy,
        lessThan(tester.getTopLeft(comparison).dy));
    expect(tester.takeException(), isNull);
  });

  test('multi-match player report renders in portrait, endless and tiled PDF',
      () async {
    for (final layout in ['portrait', 'endless', 'tiled']) {
      final bytes = await AppBackupService.buildMatchStatsPdf(
        combined,
        title: 'Spielervergleich',
        sourceMatches: matches,
        continuous: layout == 'endless',
        landscape: layout == 'endless',
        tiled: layout == 'tiled',
      );
      expect(bytes.take(5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(bytes.length, greaterThan(1000));
    }
  });
}
