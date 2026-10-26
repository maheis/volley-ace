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

    return <String, dynamic>{
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
    };
  }

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
    final pageFormat = _pageFormat(landscape);

    final reportWidgets = <pw.Widget>[
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        match.opponentTeam.isEmpty ? match.matchType : match.opponentTeam,
        style: const pw.TextStyle(fontSize: 13),
      ),
      if (orderedSourceMatches != null && orderedSourceMatches.isNotEmpty) ...[
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
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          for (final sourceMatch in orderedSourceMatches)
            ..._individualMatchReportWidgets(
              sourceMatch,
              includeMatchDetails: true,
            ),
        ] else ...[
          pw.SizedBox(height: 18),
          pw.Text(
            'Spielbericht',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
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
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ..._matchHistoryWidgets(match, sortedEvents),
        ],
      ],
      pw.SizedBox(height: 18),
      pw.Row(
        children: [
          pw.Expanded(
            child: _summaryCard('Punkte', '$pointCount', pdf.PdfColors.green),
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
        'Punkte und Fehler nach Art',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      if (categories.isEmpty)
        pw.Text('Noch keine Punkte oder Fehler erfasst.')
      else
        pw.SizedBox(
          height: _categoryChartHeight(categories.length),
          child: _categoryChart(categories, points, errors),
        ),
      if (categories.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        _categorySummaryTable(categories, points, errors),
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
            '${player.name} · ${player.number}',
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
              trendSamples: orderedSourceMatches != null &&
                      orderedSourceMatches.length > 1
                  ? matchPlayerTrendSamples(
                      match,
                      orderedSourceMatches,
                      player.id,
                    )
                  : null,
            ),
          ),
        ],
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
          ..._individualMatchReportWidgets(sourceMatch),
      ],
    ];

    if (continuous) {
      final reportCount = orderedSourceMatches?.length ?? 1;
      final reportPlayerCount = orderedSourceMatches == null
          ? match.players.length
          : orderedSourceMatches.fold<int>(
              match.players.length,
              (total, sourceMatch) => total + sourceMatch.players.length,
            );
      final detailedMatches = orderedSourceMatches ?? <MatchGame>[match];
      final eventCount = detailedMatches.fold<int>(
        0,
        (total, sourceMatch) => total + sourceMatch.events.length,
      );
      final reportLength = detailedMatches.fold<int>(
        0,
        (total, sourceMatch) => total + sourceMatch.matchReport.length,
      );
      final eventHistoryHeight = includeFullMatchDetails
          ? eventCount * 42 + (eventCount / 18).ceil() * 20
          : 0;
      final matchReportHeight =
          includeFullMatchDetails ? (reportLength / 80).ceil() * 14 : 0;
      final pageHeight = math
          .max(
            pageFormat.height,
            1800 +
                reportCount * 1000 +
                reportPlayerCount * 180 +
                eventHistoryHeight +
                matchReportHeight,
          )
          .toDouble();
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(pageFormat.width, pageHeight),
          margin: const pw.EdgeInsets.all(32),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: reportWidgets,
          ),
        ),
      );
    } else {
      document.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              'VolleyAce · Punktewertung',
              style: const pw.TextStyle(
                color: pdf.PdfColors.grey700,
                fontSize: 9,
              ),
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(
                color: pdf.PdfColors.grey700,
                fontSize: 9,
              ),
            ),
          ),
          build: (_) => reportWidgets,
        ),
      );
    }

    return document.save();
  }

  static Future<Uint8List> buildMatchHistoryPdf(MatchGame match) async {
    final events = List<MatchEvent>.from(match.events)
      ..sort((first, second) {
        final timeOrder = first.occurredAt.compareTo(second.occurredAt);
        return timeOrder != 0 ? timeOrder : first.id.compareTo(second.id);
      });
    final historyRows = _matchHistoryRows(match, events);
    final historyWidgets = _matchHistoryWidgetsFromRows(historyRows);
    final landscapeFormat = _pageFormat(true);
    final pageHeight = math
        .max(
          landscapeFormat.height,
          240 + historyRows.length * 42 + (historyRows.length / 18).ceil() * 20,
        )
        .toDouble();
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat(landscapeFormat.width, pageHeight),
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Text(
              'Spielverlauf · ${match.opponentTeam.isEmpty ? match.matchType : match.opponentTeam}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${_formatPdfDateTime(match.matchDateTime).replaceAll('–', '-')} · ${match.location.isEmpty ? 'Ort offen' : match.location} · ${match.matchType}',
              style: const pw.TextStyle(
                color: pdf.PdfColors.grey700,
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 18),
            ...historyWidgets,
          ],
        ),
      ),
    );
    return document.save();
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

  static List<pw.Widget> _individualMatchReportWidgets(
    MatchGame match, {
    bool includeMatchDetails = false,
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
        'Punkte und Fehler nach Art',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      if (categories.isEmpty)
        pw.Text('Noch keine Punkte oder Fehler erfasst.')
      else
        pw.SizedBox(
          height: _categoryChartHeight(categories.length),
          child: _categoryChart(categories, points, errors),
        ),
      if (categories.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _categorySummaryTable(categories, points, errors),
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
            '${player.name} · ${player.number}',
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
      ],
    ];
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

  static pw.Widget _categorySummaryTable(
    List<String> categories,
    Map<String, int> points,
    Map<String, int> errors,
  ) {
    final totalPoints = points.values.fold<int>(0, (sum, value) => sum + value);
    final totalErrors = errors.values.fold<int>(0, (sum, value) => sum + value);
    return pw.Table(
      border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        _tableRow(['Art', 'Punkte', 'Fehler'], header: true),
        for (final category in categories)
          _tableRow([
            category,
            '${points[category] ?? 0}',
            '${errors[category] ?? 0}',
          ]),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey100),
          children: [
            for (final value in ['Gesamt', '$totalPoints', '$totalErrors'])
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  value,
                  textAlign: value == 'Gesamt'
                      ? pw.TextAlign.left
                      : pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _categoryChart(
    List<String> categories,
    Map<String, int> points,
    Map<String, int> errors,
  ) {
    final labels = <String>['', ...categories];
    final pointData = <pw.PointChartValue>[
      for (var index = 0; index < labels.length; index++)
        pw.PointChartValue(
          index > 0 ? (points[categories[index - 1]] ?? 0).toDouble() : 0,
          index.toDouble(),
        ),
    ];
    final errorData = <pw.PointChartValue>[
      for (var index = 0; index < labels.length; index++)
        pw.PointChartValue(
          index > 0 ? (errors[categories[index - 1]] ?? 0).toDouble() : 0,
          index.toDouble(),
        ),
    ];
    final maxValue = <int>[...points.values, ...errors.values]
        .fold<int>(1, math.max)
        .toDouble();
    final evenBandData = <pw.PointChartValue>[
      for (var index = 0; index < categories.length; index += 2)
        pw.PointChartValue(maxValue, (index + 1).toDouble()),
    ];
    final oddBandData = <pw.PointChartValue>[
      for (var index = 1; index < categories.length; index += 2)
        pw.PointChartValue(maxValue, (index + 1).toDouble()),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _chartLegend(pdf.PdfColors.green, 'Punkte'),
            pw.SizedBox(width: 16),
            _chartLegend(pdf.PdfColors.red, 'Fehler'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis<double>(
                [0, maxValue],
                format: (value) => value.toStringAsFixed(0),
                divisions: true,
                textStyle: const pw.TextStyle(fontSize: 8),
              ),
              yAxis: pw.FixedAxis.fromStrings(
                labels,
                textStyle: const pw.TextStyle(fontSize: 8),
              ),
            ),
            datasets: [
              pw.BarDataSet<pw.PointChartValue>(
                data: evenBandData,
                color: pdf.PdfColor(1, 0.93, 0.72),
                axis: pw.Axis.vertical,
                width: 19,
              ),
              pw.BarDataSet<pw.PointChartValue>(
                data: oddBandData,
                color: pdf.PdfColor(1, 0.98, 0.88),
                axis: pw.Axis.vertical,
                width: 19,
              ),
              pw.BarDataSet<pw.PointChartValue>(
                data: pointData,
                color: pdf.PdfColors.green,
                axis: pw.Axis.vertical,
                width: 10,
                offset: -6,
              ),
              pw.BarDataSet<pw.PointChartValue>(
                data: errorData,
                color: pdf.PdfColors.red,
                axis: pw.Axis.vertical,
                width: 10,
                offset: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static double _categoryChartHeight(int categoryCount) =>
      math.max(230, (categoryCount + 1) * 25 + 40).toDouble();

  static pw.Widget _timelineChart(
    List<MatchEvent> events, {
    List<DateTime> matchTimes = const <DateTime>[],
    List<MatchTrendSample>? trendSamples,
  }) {
    if (trendSamples != null) {
      return _playerTimelineChartFromSamples(trendSamples);
    }
    final scoredEvents = events
        .where((event) => event.kind == 'point' || event.kind == 'error')
        .toList();
    if (scoredEvents.isEmpty) return pw.Text('Keine Punktdaten.');

    var points = 0;
    var errors = 0;
    var opponentErrors = 0;
    final pointData = <pw.PointChartValue>[
      const pw.PointChartValue(0, 0),
    ];
    final errorData = <pw.PointChartValue>[
      const pw.PointChartValue(0, 0),
    ];
    final opponentErrorData = <pw.PointChartValue>[
      const pw.PointChartValue(0, 0),
    ];
    for (var index = 0; index < scoredEvents.length; index++) {
      if (scoredEvents[index].kind == 'point') {
        points++;
        if (scoredEvents[index].category == 'Gegnerfehler') {
          opponentErrors++;
        }
      } else {
        errors++;
      }
      pointData
          .add(pw.PointChartValue((index + 1).toDouble(), points.toDouble()));
      errorData
          .add(pw.PointChartValue((index + 1).toDouble(), errors.toDouble()));
      opponentErrorData.add(
        pw.PointChartValue((index + 1).toDouble(), opponentErrors.toDouble()),
      );
    }

    final end = scoredEvents.length.toDouble();
    final middle = end / 2;
    final dateLabels = [0.0, middle, end].map((position) {
      final eventIndex =
          (position - 1).round().clamp(0, scoredEvents.length - 1);
      return _formatPdfDateTime(scoredEvents[eventIndex].occurredAt);
    }).toList();
    final maxValue =
        math.max(points, math.max(errors, opponentErrors)).toDouble();
    final matchStarts = matchTimes
        .map((time) => scoredEvents.indexWhere(
              (event) => !event.occurredAt.isBefore(time),
            ))
        .where((index) => index >= 0)
        .toSet()
        .toList()
      ..sort();
    if (matchStarts.isEmpty || matchStarts.first > 0) matchStarts.insert(0, 0);
    final segmentWidths = <int>[];
    for (var index = 0; index < matchStarts.length; index++) {
      final next = index + 1 < matchStarts.length
          ? matchStarts[index + 1]
          : scoredEvents.length;
      if (next > matchStarts[index]) {
        segmentWidths.add(next - matchStarts[index]);
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _chartLegend(pdf.PdfColors.green, 'Punkte'),
            pw.SizedBox(width: 16),
            _chartLegend(pdf.PdfColors.red, 'Fehler'),
            pw.SizedBox(width: 16),
            _chartLegend(pdf.PdfColors.blue, 'Gegnerfehler'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              if (segmentWidths.length > 1)
                pw.Positioned.fill(
                  child: pw.Row(
                    children: [
                      for (var index = 0; index < segmentWidths.length; index++)
                        pw.Expanded(
                          flex: segmentWidths[index],
                          child: pw.Container(
                            color: index.isEven
                                ? pdf.PdfColor(0.93, 0.97, 1)
                                : pdf.PdfColor(1, 0.96, 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
              pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis<double>(
                    [0, middle, end],
                    format: (value) {
                      if (value <= 0) return dateLabels.first;
                      if (value >= end) return dateLabels.last;
                      return dateLabels[1];
                    },
                    textStyle: const pw.TextStyle(fontSize: 7),
                  ),
                  yAxis: pw.FixedAxis<double>(
                    [0, math.max(1, maxValue)],
                    format: (value) => value.toStringAsFixed(0),
                    divisions: true,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                datasets: [
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
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _playerTimelineChartFromSamples(
    List<MatchTrendSample> samples,
  ) {
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
    final middle = end / 2;
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
    final matchStarts = samples
        .asMap()
        .entries
        .where((entry) => entry.value.beginsMatch)
        .map((entry) => entry.key)
        .toList();
    if (matchStarts.isEmpty || matchStarts.first != 0) {
      matchStarts.insert(0, 0);
    }
    final segmentWidths = <int>[];
    for (var index = 0; index < matchStarts.length; index++) {
      final next = index + 1 < matchStarts.length
          ? matchStarts[index + 1]
          : samples.length - 1;
      final width = next - matchStarts[index];
      if (width > 0) segmentWidths.add(width);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _chartLegend(pdf.PdfColors.green, 'Punkte'),
            pw.SizedBox(width: 16),
            _chartLegend(pdf.PdfColors.red, 'Fehler'),
            pw.SizedBox(width: 16),
            _chartLegend(pdf.PdfColors.blue, 'Gegnerfehler'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              if (segmentWidths.length > 1)
                pw.Positioned.fill(
                  child: pw.Row(
                    children: [
                      for (var index = 0; index < segmentWidths.length; index++)
                        pw.Expanded(
                          flex: segmentWidths[index],
                          child: pw.Container(
                            color: index.isEven
                                ? pdf.PdfColor(0.93, 0.97, 1)
                                : pdf.PdfColor(1, 0.96, 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
              pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis<double>(
                    [0, middle, end],
                    format: (value) {
                      if (value <= 0) return dateLabels.first;
                      if (value >= end) return dateLabels.last;
                      return dateLabels[1];
                    },
                    textStyle: const pw.TextStyle(fontSize: 7),
                  ),
                  yAxis: pw.FixedAxis<double>(
                    [0, math.max(1, maxValue)],
                    format: (value) => value.toStringAsFixed(0),
                    divisions: true,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                datasets: [
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

  static pw.TableRow _tableRow(List<String> values, {bool header = false}) {
    return pw.TableRow(
      decoration:
          header ? const pw.BoxDecoration(color: pdf.PdfColors.grey200) : null,
      children: [
        for (var index = 0; index < values.length; index++)
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
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
    bool continuous = true,
    bool includeFullMatchDetails = false,
  }) async {
    final bytes = await buildMatchStatsPdf(
      match,
      title: title,
      sourceMatches: sourceMatches,
      landscape: landscape,
      continuous: continuous,
      includeFullMatchDetails: includeFullMatchDetails,
    );
    if (!context.mounted) return;
    final platform = Theme.of(context).platform;
    final suggestedName =
        'volleyace-pdf-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().millisecondsSinceEpoch}.pdf';

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
    final bytes = await buildMatchHistoryPdf(match);
    if (!context.mounted) return;
    final platform = Theme.of(context).platform;
    final suggestedName =
        'volleyace-pdf-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().millisecondsSinceEpoch}.pdf';

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
    final payload = await _readBackup(database);
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
    final payload = await _readBackup(database);
    final jsonText = encodeBackup(payload);
    final suggestedName =
        'volleyace-gesamt-${DateTime.now().millisecondsSinceEpoch}.json';
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: 'VolleyAce Teams und Daten',
      dialogTitle: 'Alle Teams und Daten teilen',
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
    final suggestedName =
        'volleyace-match-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().toIso8601String().replaceAll(':', '-')}.vace';
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
    final suggestedName =
        'volleyace-punktewertung-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().millisecondsSinceEpoch}.json';
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
    final suggestedName =
        'volleyace-punktewertungen-${matches.length}-${DateTime.now().millisecondsSinceEpoch}.json';
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
    final data = await _pickJsonMap('Team importieren');
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
