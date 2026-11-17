import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:sembast/sembast.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/match_stats_page.dart';
import '../teams/teams_page.dart';

enum _PdfExportLayout { continuous, a4, tiledA4 }

class AppBackupService {
  AppBackupService._();

  static const int _formatVersion = 1;
  static final StoreRef<String, Map<String, dynamic>> _peopleStore =
      StoreRef<String, Map<String, dynamic>>('people');
  static final StoreRef<String, Map<String, dynamic>> _trainingStore =
      StoreRef<String, Map<String, dynamic>>('training');
  static final StoreRef<String, Map<String, dynamic>> _trainingPlansStore =
      StoreRef<String, Map<String, dynamic>>('training_plans');
  static final StoreRef<String, Map<String, dynamic>> _trainingExercisesStore =
      StoreRef<String, Map<String, dynamic>>('training_exercises');
  static final StoreRef<String, Map<String, dynamic>> _scoreboardStore =
      StoreRef<String, Map<String, dynamic>>('scoreboard');
  static final StoreRef<String, Map<String, dynamic>> _tacticsStore =
      StoreRef<String, Map<String, dynamic>>('tactics');
  static final StoreRef<String, Map<String, dynamic>> _settingsStore =
      StoreRef<String, Map<String, dynamic>>('settings');
  static final StoreRef<String, Map<String, dynamic>> _homeStore =
      StoreRef<String, Map<String, dynamic>>('home');
  static final StoreRef<String, Map<String, dynamic>> _arcadeStore =
      StoreRef<String, Map<String, dynamic>>('arcade');

  static Future<Map<String, dynamic>> _readBackup(Database database) async {
    final teamsRepository = TeamsRepository(database);
    final matchStatsRepository = MatchStatsRepository(database);

    final teams = await teamsRepository.load();
    final matchStats = await matchStatsRepository.load();
    final people = await _peopleStore.record('all').get(database);
    var training = await _trainingStore.record('sessions').get(database);
    if (training == null) {
      final legacyTraining =
          await _trainingStore.record('current').get(database);
      if (legacyTraining != null) {
        training = <String, dynamic>{
          'sessions': [legacyTraining]
        };
      }
    }
    final trainingPlans =
        await _trainingPlansStore.record('plans').get(database);
    final trainingExercises =
        await _trainingExercisesStore.record('exercises').get(database);
    final scoreboard = await _scoreboardStore.record('current').get(database);
    final scoreboardSnapshots =
        await _scoreboardStore.record('snapshots').get(database);
    final tactics = await _tacticsStore.record('board').get(database);
    final settings = await _settingsStore.record('app').get(database);
    final home = await _homeStore.record('state').get(database);
    final arcade = await _arcadeStore.record('state').get(database);

    return <String, dynamic>{
      'type': 'full',
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'teams': teams.map((team) => team.toJson()).toList(),
      'matchStats': matchStats.toJson(),
      if (people != null) 'people': people,
      if (training != null) 'training': training,
      if (trainingPlans != null) 'trainingPlans': trainingPlans,
      if (trainingExercises != null) 'trainingExercises': trainingExercises,
      if (scoreboard != null || scoreboardSnapshots != null)
        'scoreboard': <String, dynamic>{
          if (scoreboard != null) 'current': scoreboard,
          if (scoreboardSnapshots != null) 'snapshots': scoreboardSnapshots,
        },
      if (tactics != null) 'tactics': tactics,
      if (settings != null) 'settings': settings,
      if (home != null) 'home': home,
      if (arcade != null) 'arcade': arcade,
    };
  }

  static Future<Map<String, dynamic>> buildFullBackup(Database database) =>
      _readBackup(database);

  static Future<Map<String, dynamic>> buildTeamBundle(
    Database database,
    Team team,
  ) async {
    final backup = await _readBackup(database);
    List<Map<String, dynamic>> records(Object? raw, String key) {
      final values = raw is Map ? raw[key] : null;
      return values is List
          ? values
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList()
          : <Map<String, dynamic>>[];
    }

    final sessions = records(backup['training'], 'sessions').where((session) {
      final teamIds = session['teamIds'];
      final isLinkedByTeamIds = teamIds is List &&
          teamIds.whereType<num>().any((id) => id.toInt() == team.id);
      return isLinkedByTeamIds || session['teamId'] == team.id;
    }).toList();
    final planIds = <int>{};
    final exerciseIds = <int>{};
    final guestNames = <String>{};
    for (final session in sessions) {
      final storedPlanIds = session['trainingPlanIds'];
      if (storedPlanIds is List) {
        planIds.addAll(storedPlanIds.whereType<num>().map((id) => id.toInt()));
      }
      if (session['trainingPlanId'] is num) {
        planIds.add((session['trainingPlanId'] as num).toInt());
      }
      final storedExercises = session['exercises'];
      if (storedExercises is List) {
        for (final exercise in storedExercises.whereType<Map>()) {
          if (exercise['id'] is num) {
            exerciseIds.add((exercise['id'] as num).toInt());
          }
        }
      }
      if (session['guests'] is List) {
        guestNames.addAll((session['guests'] as List).whereType<String>());
      }
    }

    final plans = records(backup['trainingPlans'], 'plans')
        .where((plan) => planIds.contains(plan['id']))
        .toList();
    for (final plan in plans) {
      final storedExercises = plan['exercises'];
      if (storedExercises is List) {
        for (final exercise in storedExercises.whereType<Map>()) {
          if (exercise['id'] is num) {
            exerciseIds.add((exercise['id'] as num).toInt());
          }
        }
      }
    }

    final peopleIds = <int>{
      ...team.players.map((player) => player.personId).whereType<int>(),
      ...team.coaches.map((coach) => coach.personId).whereType<int>(),
    };
    final people = records(backup['people'], 'people')
        .where((person) =>
            peopleIds.contains(person['id']) ||
            guestNames.contains(person['name']))
        .toList();
    final exercises = records(backup['trainingExercises'], 'exercises')
        .where((exercise) => exerciseIds.contains(exercise['id']))
        .toList();
    final matchStats = Map<String, dynamic>.from(
      backup['matchStats'] as Map<String, dynamic>,
    );
    final matches = records(matchStats, 'matches').where((match) {
      if (match['teamId'] == team.id) return true;
      final players = match['players'];
      return players is List &&
          players.whereType<Map>().any(
                (player) => player['sourceTeamId'] == team.id,
              );
    }).toList();

    return <String, dynamic>{
      ...backup,
      'type': 'team-bundle',
      'teamId': team.id,
      'team': team.toJson(),
      'teams': <Map<String, dynamic>>[team.toJson()],
      'people': <String, dynamic>{'people': people},
      'matchStats': <String, dynamic>{'matches': matches},
      'training': <String, dynamic>{'sessions': sessions},
      'trainingPlans': <String, dynamic>{'plans': plans},
      'trainingExercises': <String, dynamic>{'exercises': exercises},
    };
  }

  static Map<String, dynamic> buildTeamBackup(Team team) => <String, dynamic>{
        'formatVersion': _formatVersion,
        'type': 'team',
        'exportedAt': DateTime.now().toIso8601String(),
        'team': team.toJson(),
      };

  static Map<String, dynamic> buildMatchBackup(MatchGame match) =>
      <String, dynamic>{
        'formatVersion': _formatVersion,
        'type': 'match',
        'exportedAt': DateTime.now().toIso8601String(),
        'match': match.toJson(),
      };

  static Map<String, dynamic> buildMatchesBackup(List<MatchGame> matches) =>
      <String, dynamic>{
        'formatVersion': _formatVersion,
        'type': 'matches',
        'exportedAt': DateTime.now().toIso8601String(),
        'matches': _oldestMatchesFirst(matches)
            .map((match) => match.toJson())
            .toList(),
      };

  static List<MatchGame> _oldestMatchesFirst(List<MatchGame> matches) =>
      List<MatchGame>.from(matches)
        ..sort((first, second) => compareMatchesByGameTime(second, first));

  static List<MatchGame> mergeMatchesById(
    List<MatchGame> existing,
    List<MatchGame> imported,
  ) {
    final merged = <int, MatchGame>{
      for (final match in existing) match.id: match,
    };
    for (final match in imported) {
      merged[match.id] = match;
    }
    return merged.values.toList();
  }

  static Future<Uint8List> buildMatchStatsPdf(
    MatchGame match, {
    required String title,
    List<MatchGame>? sourceMatches,
    bool landscape = false,
    bool continuous = false,
    bool tiled = false,
    bool includeFullMatchDetails = false,
  }) async {
    final orderedSourceMatches =
        sourceMatches == null ? null : _oldestMatchesFirst(sourceMatches);
    final sortedEvents = List<MatchEvent>.from(match.events)
      ..sort((a, b) {
        final timeOrder = a.occurredAt.compareTo(b.occurredAt);
        return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
      });
    final points = _eventSummary(sortedEvents, 'point');
    final errors = _eventSummary(sortedEvents, 'error');
    final pointCount =
        sortedEvents.where((event) => event.kind == 'point').length;
    final errorCount =
        sortedEvents.where((event) => event.kind == 'error').length;
    final categories = <String>{...points.keys, ...errors.keys}.toList()
      ..sort();
    final matchTimes = orderedSourceMatches == null
        ? const <DateTime>[]
        : (orderedSourceMatches
            .map((sourceMatch) {
              final eventTimes = sourceMatch.events
                  .where(
                      (event) => event.kind == 'point' || event.kind == 'error')
                  .map((event) => event.occurredAt)
                  .toList()
                ..sort();
              return eventTimes.firstOrNull;
            })
            .whereType<DateTime>()
            .toList()
          ..sort());
    final scoredEvents = sortedEvents
        .where((event) => event.kind == 'point' || event.kind == 'error')
        .toList();
    final firstEventTime = scoredEvents.firstOrNull?.occurredAt;
    final lastEventTime = scoredEvents.lastOrNull?.occurredAt;
    final period = firstEventTime == null || lastEventTime == null
        ? _formatPdfDate(match.matchDateTime)
        : '${_formatPdfDateTime(firstEventTime)} – ${_formatPdfDateTime(lastEventTime)}';
    final document = pw.Document();
    final pageFormat = tiled ? pdf.PdfPageFormat.a4 : _pageFormat(landscape);
    if (!continuous && !tiled) {
      _addPortraitStatistics(document, match,
          title: title,
          sourceMatches: orderedSourceMatches,
          includeFullMatchDetails: includeFullMatchDetails);
      if (orderedSourceMatches != null && orderedSourceMatches.length > 1) {
        for (final sourceMatch in orderedSourceMatches) {
          _addPortraitStatistics(document, sourceMatch,
              title: 'Einzelpartie · ${sourceMatch.opponentTeam}',
              includeFullMatchDetails: includeFullMatchDetails);
        }
      }
      return document.save();
    }

    final continuousContent = continuous || tiled;
    List<pw.Widget> buildReportWidgets() => <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            match.opponentTeam.isEmpty ? match.matchType : match.opponentTeam,
            style: const pw.TextStyle(fontSize: 13),
          ),
          if (orderedSourceMatches != null &&
              orderedSourceMatches.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Ausgewählte Partien (${orderedSourceMatches.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _selectedMatchesTable(orderedSourceMatches),
          ],
          pw.Text(
            '$period · ${match.location.isEmpty ? 'Ort offen' : match.location}',
            style: const pw.TextStyle(
              color: pdf.PdfColors.grey700,
              fontSize: 10,
            ),
          ),
          if (includeFullMatchDetails) ...[
            if (orderedSourceMatches != null &&
                orderedSourceMatches.length > 1) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Einzelspiele: Bericht, Verlauf und Statistik',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              for (final sourceMatch in orderedSourceMatches)
                ..._individualMatchReportWidgets(
                  sourceMatch,
                  includeMatchDetails: true,
                  continuous: continuousContent,
                ),
            ] else ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Spielbericht',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                match.matchReport.trim().isEmpty
                    ? 'Kein Spielbericht erfasst.'
                    : match.matchReport,
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Spielverlauf',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              ..._matchHistoryWidgets(match, sortedEvents),
            ],
          ],
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              pw.Expanded(
                child:
                    _summaryCard('Punkte', '$pointCount', pdf.PdfColors.green),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _summaryCard('Fehler', '$errorCount', pdf.PdfColors.red),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _summaryCard(
                  'Einträge',
                  '${pointCount + errorCount}',
                  pdf.PdfColors.blue,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Punkte und Fehler gesamt',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (categories.isNotEmpty) ...[
            pw.Text('Punkte gesamt',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _categoryTreeSummaryTable(
              _categoryTreeRows(
                sortedEvents,
                match.players,
                kind: 'point',
              ),
              includeErrors: false,
            ),
            pw.SizedBox(height: 10),
            pw.Text('Fehler gesamt',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _categoryTreeSummaryTable(
              _categoryTreeRows(
                sortedEvents,
                match.players,
                kind: 'error',
              ),
              includePoints: false,
            ),
          ],
          pw.Text(
            'Zeitverlauf',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (pointCount + errorCount == 0)
            pw.Text('Noch keine Verlaufsdaten vorhanden.')
          else
            pw.SizedBox(
              height: 220,
              child: _timelineChart(sortedEvents, matchTimes: matchTimes),
            ),
          if (orderedSourceMatches != null &&
              orderedSourceMatches.length > 1) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Spielvergleich · je Partie ab 0',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.SizedBox(
              height: 220,
              child: _timelineChart(
                sortedEvents,
                trendSamples: matchComparisonTrendSamples(orderedSourceMatches),
                comparisonMode: true,
                matchLabels: orderedSourceMatches
                    .map((source) => source.opponentTeam.isEmpty
                        ? _formatPdfDate(source.matchDateTime)
                        : source.opponentTeam)
                    .toList(),
              ),
            ),
          ],
          if (match.players.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Text(
              'Spielerübersicht',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _playerTable(match, sortedEvents),
            pw.SizedBox(height: 18),
            pw.Text(
              'Zeitverlauf pro Spieler',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            for (final player in match.players) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                _playerStatisticsLabel(player, sortedEvents),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.SizedBox(
                height: 150,
                child: _timelineChart(
                  sortedEvents
                      .where((event) => event.scorerIds.contains(player.id))
                      .toList(),
                  matchTimes: matchTimes,
                  trendSamples: matchPlayerTrendSamples(
                    match,
                    orderedSourceMatches ?? <MatchGame>[match],
                    player.id,
                  ),
                ),
              ),
              if (orderedSourceMatches != null &&
                  orderedSourceMatches.length > 1) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  '${player.name} · Spielvergleich · je Partie ab 0',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.SizedBox(
                  height: 200,
                  child: _timelineChart(
                    const <MatchEvent>[],
                    trendSamples: matchPlayerTrendSamples(
                      match,
                      orderedSourceMatches,
                      player.id,
                      resetPerMatch: true,
                    ),
                    comparisonMode: true,
                    matchLabels: orderedSourceMatches
                        .map((source) => source.opponentTeam.isEmpty
                            ? _formatPdfDate(source.matchDateTime)
                            : source.opponentTeam)
                        .toList(),
                  ),
                ),
              ],
            ],
            ..._playerErrorDetails(match, sortedEvents),
          ],
          if (orderedSourceMatches != null &&
              orderedSourceMatches.length > 1 &&
              !includeFullMatchDetails) ...[
            pw.SizedBox(height: 24),
            pw.Divider(color: pdf.PdfColors.grey400),
            pw.Text(
              'Einzelstatistiken',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            for (final sourceMatch in orderedSourceMatches)
              ..._individualMatchReportWidgets(
                sourceMatch,
                continuous: continuousContent,
              ),
          ],
        ];

    if (tiled) {
      await _addTiledPrintPages(document, buildReportWidgets);
      return document.save();
    }

    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat(pageFormat.width, double.infinity),
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: buildReportWidgets(),
        ),
      ),
    );

    return document.save();
  }

  static Future<Uint8List> buildMatchHistoryPdf(MatchGame match,
      {bool continuous = true, bool tiled = false}) async {
    final events = List<MatchEvent>.from(match.events)
      ..sort((first, second) {
        final timeOrder = first.occurredAt.compareTo(second.occurredAt);
        return timeOrder != 0 ? timeOrder : first.id.compareTo(second.id);
      });
    final historyRows = _matchHistoryRows(match, events);
    final historyWidgets = _matchHistoryWidgetsFromRows(historyRows);
    final landscapeFormat = _pageFormat(true);
    final document = pw.Document();
    List<pw.Widget> buildWidgets() => <pw.Widget>[
          pw.Text(
            'Spielverlauf · ${match.opponentTeam.isEmpty ? match.matchType : match.opponentTeam}',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_formatPdfDateTime(match.matchDateTime).replaceAll('–', '-')} · ${match.location.isEmpty ? 'Ort offen' : match.location} · ${match.matchType}',
            style:
                const pw.TextStyle(color: pdf.PdfColors.grey700, fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          ...historyWidgets,
        ];
    if (tiled) {
      await _addTiledPrintPages(document, buildWidgets);
    } else if (continuous) {
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(landscapeFormat.width, double.infinity),
          margin: const pw.EdgeInsets.all(32),
          build: (_) => pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: buildWidgets(),
          ),
        ),
      );
    } else {
      document.addPage(pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: math.max(20, historyRows.length + 1),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber} / ${context.pagesCount}'),
        ),
        build: (_) => buildWidgets(),
      ));
    }
    return document.save();
  }

  static void _addPortraitStatistics(pw.Document document, MatchGame match,
      {required String title,
      List<MatchGame>? sourceMatches,
      bool includeFullMatchDetails = false}) {
    final events = List<MatchEvent>.from(match.events)
      ..sort((first, second) {
        final byTime = first.occurredAt.compareTo(second.occurredAt);
        return byTime != 0 ? byTime : first.id.compareTo(second.id);
      });
    final points = _eventSummary(events, 'point');
    final errors = _eventSummary(events, 'error');
    final detailCategories = {...points.keys, ...errors.keys}.toList()..sort();
    final pageFormat = pdf.PdfPageFormat.a4;
    pw.Widget heading(String text) => pw.Text(text,
        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold));
    pw.Widget footer(pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('VolleyAce · ${context.pageNumber}',
              style: const pw.TextStyle(
                  fontSize: 9, color: pdf.PdfColors.grey700)),
        );
    void addFixedPage(List<pw.Widget> widgets) {
      document.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
                child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: widgets,
            )),
            pw.SizedBox(height: 10),
            footer(context),
          ],
        ),
      ));
    }

    final categoryTablePages = <({
      String title,
      List<({String label, int points, int errors})> rows,
      bool includePoints
    })>[];
    for (final table in [
      (title: 'Punkte gesamt', kind: 'point', includePoints: true),
      (title: 'Fehler gesamt', kind: 'error', includePoints: false),
    ]) {
      final rows = _categoryTreeRows(
        events,
        match.players,
        kind: table.kind,
      );
      for (var start = 0; start < rows.length; start += 10) {
        categoryTablePages.add((
          title: table.title,
          rows: rows.skip(start).take(10).toList(),
          includePoints: table.includePoints,
        ));
      }
    }

    if (categoryTablePages.isEmpty) {
      categoryTablePages.add((
        title: 'Punkte und Fehler gesamt',
        rows: const <({String label, int points, int errors})>[],
        includePoints: true,
      ));
    }

    for (var index = 0; index < categoryTablePages.length; index++) {
      final page = categoryTablePages[index];
      addFixedPage([
        pw.Text(index == 0 ? title : '$title · ${page.title}',
            maxLines: 2,
            style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (index == 0) ...[
          pw.Text(
              '${_formatPdfDate(match.matchDateTime)} ${match.matchDateTime.hour.toString().padLeft(2, '0')}:${match.matchDateTime.minute.toString().padLeft(2, '0')} · ${match.matchType}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Text(match.location.isEmpty ? 'Ort offen' : match.location,
              maxLines: 2, style: const pw.TextStyle(fontSize: 10)),
          if (match.league.isNotEmpty || match.matchTag.isNotEmpty)
            pw.Text(
                [match.league, match.matchTag]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 10)),
          if (match.coaches.isNotEmpty)
            pw.Text(
                'Trainer: ${match.coaches.map((coach) => coach.name).join(', ')}',
                maxLines: 2,
                style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
              sourceMatches != null && sourceMatches.length > 1
                  ? '${sourceMatches.length} Spiele'
                  : '${match.opponentTeam} · Sätze ${_matchSetWins(match)} · ${_matchSetScores(match)}',
              maxLines: 2,
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            pw.Expanded(
                child: _summaryCard(
                    'Punkte',
                    '${points.values.fold<int>(0, (total, count) => total + count)}',
                    pdf.PdfColors.green)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _summaryCard(
                    'Fehler',
                    '${errors.values.fold<int>(0, (total, count) => total + count)}',
                    pdf.PdfColors.red)),
          ]),
          pw.SizedBox(height: 14),
        ],
        heading(page.title),
        pw.SizedBox(height: 8),
        if (page.rows.isNotEmpty)
          _categoryTreeSummaryTable(
            page.rows,
            includePoints: page.includePoints,
            includeErrors: !page.includePoints,
            compact: true,
          )
        else
          pw.Text('Noch keine Punkte oder Fehler erfasst.'),
      ]);
    }

    final matchTimes = sourceMatches == null
        ? const <DateTime>[]
        : sourceMatches.map((source) => source.matchDateTime).toList();
    document.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(32),
      maxPages:
          math.max(100, match.players.length + (sourceMatches?.length ?? 0)),
      footer: footer,
      build: (_) => [
        heading('Zeitverlauf · ${match.opponentTeam}'),
        pw.SizedBox(height: 12),
        pw.SizedBox(
            height: 310, child: _timelineChart(events, matchTimes: matchTimes)),
        if (sourceMatches != null && sourceMatches.length > 1) ...[
          pw.SizedBox(height: 18),
          heading('Spielvergleich · je Partie ab 0'),
          pw.SizedBox(height: 8),
          pw.SizedBox(
            height: 230,
            child: _timelineChart(
              events,
              trendSamples: matchComparisonTrendSamples(sourceMatches),
              comparisonMode: true,
              matchLabels: sourceMatches
                  .map((source) => source.opponentTeam.isEmpty
                      ? _formatPdfDate(source.matchDateTime)
                      : source.opponentTeam)
                  .toList(),
            ),
          ),
        ],
        pw.SizedBox(height: 22),
        heading('Spielübersicht'),
        pw.SizedBox(height: 8),
        _selectedMatchesTable(sourceMatches ?? [match]),
        if (match.players.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          heading('Spielerübersicht'),
          pw.SizedBox(height: 8),
          _playerTable(match, events),
        ],
      ],
    ));

    final showPlayerComparison =
        sourceMatches != null && sourceMatches.length > 1;
    final playersPerPage = showPlayerComparison ? 1 : 3;
    for (var start = 0; start < match.players.length; start += playersPerPage) {
      final players = match.players.skip(start).take(playersPerPage).toList();
      addFixedPage([
        heading('Zeitverlauf pro Spieler · ${match.opponentTeam}'),
        pw.SizedBox(height: 12),
        for (final player in players)
          pw.Expanded(
              child: pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(_playerStatisticsLabel(player, events),
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Expanded(
                    child: _timelineChart(
                  events
                      .where((event) => event.scorerIds.contains(player.id))
                      .toList(),
                  matchTimes: matchTimes,
                  trendSamples: matchPlayerTrendSamples(
                    match,
                    sourceMatches ?? <MatchGame>[match],
                    player.id,
                  ),
                )),
                if (showPlayerComparison) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    '${player.name} · Spielvergleich · je Partie ab 0',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Expanded(
                    child: _timelineChart(
                      const <MatchEvent>[],
                      trendSamples: matchPlayerTrendSamples(
                        match,
                        sourceMatches,
                        player.id,
                        resetPerMatch: true,
                      ),
                      comparisonMode: true,
                      matchLabels: sourceMatches
                          .map((source) => source.opponentTeam.isEmpty
                              ? _formatPdfDate(source.matchDateTime)
                              : source.opponentTeam)
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          )),
      ]);
    }

    if (match.players.isNotEmpty) {
      document.addPage(pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        maxPages: math.max(100, match.players.length + events.length),
        footer: footer,
        build: (_) => _playerErrorDetails(match, events, paginated: true),
      ));
    }

    final hasDetails = detailCategories
        .any((category) => category.contains(' · ') || category.contains(':'));
    if (hasDetails ||
        (includeFullMatchDetails &&
            (sourceMatches == null || sourceMatches.length <= 1))) {
      final history = includeFullMatchDetails
          ? _matchHistoryWidgets(match, events)
          : <pw.Widget>[];
      document.addPage(pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        maxPages: math.max(100, events.length + detailCategories.length),
        footer: footer,
        build: (_) => [
          if (hasDetails) ...[
            heading('Kategoriedetails · ${match.opponentTeam}'),
            pw.SizedBox(height: 10),
            pw.Text('Punkte gesamt'),
            pw.SizedBox(height: 4),
            _categoryTreeSummaryTable(
              _categoryTreeRows(events, match.players, kind: 'point'),
              includeErrors: false,
            ),
            pw.SizedBox(height: 8),
            pw.Text('Fehler gesamt'),
            pw.SizedBox(height: 4),
            _categoryTreeSummaryTable(
              _categoryTreeRows(events, match.players, kind: 'error'),
              includePoints: false,
            ),
          ],
          if (includeFullMatchDetails &&
              (sourceMatches == null || sourceMatches.length <= 1)) ...[
            pw.SizedBox(height: 18),
            heading('Spielbericht'),
            pw.SizedBox(height: 8),
            pw.Text(match.matchReport.trim().isEmpty
                ? 'Kein Spielbericht erfasst.'
                : match.matchReport),
            pw.SizedBox(height: 18),
            heading('Spielverlauf'),
            pw.SizedBox(height: 8),
            ...history,
          ],
        ],
      ));
    }
  }

  static List<List<String>> _matchHistoryRows(
    MatchGame match,
    List<MatchEvent> events,
  ) {
    final rows = <List<String>>[];
    var setNumber = 1;
    var us = 0;
    var opponent = 0;
    for (final event in events) {
      if (event.kind == 'point') {
        us++;
      } else if (event.kind == 'error') {
        opponent++;
      }
      final manualSetEnd = event.kind == 'manual_set_end';
      final setFinished = manualSetEnd ||
          (us >= 25 && us - opponent >= 2) ||
          (opponent >= 25 && opponent - us >= 2);
      final String action;
      final String details;
      if (event.kind == 'point') {
        action = 'Punkt';
        details = '${event.playerName} · ${event.category}';
      } else if (event.kind == 'error') {
        action = 'Fehler';
        details = '${event.playerName} · ${event.category}';
      } else if (event.kind == 'substitution') {
        action = 'Spielerwechsel';
        final outgoing = event.replacedPlayerName ?? 'Unbekannt';
        final outgoingNumber = event.replacedPlayerNumber == null
            ? ''
            : ' · ${event.replacedPlayerNumber}';
        final position = event.rotationPosition == null
            ? ''
            : ' · Position ${event.rotationPosition! + 1}';
        details = '$outgoing$outgoingNumber -> ${event.playerName}$position';
      } else if (event.kind == 'timeout') {
        action = 'Auszeit';
        details = event.category;
      } else if (event.kind == 'manual_set_end') {
        action = 'Satzende';
        details = 'Manuell';
      } else if (event.kind == 'match_end') {
        action = 'Spielende';
        details = 'Manuell beendet';
      } else {
        action = event.kind;
        details = event.category;
      }
      rows.add([
        _formatPdfDateTime(event.occurredAt).replaceAll('–', '-'),
        '$setNumber',
        '$us:$opponent',
        action,
        details,
      ]);
      if (setFinished) {
        setNumber++;
        us = 0;
        opponent = 0;
      }
    }
    return rows;
  }

  static List<pw.Widget> _matchHistoryWidgets(
    MatchGame match,
    List<MatchEvent> events,
  ) {
    return _matchHistoryWidgetsFromRows(_matchHistoryRows(match, events));
  }

  static List<pw.Widget> _matchHistoryWidgetsFromRows(List<List<String>> rows) {
    if (rows.isEmpty) {
      return <pw.Widget>[pw.Text('Noch keine Verlaufseinträge vorhanden.')];
    }
    const rowsPerTable = 18;
    return <pw.Widget>[
      for (var start = 0; start < rows.length; start += rowsPerTable)
        pw.Table(
          border: pw.TableBorder.all(
            color: pdf.PdfColors.grey400,
            width: 0.5,
          ),
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(0.6),
            2: pw.FlexColumnWidth(0.8),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(3.2),
          },
          children: [
            _tableRow(
              ['Zeit', 'Satz', 'Stand', 'Aktion', 'Spieler / Details'],
              header: true,
            ),
            for (final row in rows.skip(start).take(rowsPerTable))
              _tableRow(row),
          ],
        ),
    ];
  }

  static pdf.PdfPageFormat _pageFormat(bool landscape) {
    const portrait = pdf.PdfPageFormat.a4;
    return landscape
        ? pdf.PdfPageFormat(portrait.height, portrait.width)
        : portrait;
  }

  static Future<void> _addTiledPrintPages(
    pw.Document document,
    List<pw.Widget> Function() buildWidgets,
  ) async {
    const pageFormat = pdf.PdfPageFormat.a4;
    const seamMargin = 5 * pdf.PdfPageFormat.mm;
    const measurementMargins = pw.EdgeInsets.fromLTRB(
      seamMargin,
      0,
      seamMargin,
      0,
    );
    const printMargins = pw.EdgeInsets.fromLTRB(
      seamMargin,
      0,
      seamMargin,
      seamMargin,
    );
    final tileHeight = pageFormat.height - seamMargin;
    final measurementDocument = pw.Document();
    final measurementPage = pw.Page(
      pageFormat: pdf.PdfPageFormat(pageFormat.width, double.infinity),
      margin: measurementMargins,
      build: (_) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: buildWidgets(),
      ),
    );
    measurementDocument.addPage(measurementPage);
    await measurementDocument.save();
    final contentHeight = measurementPage.pageFormat.height;
    final pageCount = math.max(1, (contentHeight / tileHeight).ceil());

    for (var index = 0; index < pageCount; index++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: printMargins,
          clip: true,
          build: (_) => pw.Transform.rotateBox(
            angle: 0,
            unconstrained: true,
            child: pw.ConstrainedBox(
              constraints: pw.BoxConstraints.tightFor(
                width: pageFormat.width - seamMargin * 2,
              ),
              child: pw.Transform.translate(
                offset: pdf.PdfPoint(0, index * tileHeight),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: buildWidgets(),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  static List<pw.Widget> _individualMatchReportWidgets(
    MatchGame match, {
    bool includeMatchDetails = false,
    bool continuous = true,
  }) {
    final statisticsMatch = combineMatchesForStatistics([match]);
    final events = List<MatchEvent>.from(statisticsMatch.events)
      ..sort((a, b) {
        final timeOrder = a.occurredAt.compareTo(b.occurredAt);
        return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
      });
    final points = _eventSummary(events, 'point');
    final errors = _eventSummary(events, 'error');
    final categories = <String>{...points.keys, ...errors.keys}.toList()
      ..sort();
    final pointCount = events.where((event) => event.kind == 'point').length;
    final errorCount = events.where((event) => event.kind == 'error').length;

    return <pw.Widget>[
      pw.SizedBox(height: 16),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const pw.BoxDecoration(
          color: pdf.PdfColors.grey200,
          border: pw.Border(
            left: pw.BorderSide(color: pdf.PdfColors.blue, width: 3),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                match.opponentTeam.isEmpty
                    ? 'Einzelpartie · ${match.matchType}'
                    : 'Einzelpartie · vs. ${match.opponentTeam}',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              _formatPdfDateTime(match.matchDateTime),
              style: const pw.TextStyle(
                color: pdf.PdfColors.grey700,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
      if (includeMatchDetails) ...[
        pw.Text(
          'Spielbericht',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          match.matchReport.trim().isEmpty
              ? 'Kein Spielbericht erfasst.'
              : match.matchReport,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Spielverlauf',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        ..._matchHistoryWidgets(match, events),
        pw.SizedBox(height: 14),
      ],
      pw.Text(
        '${match.location.isEmpty ? 'Ort offen' : match.location} · ${match.matchType}',
        style: const pw.TextStyle(color: pdf.PdfColors.grey700, fontSize: 9),
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          pw.Expanded(
            child: _summaryCard('Punkte', '$pointCount', pdf.PdfColors.green),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _summaryCard('Fehler', '$errorCount', pdf.PdfColors.red),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _summaryCard(
              'Einträge',
              '${pointCount + errorCount}',
              pdf.PdfColors.blue,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Text(
        'Punkte und Fehler gesamt',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      if (categories.isNotEmpty) ...[
        pw.Text('Punkte gesamt',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _categoryTreeSummaryTable(
          _categoryTreeRows(events, statisticsMatch.players, kind: 'point'),
          includeErrors: false,
        ),
        pw.SizedBox(height: 10),
        pw.Text('Fehler gesamt',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _categoryTreeSummaryTable(
          _categoryTreeRows(events, statisticsMatch.players, kind: 'error'),
          includePoints: false,
        ),
      ],
      pw.SizedBox(height: 12),
      pw.Text(
        'Zeitverlauf',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.SizedBox(height: 170, child: _timelineChart(events)),
      if (statisticsMatch.players.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text(
          'Spielerübersicht',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _playerTable(statisticsMatch, events),
        pw.SizedBox(height: 12),
        pw.Text(
          'Zeitverlauf pro Spieler',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        for (final player in statisticsMatch.players) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            _playerStatisticsLabel(player, events),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(
            height: 120,
            child: _timelineChart(
              events
                  .where((event) => event.scorerIds.contains(player.id))
                  .toList(),
            ),
          ),
        ],
        ..._playerErrorDetails(statisticsMatch, events),
      ],
    ];
  }

  static String _playerStatisticsLabel(
      MatchPlayer player, List<MatchEvent> events) {
    final ownEvents =
        events.where((event) => event.scorerIds.contains(player.id));
    final points = ownEvents.where((event) => event.kind == 'point').length;
    final errors = ownEvents.where((event) => event.kind == 'error').length;
    return '${player.name} · ${player.number}  |  Punkte: $points  |  Fehler: $errors';
  }

  static List<pw.Widget> _playerErrorDetails(
      MatchGame match, List<MatchEvent> events,
      {bool paginated = false}) {
    return [
      pw.SizedBox(height: 16),
      pw.Text('Fehler pro Spieler nach Art',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      for (final player in match.players) ...[
        if (paginated) pw.NewPage(freeSpace: 120),
        pw.SizedBox(height: 12),
        pw.Text(_playerStatisticsLabel(player, events),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _playerErrorTable(player, events),
      ],
    ];
  }

  static pw.Widget _playerErrorTable(
      MatchPlayer player, List<MatchEvent> events) {
    final rows = _categoryTreeRows(
      events,
      [player],
      kind: 'error',
      playerId: player.id,
    );
    return _categoryTreeSummaryTable(
      rows,
      includePoints: false,
    );
  }

  static Map<String, int> _eventSummary(
    List<MatchEvent> events,
    String kind,
  ) {
    final summary = <String, int>{};
    for (final event in events.where((entry) => entry.kind == kind)) {
      summary[event.category] = (summary[event.category] ?? 0) + 1;
    }
    return summary;
  }

  static pw.Widget _summaryCard(
      String label, String value, pdf.PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.12),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _categoryTreeSummaryTable(
    List<({String label, int points, int errors})> rows, {
    bool compact = false,
    bool includePoints = true,
    bool includeErrors = true,
  }) {
    final totalOnly = includePoints != includeErrors;
    final columns = <String>[
      'Art / Wertung',
      if (totalOnly)
        'Gesamt'
      else ...[
        if (includePoints) 'Punkte',
        if (includeErrors) 'Fehler',
      ],
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        for (var index = 1; index < columns.length; index++)
          index: const pw.FlexColumnWidth(1),
      },
      children: [
        _tableRow(columns, header: true, padding: compact ? 3 : 6),
        for (final row in rows)
          _tableRow([
            row.label,
            if (includePoints) '${row.points}',
            if (includeErrors) '${row.errors}',
          ], header: row.label.trim() == 'Gesamt', padding: compact ? 3 : 6),
      ],
    );
  }

  static List<({String label, int points, int errors})> _categoryTreeRows(
      List<MatchEvent> events, List<MatchPlayer> players,
      {String? kind, int? playerId}) {
    final rows = <({String label, int points, int errors})>[];
    void addNode(CategoryStatisticNode node, List<String> parentPath) {
      final path = [...parentPath, node.label];
      rows.add((
        label:
            '${List.filled(node.depth * 2, ' ').join()}${path.length > 2 ? path.skip(1).join(' / ') : node.label}',
        points: playerId == null
            ? node.pointsCount
            : node.pointsByPlayer[playerId] ?? 0,
        errors: playerId == null
            ? node.errorsCount
            : node.errorsByPlayer[playerId] ?? 0,
      ));
      for (final child in node.children) {
        addNode(child, path);
      }
    }

    for (final node in categoryStatisticsTree(
      events,
      players,
      kind: kind,
    )) {
      if (node.hasData) addNode(node, const <String>[]);
    }
    return rows;
  }

  static pw.Widget _timelineChart(
    List<MatchEvent> events, {
    List<DateTime> matchTimes = const <DateTime>[],
    List<MatchTrendSample>? trendSamples,
    bool comparisonMode = false,
    List<String> matchLabels = const <String>[],
  }) {
    if (trendSamples != null) {
      return _playerTimelineChartFromSamples(
        trendSamples,
        comparisonMode: comparisonMode,
        matchLabels: matchLabels,
      );
    }
    final timelineEvents = events
        .where((event) =>
            event.kind == 'point' ||
            event.kind == 'error' ||
            event.kind == 'manual_set_end')
        .toList()
      ..sort((first, second) {
        final timeOrder = first.occurredAt.compareTo(second.occurredAt);
        return timeOrder != 0 ? timeOrder : first.id.compareTo(second.id);
      });
    if (timelineEvents.isEmpty) return pw.Text('Keine Punktdaten.');

    final sortedMatchTimes = List<DateTime>.from(matchTimes)..sort();
    final matchStartPositions = sortedMatchTimes
        .map((time) => timelineEvents.indexWhere(
              (event) => !event.occurredAt.isBefore(time),
            ))
        .where((index) => index >= 0)
        .map((index) => index + 1)
        .toSet()
        .toList()
      ..sort();
    if (matchStartPositions.isEmpty || matchStartPositions.first != 1) {
      matchStartPositions.insert(0, 1);
    }
    final matchEndPositions = <int>{};
    for (var index = 0; index < matchStartPositions.length; index++) {
      final endPosition = index + 1 < matchStartPositions.length
          ? matchStartPositions[index + 1] - 1
          : timelineEvents.length;
      if (endPosition > 0) matchEndPositions.add(endPosition);
    }

    var points = 0;
    var errors = 0;
    var opponentErrors = 0;
    var ourSetScore = 0;
    var opponentSetScore = 0;
    var setNumber = 1;
    final samples = <MatchTrendSample>[
      MatchTrendSample(
        time: timelineEvents.first.occurredAt,
        points: 0,
        errors: 0,
        opponentErrors: 0,
        beginsMatch: true,
        setNumber: setNumber,
      ),
    ];
    for (var index = 0; index < timelineEvents.length; index++) {
      final event = timelineEvents[index];
      final sampleIndex = index + 1;
      if (matchStartPositions.contains(sampleIndex) && sampleIndex != 1) {
        setNumber = 1;
        ourSetScore = 0;
        opponentSetScore = 0;
      }
      if (event.kind == 'point') {
        points++;
        ourSetScore++;
        if (event.category == 'Gegnerfehler') opponentErrors++;
      } else if (event.kind == 'error') {
        errors++;
        opponentSetScore++;
      }
      final endsSet = event.kind == 'manual_set_end' ||
          (ourSetScore >= 25 && ourSetScore - opponentSetScore >= 2) ||
          (opponentSetScore >= 25 && opponentSetScore - ourSetScore >= 2);
      final endsMatch = matchEndPositions.contains(sampleIndex);
      samples.add(
        MatchTrendSample(
          time: event.occurredAt,
          points: points,
          errors: errors,
          opponentErrors: opponentErrors,
          beginsMatch: matchStartPositions.contains(sampleIndex),
          setNumber: setNumber,
          endsSet: endsSet,
          endsMatch: endsMatch,
        ),
      );
      if (endsSet) {
        setNumber++;
        ourSetScore = 0;
        opponentSetScore = 0;
      }
      if (endsMatch) {
        setNumber = 1;
        ourSetScore = 0;
        opponentSetScore = 0;
      }
    }
    return _playerTimelineChartFromSamples(samples);
  }

  static pw.Widget _playerTimelineChartFromSamples(
    List<MatchTrendSample> samples, {
    bool comparisonMode = false,
    List<String> matchLabels = const <String>[],
  }) {
    if (samples.isEmpty) return pw.Text('Keine Punktdaten.');

    final pointData = <pw.PointChartValue>[
      for (var index = 0; index < samples.length; index++)
        pw.PointChartValue(index.toDouble(), samples[index].points.toDouble()),
    ];
    final errorData = <pw.PointChartValue>[
      for (var index = 0; index < samples.length; index++)
        pw.PointChartValue(index.toDouble(), samples[index].errors.toDouble()),
    ];
    final opponentErrorData = <pw.PointChartValue>[
      for (var index = 0; index < samples.length; index++)
        pw.PointChartValue(
          index.toDouble(),
          samples[index].opponentErrors.toDouble(),
        ),
    ];
    final end = (samples.length - 1).toDouble();
    if (end <= 0) return pw.Text('Keine Punktdaten.');
    final chartEnd = comparisonMode && matchLabels.isNotEmpty
        ? matchLabels.length.toDouble()
        : end;
    final middle = chartEnd / 2;
    final labelAt = (double position) => _formatPdfDateTime(
          samples[position.round().clamp(0, samples.length - 1)].time,
        );
    final dateLabels = [labelAt(0), labelAt(middle), labelAt(end)];
    final maxValue = samples.fold<int>(0, (maximum, sample) {
      return math.max(
        maximum,
        math.max(
          math.max(sample.points, sample.errors),
          sample.opponentErrors,
        ),
      );
    }).toDouble();
    pdf.PdfColor? statusColor(MatchTrendSample sample) {
      if (sample.playerInMatchRoster == null) return null;
      if (sample.playerOnCourt == true) return pdf.PdfColor(0.82, 0.93, 0.82);
      return sample.playerInMatchRoster!
          ? pdf.PdfColor(1, 0.94, 0.7)
          : pdf.PdfColor(0.96, 0.82, 0.82);
    }

    pw.Widget markerLegend({required String label, bool doubleLine = false}) =>
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(width: 2.5, height: 9, color: pdf.PdfColors.grey800),
            if (doubleLine) ...[
              pw.SizedBox(width: 2),
              pw.Container(
                width: 2.5,
                height: 9,
                color: pdf.PdfColors.grey800,
              ),
            ],
            pw.SizedBox(width: 4),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ],
        );

    final hasPlayerStatus =
        samples.any((sample) => sample.playerInMatchRoster != null);
    pw.Widget comparisonStatusBands() {
      final segments = <int, List<MatchTrendSample>>{};
      for (final sample in samples) {
        (segments[sample.matchIndex] ??= []).add(sample);
      }
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final segment in segments.values)
            pw.Expanded(
              child: segment.last.time.isAfter(segment.first.time)
                  ? pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < segment.length - 1; index++)
                          if (segment[index + 1]
                              .time
                              .isAfter(segment[index].time))
                            pw.Expanded(
                              flex: segment[index + 1]
                                  .time
                                  .difference(segment[index].time)
                                  .inMilliseconds,
                              child: pw.Container(
                                color: statusColor(segment[index]),
                              ),
                            ),
                      ],
                    )
                  : pw.Container(color: statusColor(segment.first)),
            ),
        ],
      );
    }

    final comparisonDatasets = <pw.LineDataSet<pw.PointChartValue>>[];
    if (comparisonMode) {
      final matchIndexes =
          samples.map((sample) => sample.matchIndex).toSet().toList()..sort();
      for (final matchIndex in matchIndexes) {
        final matchSamples =
            samples.where((sample) => sample.matchIndex == matchIndex).toList();
        if (matchSamples.isEmpty) continue;
        final duration = math.max(
          1,
          matchSamples.last.time
              .difference(matchSamples.first.time)
              .inMilliseconds,
        );
        double xForIndex(int index) =>
            matchIndex +
            matchSamples[index]
                    .time
                    .difference(matchSamples.first.time)
                    .inMilliseconds /
                duration;
        comparisonDatasets.addAll([
          pw.LineDataSet<pw.PointChartValue>(
            data: [
              for (var index = 0; index < matchSamples.length; index++)
                pw.PointChartValue(
                  xForIndex(index),
                  matchSamples[index].points.toDouble(),
                ),
            ],
            color: pdf.PdfColors.green,
            drawPoints: false,
            lineWidth: 2,
            isCurved: false,
          ),
          pw.LineDataSet<pw.PointChartValue>(
            data: [
              for (var index = 0; index < matchSamples.length; index++)
                pw.PointChartValue(
                  xForIndex(index),
                  matchSamples[index].errors.toDouble(),
                ),
            ],
            color: pdf.PdfColors.red,
            drawPoints: false,
            lineWidth: 2,
            isCurved: false,
          ),
          pw.LineDataSet<pw.PointChartValue>(
            data: [
              for (var index = 0; index < matchSamples.length; index++)
                pw.PointChartValue(
                  xForIndex(index),
                  matchSamples[index].opponentErrors.toDouble(),
                ),
            ],
            color: pdf.PdfColors.blue,
            drawPoints: false,
            lineWidth: 2,
            isCurved: false,
          ),
        ]);
        for (var index = 0; index < matchSamples.length; index++) {
          final sample = matchSamples[index];
          if (!sample.endsSet && !sample.endsMatch) continue;
          final x = xForIndex(index);
          for (final offset in sample.endsMatch ? [0.0, -0.008] : [0.0]) {
            comparisonDatasets.add(pw.LineDataSet<pw.PointChartValue>(
              data: [
                pw.PointChartValue(x + offset, 0),
                pw.PointChartValue(x + offset, math.max(1, maxValue)),
              ],
              color: pdf.PdfColors.grey800,
              lineWidth: 2,
              drawPoints: false,
              isCurved: false,
            ));
          }
        }
      }
    }
    final axisPositions = comparisonMode && matchLabels.isNotEmpty
        ? <double>[
            0,
            for (var index = 0; index < matchLabels.length; index++)
              index + 0.5,
            matchLabels.length.toDouble(),
          ]
        : <double>[0, middle, end];

    String axisLabel(double value) {
      if (comparisonMode && matchLabels.isNotEmpty) {
        if (value <= 0 || value >= matchLabels.length) return '';
        final index = (value - 0.5).round().clamp(0, matchLabels.length - 1);
        return matchLabels[index];
      }
      if (value <= 0) return dateLabels.first;
      if (value >= end) return dateLabels.last;
      return dateLabels[1];
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (comparisonMode)
              pw.Wrap(
                spacing: 8,
                runSpacing: 3,
                children: [
                  _chartLegend(pdf.PdfColors.green, 'Punkte'),
                  _chartLegend(pdf.PdfColors.red, 'Fehler'),
                  _chartLegend(pdf.PdfColors.blue, 'Gegnerfehler'),
                ],
              )
            else
              pw.Row(
                children: [
                  _chartLegend(pdf.PdfColors.green, 'Punkte'),
                  pw.SizedBox(width: 12),
                  _chartLegend(pdf.PdfColors.red, 'Fehler'),
                  pw.SizedBox(width: 12),
                  _chartLegend(pdf.PdfColors.blue, 'Gegnerfehler'),
                ],
              ),
            pw.SizedBox(height: 3),
            pw.Wrap(
              spacing: 8,
              runSpacing: 3,
              children: [
                if (hasPlayerStatus) ...[
                  _chartLegend(pdf.PdfColor(0.82, 0.93, 0.82), 'Auf dem Feld'),
                  pw.SizedBox(width: 8),
                  _chartLegend(pdf.PdfColor(1, 0.94, 0.7), 'Bank · gespielt'),
                  pw.SizedBox(width: 8),
                  _chartLegend(
                      pdf.PdfColor(0.96, 0.82, 0.82), 'Nicht eingesetzt'),
                  pw.SizedBox(width: 12),
                ],
                markerLegend(label: 'Satzende'),
                pw.SizedBox(width: 8),
                markerLegend(label: 'Spielende', doubleLine: true),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              if (hasPlayerStatus)
                pw.Positioned.fill(
                  child: comparisonMode
                      ? comparisonStatusBands()
                      : pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 0;
                                index < samples.length - 1;
                                index++)
                              pw.Expanded(
                                child: pw.Container(
                                  color: statusColor(samples[index]),
                                ),
                              ),
                          ],
                        ),
                ),
              pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis<double>(
                    comparisonMode ? axisPositions : <double>[0, middle, end],
                    format: (value) => axisLabel(value.toDouble()),
                    textStyle: const pw.TextStyle(fontSize: 7),
                  ),
                  yAxis: pw.FixedAxis<double>(
                    [0, math.max(1, maxValue)],
                    format: (value) => value.toStringAsFixed(0),
                    divisions: false,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                datasets: comparisonMode
                    ? comparisonDatasets
                    : [
                        pw.LineDataSet<pw.PointChartValue>(
                          data: pointData,
                          legend: 'Punkte',
                          color: pdf.PdfColors.green,
                          drawPoints: false,
                          isCurved: true,
                        ),
                        pw.LineDataSet<pw.PointChartValue>(
                          data: errorData,
                          legend: 'Fehler',
                          color: pdf.PdfColors.red,
                          drawPoints: false,
                          isCurved: true,
                        ),
                        pw.LineDataSet<pw.PointChartValue>(
                          data: opponentErrorData,
                          legend: 'Gegnerfehler',
                          color: pdf.PdfColors.blue,
                          drawPoints: false,
                          isCurved: true,
                        ),
                      ],
              ),
              if (!comparisonMode)
                pw.Positioned.fill(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 1; index < samples.length; index++)
                        pw.Expanded(
                          child: pw.Container(
                            alignment: pw.Alignment.centerRight,
                            child: samples[index].endsMatch
                                ? pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      pw.Container(
                                        width: 2.5,
                                        color: pdf.PdfColors.grey800,
                                      ),
                                      pw.SizedBox(width: 2),
                                      pw.Container(
                                        width: 2.5,
                                        color: pdf.PdfColors.grey800,
                                      ),
                                    ],
                                  )
                                : samples[index].endsSet
                                    ? pw.Container(
                                        width: 2.5,
                                        color: pdf.PdfColors.grey800,
                                      )
                                    : null,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _selectedMatchesTable(List<MatchGame> matches) {
    return pw.Table(
      border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.7),
        3: pw.FlexColumnWidth(0.8),
        4: pw.FlexColumnWidth(3),
      },
      children: [
        _tableRow(
          ['Partie', 'Spielart', 'Spielzeit', 'Sätze', 'Ergebnis pro Satz'],
          header: true,
        ),
        for (final sourceMatch in matches)
          _tableRow([
            sourceMatch.opponentTeam.isEmpty
                ? 'Ohne Gegner'
                : 'vs. ${sourceMatch.opponentTeam}',
            sourceMatch.matchType,
            _formatPdfDateTime(sourceMatch.matchDateTime),
            _matchSetWins(sourceMatch),
            _matchSetScores(sourceMatch),
          ]),
        if (matches.any(
          (match) =>
              computeMatchSetResults(match).any((set) => !set.isFinished),
        ))
          _tableRow(['* Laufender Satz', '', '', '', '']),
      ],
    );
  }

  static String _matchSetWins(MatchGame match) {
    var us = 0;
    var opponent = 0;
    for (final set
        in computeMatchSetResults(match).where((set) => set.isFinished)) {
      if (set.us > set.opponent) {
        us++;
      } else if (set.opponent > set.us) {
        opponent++;
      }
    }
    return '$us:$opponent';
  }

  static String _matchSetScores(MatchGame match) =>
      computeMatchSetResults(match)
          .map((set) => '${set.us}:${set.opponent}${set.isFinished ? '' : '*'}')
          .join(' · ');

  static pw.Widget _playerTable(MatchGame match, List<MatchEvent> events) {
    return pw.Table(
      border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        _tableRow(['Spieler', 'Punkte', 'Fehler'], header: true),
        for (final player in match.players)
          _tableRow([
            '${player.name} · ${player.number}',
            '${events.where((event) => event.scorerIds.contains(player.id) && event.kind == 'point').length}',
            '${events.where((event) => event.scorerIds.contains(player.id) && event.kind == 'error').length}',
          ]),
      ],
    );
  }

  static pw.TableRow _tableRow(List<String> values,
      {bool header = false, double padding = 6}) {
    return pw.TableRow(
      decoration:
          header ? const pw.BoxDecoration(color: pdf.PdfColors.grey200) : null,
      children: [
        for (var index = 0; index < values.length; index++)
          pw.Padding(
            padding: pw.EdgeInsets.all(padding),
            child: pw.Text(
              values[index],
              textAlign: index == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _chartLegend(pdf.PdfColor color, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 9, height: 9, color: color),
        pw.SizedBox(width: 5),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static String _formatPdfDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  static String _formatPdfDateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String encodeBackup(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<void> _exportJson(BuildContext context, String dialogTitle,
      String suggestedName, String jsonText,
      {String extension = 'json'}) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonText));

    try {
      final selectedPath = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );

      if (selectedPath == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export gespeichert: $selectedPath')),
        );
      }
    } catch (_) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$suggestedName');
      await file.writeAsString(jsonText);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export gespeichert unter ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static Future<void> _shareJson(
      String suggestedName, String jsonText, String subject,
      {String mimeType = 'application/json'}) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$suggestedName');
    await file.writeAsString(jsonText);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
      ),
    );
  }

  static Future<void> shareOrSaveJson(
    BuildContext context, {
    required String suggestedName,
    required String jsonText,
    required String subject,
    required String dialogTitle,
    bool vace = false,
  }) async {
    final exportName = vace
        ? suggestedName.replaceFirst(RegExp(r'\.json$'), '.vace')
        : suggestedName;
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows) {
      await _exportJson(
        context,
        dialogTitle,
        exportName,
        jsonText,
        extension: vace ? 'vace' : 'json',
      );
      return;
    }

    await _shareJson(
      exportName,
      jsonText,
      subject,
      mimeType: vace ? 'application/vnd.volleyace' : 'application/json',
    );
  }

  static Future<void> exportCompleteMatchPdf(
      BuildContext context, MatchGame match,
      {List<MatchGame>? sourceMatches}) {
    final opponent = match.opponentTeam.isEmpty ? 'Spiel' : match.opponentTeam;
    return exportMatchStatsPdf(
      context,
      match,
      title: sourceMatches != null && sourceMatches.length > 1
          ? 'Gesamtexport · ${sourceMatches.length} Spiele'
          : 'Gesamtexport · $opponent',
      sourceMatches: sourceMatches,
      includeFullMatchDetails: true,
    );
  }

  static Future<void> exportMatchStatsPdf(
    BuildContext context,
    MatchGame match, {
    required String title,
    List<MatchGame>? sourceMatches,
    bool landscape = true,
    bool? continuous,
    bool tiled = false,
    bool includeFullMatchDetails = false,
  }) async {
    final layout = tiled
        ? _PdfExportLayout.tiledA4
        : continuous == null
            ? await _choosePdfLayout(context)
            : continuous
                ? _PdfExportLayout.continuous
                : _PdfExportLayout.a4;
    if (layout == null || !context.mounted) return;
    final useContinuous = layout == _PdfExportLayout.continuous;
    final useTiled = layout == _PdfExportLayout.tiledA4;
    final bytes = await buildMatchStatsPdf(
      match,
      title: title,
      sourceMatches: sourceMatches,
      landscape: useContinuous ? landscape : false,
      continuous: useContinuous,
      tiled: useTiled,
      includeFullMatchDetails: includeFullMatchDetails,
    );
    if (!context.mounted) return;
    final platform = Theme.of(context).platform;
    final suggestedName = matchExportFileName(
      sourceMatches == null || sourceMatches.isEmpty ? [match] : sourceMatches,
      extension: 'pdf',
      suffix:
          '${includeFullMatchDetails ? 'gesamt' : 'statistik'}_${switch (layout) {
        _PdfExportLayout.continuous => 'endlos',
        _PdfExportLayout.a4 => 'a4-hoch',
        _PdfExportLayout.tiledA4 => 'a4-kachel',
      }}',
    );

    if (platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows) {
      try {
        final selectedPath = await FilePicker.saveFile(
          dialogTitle: 'PDF speichern',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          bytes: bytes,
        );
        if (selectedPath == null || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF gespeichert: $selectedPath')),
        );
      } catch (_) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$suggestedName');
        await file.writeAsBytes(bytes, flush: true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert unter ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$suggestedName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: title,
      ),
    );
  }

  static Future<void> exportMatchHistoryPdf(
    BuildContext context,
    MatchGame match,
  ) async {
    final layout = await _choosePdfLayout(context);
    if (layout == null || !context.mounted) return;
    final continuous = layout == _PdfExportLayout.continuous;
    final tiled = layout == _PdfExportLayout.tiledA4;
    final bytes = await buildMatchHistoryPdf(
      match,
      continuous: continuous,
      tiled: tiled,
    );
    if (!context.mounted) return;
    final platform = Theme.of(context).platform;
    final suggestedName = matchExportFileName(
      [match],
      extension: 'pdf',
      suffix: 'verlauf_${switch (layout) {
        _PdfExportLayout.continuous => 'endlos',
        _PdfExportLayout.a4 => 'a4-hoch',
        _PdfExportLayout.tiledA4 => 'a4-kachel',
      }}',
    );

    if (platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows) {
      try {
        final selectedPath = await FilePicker.saveFile(
          dialogTitle: 'PDF speichern',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          bytes: bytes,
        );
        if (selectedPath == null || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF gespeichert: $selectedPath')),
        );
      } catch (_) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$suggestedName');
        await file.writeAsBytes(bytes, flush: true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert unter ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$suggestedName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Spielverlauf',
      ),
    );
  }

  static Future<void> exportBackup(
      BuildContext context, Database database) async {
    final payload = await buildFullBackup(database);
    final jsonText = encodeBackup(payload);
    final suggestedName =
        'volleyace-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.vace';
    await _exportJson(
      context,
      'VolleyAce Export speichern',
      suggestedName,
      jsonText,
      extension: 'vace',
    );
  }

  static Future<void> shareFullBackup(
    BuildContext context,
    Database database,
  ) async {
    final payload = await buildFullBackup(database);
    final jsonText = encodeBackup(payload);
    final suggestedName =
        'volleyace-gesamt-${DateTime.now().millisecondsSinceEpoch}.json';
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: 'VolleyAce Komplettbackup',
      dialogTitle: 'Komplettbackup teilen',
      vace: true,
    );
  }

  static Future<void> exportTeam(
    BuildContext context,
    Database database,
    Team team,
  ) async {
    final bundle = await buildTeamBundle(database, team);
    if (!context.mounted) return;
    final jsonText = encodeBackup(bundle);
    final suggestedName =
        'volleyace-team-${_safeFileName(team.name)}-${DateTime.now().toIso8601String().replaceAll(':', '-')}.vace';
    await _exportJson(
      context,
      'Team exportieren',
      suggestedName,
      jsonText,
      extension: 'vace',
    );
  }

  static Future<void> shareTeam(
    BuildContext context,
    Database database,
    Team team,
  ) async {
    final bundle = await buildTeamBundle(database, team);
    if (!context.mounted) return;
    final jsonText = encodeBackup(bundle);
    final suggestedName =
        'volleyace-team-${_safeFileName(team.name)}-${DateTime.now().millisecondsSinceEpoch}.json';
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: 'VolleyAce Team-Backup',
      dialogTitle: 'Team speichern',
      vace: true,
    );
  }

  static Future<void> exportMatch(BuildContext context, MatchGame match) async {
    final jsonText = encodeBackup(buildMatchBackup(match));
    final suggestedName = matchExportFileName([match], extension: 'vace');
    await _exportJson(
      context,
      'Spiel exportieren',
      suggestedName,
      jsonText,
      extension: 'vace',
    );
  }

  static Future<void> shareMatch(BuildContext context, MatchGame match) async {
    final jsonText = encodeBackup(buildMatchBackup(match));
    final suggestedName = matchExportFileName([match], extension: 'vace');
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: 'VolleyAce Spiel-Backup',
      dialogTitle: 'Spiel speichern',
      vace: true,
    );
  }

  static Future<void> shareMatches(
    BuildContext context,
    List<MatchGame> matches,
  ) async {
    if (matches.isEmpty) return;
    final jsonText = encodeBackup(buildMatchesBackup(matches));
    final suggestedName = matchExportFileName(matches, extension: 'vace');
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: '${matches.length} VolleyAce-Punktewertungen',
      dialogTitle: 'Punktewertungen speichern',
      vace: true,
    );
  }

  static Future<Map<String, dynamic>?> _pickJsonMap(String dialogTitle) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json', 'vace'],
      withData: false,
    );
    if (result.isEmpty) return null;
    final path = result.single.path;
    if (path == null) return null;

    final rawText = await File(path).readAsString();
    final decoded = jsonDecode(rawText);
    if (decoded is! Map) {
      throw const FormatException('Ungültiges Backup-Format.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<bool> importFullBackup(
    BuildContext context,
    Database database,
  ) async {
    final data = await _pickJsonMap('VolleyAce Export importieren');
    if (data == null) return false;

    return _importFullBackupData(context, database, data);
  }

  static Future<bool> importVaceBytes(
    BuildContext context,
    Database database,
    Uint8List bytes,
  ) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Die .vace-Datei ist ungültig.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['teams'] is List && data['matchStats'] is Map) {
      return _importFullBackupData(
        context,
        database,
        data,
        skipConfirmation: true,
      );
    }
    if (data['type'] == 'matches' && data['matches'] is List) {
      return _importMatchesBackup(
        context,
        database,
        data['matches'] as List,
        skipConfirmation: true,
      );
    }
    if (data['type'] == 'match' && data['match'] is Map) {
      return _importMatchesBackup(
        context,
        database,
        <dynamic>[data['match']],
        skipConfirmation: true,
      );
    }
    if ((data['type'] == 'team' || data['type'] == 'team-bundle') &&
        data['team'] is Map) {
      return _importFullBackupData(
        context,
        database,
        <String, dynamic>{
          ...data,
          'teams': <dynamic>[data['team']],
          'matchStats': data['matchStats'] is Map
              ? data['matchStats']
              : <String, dynamic>{'matches': <dynamic>[]},
        },
        skipConfirmation: true,
      );
    }
    if (data['type'] == 'training' && data['training'] is Map) {
      return _importVaceStoreRecord(
        context,
        database,
        _trainingStore,
        'sessions',
        'sessions',
        Map<String, dynamic>.from(data['training'] as Map),
        kind: 'Training',
      );
    }
    if (data['type'] == 'training-plan' && data['plan'] is Map) {
      return _importVaceStoreRecord(
        context,
        database,
        _trainingPlansStore,
        'plans',
        'plans',
        Map<String, dynamic>.from(data['plan'] as Map),
        kind: 'Trainingsplan',
      );
    }
    if (data['type'] == 'training-exercise' && data['exercise'] is Map) {
      return _importVaceStoreRecord(
        context,
        database,
        _trainingExercisesStore,
        'exercises',
        'exercises',
        Map<String, dynamic>.from(data['exercise'] as Map),
        kind: 'Trainingsübung',
      );
    }
    if (data['type'] == 'tactics-board' && data['pages'] is List) {
      final importedTactic = <String, dynamic>{
        'id': data['id'] is num
            ? data['id']
            : DateTime.now().millisecondsSinceEpoch,
        'name': data['name'] is String ? data['name'] : 'Unbenannt',
        'pages': data['pages'],
      };
      final currentBoard = await _tacticsStore.record('board').get(database);
      final current = currentBoard == null
          ? <Map<String, dynamic>>[]
          : _backupRecords(currentBoard, 'tactics');
      final tactics = await _mergeRecords(
        context,
        current,
        [importedTactic],
        kind: 'Taktik',
      );
      await _tacticsStore.record('board').put(database, {
        ...?currentBoard,
        'tactics': tactics,
      });
      return true;
    }
    if (data['type'] == 'scoreboard-snapshot' && data['state'] is Map) {
      final savedAt = data['savedAt'] is String
          ? DateTime.tryParse(data['savedAt'] as String) ?? DateTime.now()
          : DateTime.now();
      final importedSnapshot = <String, dynamic>{
        'id': data['id'] is String
            ? data['id']
            : savedAt.millisecondsSinceEpoch.toString(),
        'name': data['name'] is String ? data['name'] : 'Punktestand',
        'savedAtMillis': savedAt.millisecondsSinceEpoch,
        'state': data['state'],
      };
      final currentSnapshots =
          await _scoreboardStore.record('snapshots').get(database);
      final snapshots = await _mergeRecords(
        context,
        _backupRecords(currentSnapshots, 'items'),
        [importedSnapshot],
        kind: 'Punktetafelstand',
      );
      await _scoreboardStore
          .record('snapshots')
          .put(database, {'items': snapshots});
      return true;
    }
    throw const FormatException('Dieser .vace-Export wird nicht unterstützt.');
  }

  static Future<bool> _importVaceStoreRecord(
    BuildContext context,
    Database database,
    StoreRef<String, Map<String, dynamic>> store,
    String recordKey,
    String listKey,
    Map<String, dynamic> incoming, {
    required String kind,
  }) async {
    final currentData = await store.record(recordKey).get(database);
    final current = _backupRecords(currentData, listKey);
    if (recordKey == 'sessions' && currentData == null) {
      final legacy = await store.record('current').get(database);
      if (legacy != null) current.add(legacy);
    }
    final merged = await _mergeRecords(
      context,
      current,
      [incoming],
      kind: kind,
    );
    await store.record(recordKey).put(database, {listKey: merged});
    return true;
  }

  static List<Map<String, dynamic>> _backupRecords(
    Object? data,
    String key,
  ) {
    final values = data is Map ? data[key] : null;
    return values is List
        ? values
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList()
        : <Map<String, dynamic>>[];
  }

  static String _canonicalJson(Object? value) {
    Object? normalize(Object? item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return <String, dynamic>{
          for (final key in keys) key: normalize(item[key]),
        };
      }
      if (item is List) return item.map(normalize).toList();
      return item;
    }

    return jsonEncode(normalize(value));
  }

  static int? _recordTimestamp(Map<String, dynamic> record) {
    final timestamps = <int>[];
    for (final key in [
      'updatedAtMillis',
      'modifiedAtMillis',
      'savedAtMillis',
      'dateMillis',
      'matchDateTimeMillis',
      'createdAtMillis',
      'wonAtMillis',
    ]) {
      if (record[key] is num) timestamps.add((record[key] as num).toInt());
      if (record[key] is String) {
        final parsed = DateTime.tryParse(record[key] as String);
        if (parsed != null) timestamps.add(parsed.millisecondsSinceEpoch);
      }
    }
    for (final key in ['events', 'historyEntries', 'completedSets']) {
      final values = record[key];
      if (values is! List) continue;
      for (final value in values.whereType<Map>()) {
        for (final timestampKey in [
          'occurredAtMillis',
          'wonAtMillis',
        ]) {
          if (value[timestampKey] is num) {
            timestamps.add((value[timestampKey] as num).toInt());
          }
        }
      }
    }
    if (timestamps.isEmpty) return null;
    return timestamps
        .reduce((first, second) => first > second ? first : second);
  }

  static String _recordLabel(Map<String, dynamic> record) {
    for (final key in ['name', 'topic', 'title', 'opponentTeam']) {
      final value = record[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'ID ${record['id'] ?? '?'}';
  }

  static Future<bool> _askImportDuplicate(
    BuildContext context,
    String kind,
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) async {
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Doppelte Daten: $kind'),
            content: Text(
              '„${_recordLabel(current)}“ ist bereits vorhanden. Welche Version soll behalten werden?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vorhandene behalten'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Import übernehmen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<List<Map<String, dynamic>>> _mergeRecords(
    BuildContext context,
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming, {
    required String kind,
  }) async {
    final merged = List<Map<String, dynamic>>.from(current);
    for (final imported in incoming) {
      final id = imported['id'];
      final index =
          id == null ? -1 : merged.indexWhere((record) => record['id'] == id);
      if (index < 0) {
        merged.add(imported);
        continue;
      }

      final existing = merged[index];
      if (_canonicalJson(existing) == _canonicalJson(imported)) continue;
      final existingTimestamp = _recordTimestamp(existing);
      final importedTimestamp = _recordTimestamp(imported);
      if (existingTimestamp != null &&
          importedTimestamp != null &&
          existingTimestamp != importedTimestamp) {
        if (importedTimestamp > existingTimestamp) merged[index] = imported;
        continue;
      }
      if (await _askImportDuplicate(context, kind, existing, imported)) {
        merged[index] = imported;
      }
    }
    return merged;
  }

  static Future<List<Map<String, dynamic>>> mergeImportRecords(
    BuildContext context,
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming, {
    required String kind,
  }) =>
      _mergeRecords(context, current, incoming, kind: kind);

  static Future<Map<String, dynamic>> _mergeSingleton(
    BuildContext context,
    String kind,
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) async {
    if (_canonicalJson(current) == _canonicalJson(incoming)) return current;
    final existingTimestamp = _recordTimestamp(current);
    final importedTimestamp = _recordTimestamp(incoming);
    if (existingTimestamp != null &&
        importedTimestamp != null &&
        existingTimestamp != importedTimestamp) {
      return importedTimestamp > existingTimestamp ? incoming : current;
    }
    return await _askImportDuplicate(context, kind, current, incoming)
        ? incoming
        : current;
  }

  static Map<String, dynamic> _mergeHomeState(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final hiddenMatchIds = <int>{
      if (current['hiddenMatchIds'] is List)
        ...(current['hiddenMatchIds'] as List)
            .whereType<num>()
            .map((id) => id.toInt()),
      if (incoming['hiddenMatchIds'] is List)
        ...(incoming['hiddenMatchIds'] as List)
            .whereType<num>()
            .map((id) => id.toInt()),
    };
    return <String, dynamic>{
      ...current,
      ...incoming,
      if (hiddenMatchIds.isNotEmpty)
        'hiddenMatchIds': hiddenMatchIds.toList()..sort(),
    };
  }

  static Map<String, dynamic> _mergeArcadeState(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final highScoresByContent = <String, Map<String, dynamic>>{};
    for (final raw in [current['highscores'], incoming['highscores']]) {
      if (raw is! List) continue;
      for (final entry in raw.whereType<Map>()) {
        final score = Map<String, dynamic>.from(entry);
        highScoresByContent.putIfAbsent(_canonicalJson(score), () => score);
      }
    }
    final highScores = highScoresByContent.values.toList()
      ..sort((first, second) {
        int value(Map<String, dynamic> record, String key) =>
            record[key] is num ? (record[key] as num).toInt() : 0;
        final setsFor = value(second, 'setsFor').compareTo(
          value(first, 'setsFor'),
        );
        if (setsFor != 0) return setsFor;
        final setDifference =
            (value(second, 'setsFor') - value(second, 'setsAgainst')).compareTo(
          value(first, 'setsFor') - value(first, 'setsAgainst'),
        );
        if (setDifference != 0) return setDifference;
        final pointsFor = value(second, 'pointsFor').compareTo(
          value(first, 'pointsFor'),
        );
        if (pointsFor != 0) return pointsFor;
        return (value(second, 'pointsFor') - value(second, 'pointsAgainst'))
            .compareTo(
          value(first, 'pointsFor') - value(first, 'pointsAgainst'),
        );
      });
    final currentName = current['lastPlayerName'];
    final importedName = incoming['lastPlayerName'];
    return <String, dynamic>{
      ...current,
      ...incoming,
      'lastPlayerName': currentName is String && currentName.trim().isNotEmpty
          ? currentName
          : importedName,
      'highscores': highScores.take(7).toList(),
    };
  }

  static Future<void> _mergeApplicationData(
    BuildContext context,
    Database database,
    Map<String, dynamic> data,
  ) async {
    final teamsRepository = TeamsRepository(database);
    final currentTeams =
        (await teamsRepository.load()).map((team) => team.toJson()).toList();
    final teams = await _mergeRecords(
      context,
      currentTeams,
      _backupRecords(<String, dynamic>{'items': data['teams']}, 'items'),
      kind: 'Mannschaft',
    );
    await teamsRepository.save(
      teams.map(Team.fromJson).toList(),
    );

    final incomingMatchStats = data['matchStats'];
    if (incomingMatchStats is Map) {
      final repository = MatchStatsRepository(database);
      final currentMatches = (await repository.load())
          .matches
          .map((match) => match.toJson())
          .toList();
      final matches = await _mergeRecords(
        context,
        currentMatches,
        _backupRecords(incomingMatchStats, 'matches'),
        kind: 'Punktewertung',
      );
      await repository.save(
        MatchStatsState.fromJson(<String, dynamic>{'matches': matches}),
      );
    }

    final incomingPeople = data['people'];
    if (incomingPeople is Map) {
      final currentPeople = await _peopleStore.record('all').get(database);
      final people = await _mergeRecords(
        context,
        _backupRecords(currentPeople, 'people'),
        _backupRecords(incomingPeople, 'people'),
        kind: 'Person',
      );
      await _peopleStore.record('all').put(database, {'people': people});
    }

    final incomingTraining = data['training'];
    if (incomingTraining is Map) {
      final currentTraining =
          await _trainingStore.record('sessions').get(database);
      final sessions = await _mergeRecords(
        context,
        _backupRecords(currentTraining, 'sessions'),
        _backupRecords(incomingTraining, 'sessions'),
        kind: 'Training',
      );
      await _trainingStore
          .record('sessions')
          .put(database, {'sessions': sessions});
    }

    for (final section in [
      (
        key: 'trainingPlans',
        store: _trainingPlansStore,
        record: 'plans',
        list: 'plans',
        label: 'Trainingsplan',
      ),
      (
        key: 'trainingExercises',
        store: _trainingExercisesStore,
        record: 'exercises',
        list: 'exercises',
        label: 'Trainingsübung',
      ),
    ]) {
      final incomingSection = data[section.key];
      if (incomingSection is! Map) continue;
      final currentSection =
          await section.store.record(section.record).get(database);
      final records = await _mergeRecords(
        context,
        _backupRecords(currentSection, section.list),
        _backupRecords(incomingSection, section.list),
        kind: section.label,
      );
      await section.store
          .record(section.record)
          .put(database, {section.list: records});
    }

    final incomingScoreboard = data['scoreboard'];
    if (incomingScoreboard is Map) {
      final currentBoard =
          await _scoreboardStore.record('current').get(database);
      final importedBoard = incomingScoreboard['current'];
      if (importedBoard is Map) {
        final mergedBoard = currentBoard == null
            ? Map<String, dynamic>.from(importedBoard)
            : await _mergeSingleton(
                context,
                'Punktetafel',
                currentBoard,
                Map<String, dynamic>.from(importedBoard),
              );
        await _scoreboardStore.record('current').put(database, mergedBoard);
      }
      final importedSnapshots = incomingScoreboard['snapshots'];
      if (importedSnapshots is Map) {
        final currentSnapshots =
            await _scoreboardStore.record('snapshots').get(database);
        final snapshots = await _mergeRecords(
          context,
          _backupRecords(currentSnapshots, 'items'),
          _backupRecords(importedSnapshots, 'items'),
          kind: 'Punktetafel-Stand',
        );
        await _scoreboardStore
            .record('snapshots')
            .put(database, {'items': snapshots});
      }
    }

    final incomingTactics = data['tactics'];
    if (incomingTactics is Map) {
      final currentTactics = await _tacticsStore.record('board').get(database);
      final importedMap = Map<String, dynamic>.from(incomingTactics);
      if (currentTactics == null) {
        await _tacticsStore.record('board').put(database, importedMap);
      } else {
        final currentMap = Map<String, dynamic>.from(currentTactics);
        final tactics = await _mergeRecords(
          context,
          _backupRecords(currentMap, 'tactics'),
          _backupRecords(importedMap, 'tactics'),
          kind: 'Taktik',
        );
        final currentCanvas = Map<String, dynamic>.from(currentMap)
          ..remove('tactics');
        final importedCanvas = Map<String, dynamic>.from(importedMap)
          ..remove('tactics');
        final canvas = await _mergeSingleton(
          context,
          'Taktiktafel',
          currentCanvas,
          importedCanvas,
        );
        await _tacticsStore.record('board').put(database, {
          ...canvas,
          'tactics': tactics,
        });
      }
    }

    final incomingSettings = data['settings'];
    if (incomingSettings is Map) {
      final currentSettings = await _settingsStore.record('app').get(database);
      final mergedSettings = currentSettings == null
          ? Map<String, dynamic>.from(incomingSettings)
          : await _mergeSingleton(
              context,
              'Einstellungen',
              currentSettings,
              Map<String, dynamic>.from(incomingSettings),
            );
      await _settingsStore.record('app').put(database, mergedSettings);
    }

    final incomingHome = data['home'];
    if (incomingHome is Map) {
      final currentHome = await _homeStore.record('state').get(database);
      final mergedHome = currentHome == null
          ? Map<String, dynamic>.from(incomingHome)
          : _mergeHomeState(
              currentHome,
              Map<String, dynamic>.from(incomingHome),
            );
      await _homeStore.record('state').put(database, mergedHome);
    }

    final incomingArcade = data['arcade'];
    if (incomingArcade is Map) {
      final currentArcade = await _arcadeStore.record('state').get(database);
      final mergedArcade = currentArcade == null
          ? Map<String, dynamic>.from(incomingArcade)
          : _mergeArcadeState(
              currentArcade,
              Map<String, dynamic>.from(incomingArcade),
            );
      await _arcadeStore.record('state').put(database, mergedArcade);
    }
  }

  static Future<bool> _importFullBackupData(
      BuildContext context, Database database, Map<String, dynamic> data,
      {bool skipConfirmation = false}) async {
    final teamsData = data['teams'];
    final matchStatsData = data['matchStats'];
    if (teamsData is! List || matchStatsData is! Map) {
      throw const FormatException(
        'Das Backup enthält nicht alle erwarteten Daten.',
      );
    }

    final shouldImport = skipConfirmation ||
        (await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Daten zusammenführen?'),
                content: const Text(
                  'Importierte Teams, Spiele, Trainings und weitere Daten werden mit dem vorhandenen Bestand zusammengeführt. Neuere importierte Datensätze werden automatisch übernommen; andere Konflikte werden einzeln abgefragt.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Importieren'),
                  ),
                ],
              ),
            ) ??
            false);

    if (!shouldImport) return false;
    await _mergeApplicationData(context, database, data);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import erfolgreich abgeschlossen.')),
      );
    }
    return true;
  }

  static Future<bool> importTeamBackup(
    BuildContext context,
    Database database,
  ) async {
    final data = await _pickJsonMap('Team- oder Komplettbackup importieren');
    if (data == null) return false;

    if (data['teams'] is List && data['matchStats'] is Map) {
      return _importFullBackupData(context, database, data);
    }

    final type = data['type'];
    if (type != 'team' && data['team'] == null) {
      throw const FormatException('Das Team-Backup hat ein ungültiges Format.');
    }
    final teamData = type == 'team' ? data['team'] : data['team'];
    if (teamData is! Map) {
      throw const FormatException('Das Team-Backup hat ein ungültiges Format.');
    }

    return _importFullBackupData(
      context,
      database,
      <String, dynamic>{
        'formatVersion': _formatVersion,
        'teams': <dynamic>[teamData],
        'matchStats': <String, dynamic>{'matches': <dynamic>[]},
      },
    );
  }

  static Future<bool> importMatchBackup(
    BuildContext context,
    Database database,
  ) async {
    final data = await _pickJsonMap('Spiel importieren');
    if (data == null) return false;

    if (data['teams'] is List && data['matchStats'] is Map) {
      return _importFullBackupData(context, database, data);
    }

    if (data['type'] == 'matches' && data['matches'] is List) {
      return _importMatchesBackup(context, database, data['matches'] as List);
    }

    final type = data['type'];
    if (type != 'match' && data['match'] == null) {
      throw const FormatException(
          'Das Spiel-Backup hat ein ungültiges Format.');
    }
    final matchData = type == 'match' ? data['match'] : data['match'];
    if (matchData is! Map) {
      throw const FormatException(
          'Das Spiel-Backup hat ein ungültiges Format.');
    }

    final match = MatchGame.fromJson(Map<String, dynamic>.from(matchData));
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spiel importieren?'),
        content: Text(
          '„${match.opponentTeam.isEmpty ? 'Spiel' : 'vs. ${match.opponentTeam}'}“ wird importiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (shouldImport != true) return false;

    final repository = MatchStatsRepository(database);
    final state = await repository.load();
    final matches = await _mergeRecords(
      context,
      state.matches.map((entry) => entry.toJson()).toList(),
      [match.toJson()],
      kind: 'Punktewertung',
    );
    await repository.save(
      MatchStatsState.fromJson(<String, dynamic>{'matches': matches}),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Spiel importiert: ${match.opponentTeam.isEmpty ? 'Spiel' : match.opponentTeam}')),
      );
    }
    return true;
  }

  static Future<bool> _importMatchesBackup(
    BuildContext context,
    Database database,
    List<dynamic> rawMatches, {
    bool skipConfirmation = false,
  }) async {
    final matches = rawMatches
        .whereType<Map>()
        .map((item) => MatchGame.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (matches.isEmpty) {
      throw const FormatException(
        'Das Mehrspiel-Backup enthält keine gültigen Spiele.',
      );
    }

    final shouldImport = skipConfirmation ||
        (await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Punktewertungen importieren?'),
                content: Text(
                  '${matches.length} Spiele werden mit dem Bestand zusammengeführt. Doppelte Einträge werden abgefragt.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Importieren'),
                  ),
                ],
              ),
            ) ??
            false);
    if (!shouldImport || !context.mounted) return false;

    final repository = MatchStatsRepository(database);
    final existing = await repository.load();
    final merged = await _mergeRecords(
      context,
      existing.matches.map((entry) => entry.toJson()).toList(),
      matches.map((entry) => entry.toJson()).toList(),
      kind: 'Punktewertung',
    );
    await repository.save(
      MatchStatsState.fromJson(<String, dynamic>{'matches': merged}),
    );

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${matches.length} Spiele importiert.')),
    );
    return true;
  }

  static Future<_PdfExportLayout?> _choosePdfLayout(BuildContext context) {
    return showDialog<_PdfExportLayout>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('PDF-Layout'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, _PdfExportLayout.continuous),
            child: const ListTile(
              leading: Icon(Icons.view_day_outlined),
              title: Text('Endlos (Bildschirm)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _PdfExportLayout.a4),
            child: const ListTile(
              leading: Icon(Icons.print_outlined),
              title: Text('DIN A4 hoch (Druck)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _PdfExportLayout.tiledA4),
            child: const ListTile(
              leading: Icon(Icons.grid_on_outlined),
              title: Text('DIN A4 Kachel (zum Kleben)'),
            ),
          ),
        ],
      ),
    );
  }

  static String matchExportFileName(List<MatchGame> matches,
      {required String extension, String? suffix}) {
    if (matches.isEmpty) {
      throw ArgumentError.value(
          matches, 'matches', 'At least one match is required');
    }
    final ordered = _oldestMatchesFirst(matches);
    final first = ordered.first;
    final date = first.matchDateTime.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    String part(String value) {
      final normalized = value
          .toLowerCase()
          .replaceAll('ä', 'ae')
          .replaceAll('ö', 'oe')
          .replaceAll('ü', 'ue')
          .replaceAll('ß', 'ss');
      final safe = _safeFileName(normalized);
      return safe.isEmpty ? 'unbenannt' : safe;
    }

    final opponents = ordered
        .map((match) => part(match.opponentTeam.trim().isEmpty
            ? 'gegner-offen'
            : match.opponentTeam))
        .toSet();
    final stem = [
      '${date.year}-${pad(date.month)}-${pad(date.day)}',
      '${pad(date.hour)}-${pad(date.minute)}',
      part(first.location.trim().isEmpty ? 'ort-offen' : first.location),
      ...opponents,
      if (suffix != null && suffix.isNotEmpty) suffix,
    ].join('_');
    return '$stem.$extension';
  }

  static String _safeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unbenannt';
    return trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .toLowerCase();
  }
}
