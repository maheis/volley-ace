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

  static Future<Map<String, dynamic>> _readBackup(Database database) async {
    final teamsRepository = TeamsRepository(database);
    final matchStatsRepository = MatchStatsRepository(database);

    final teams = await teamsRepository.load();
    final matchStats = await matchStatsRepository.load();

    return <String, dynamic>{
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'teams': teams.map((team) => team.toJson()).toList(),
      'matchStats': matchStats.toJson(),
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

  static Future<Uint8List> buildMatchStatsPdf(
    MatchGame match, {
    required String title,
    List<MatchGame>? sourceMatches,
  }) async {
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
    final matchTimes = sourceMatches == null
        ? const <DateTime>[]
        : (sourceMatches
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

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
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
        build: (context) => <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            match.opponentTeam.isEmpty ? match.matchType : match.opponentTeam,
            style: const pw.TextStyle(fontSize: 13),
          ),
          if (sourceMatches != null && sourceMatches.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Ausgewählte Partien (${sourceMatches.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _selectedMatchesTable(sourceMatches),
          ],
          pw.Text(
            '$period · ${match.location.isEmpty ? 'Ort offen' : match.location}',
            style: const pw.TextStyle(
              color: pdf.PdfColors.grey700,
              fontSize: 10,
            ),
          ),
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
            'Punkte und Fehler nach Art',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (categories.isEmpty)
            pw.Text('Noch keine Punkte oder Fehler erfasst.')
          else
            pw.SizedBox(
              height: 230,
              child: _categoryChart(categories, points, errors),
            ),
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
                      .where((event) => event.playerId == player.id)
                      .toList(),
                  matchTimes: matchTimes,
                ),
              ),
            ],
          ],
        ],
      ),
    );

    return document.save();
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

  static pw.Widget _categoryChart(
    List<String> categories,
    Map<String, int> points,
    Map<String, int> errors,
  ) {
    final labels = categories.length == 1 ? [...categories, ''] : categories;
    final pointData = <pw.PointChartValue>[
      for (var index = 0; index < labels.length; index++)
        pw.PointChartValue(
          index.toDouble(),
          index < categories.length
              ? (points[categories[index]] ?? 0).toDouble()
              : 0,
        ),
    ];
    final errorData = <pw.PointChartValue>[
      for (var index = 0; index < labels.length; index++)
        pw.PointChartValue(
          index.toDouble(),
          index < categories.length
              ? (errors[categories[index]] ?? 0).toDouble()
              : 0,
        ),
    ];
    final maxValue = <int>[...points.values, ...errors.values]
        .fold<int>(1, math.max)
        .toDouble();

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
              xAxis: pw.FixedAxis.fromStrings(
                labels,
                angle: math.pi / 4,
                textStyle: const pw.TextStyle(fontSize: 7),
              ),
              yAxis: pw.FixedAxis<double>(
                [0, maxValue],
                format: (value) => value.toStringAsFixed(0),
                divisions: true,
                textStyle: const pw.TextStyle(fontSize: 8),
              ),
            ),
            datasets: [
              pw.BarDataSet<pw.PointChartValue>(
                data: pointData,
                color: pdf.PdfColors.green,
                width: 0.3,
                offset: -0.16,
              ),
              pw.BarDataSet<pw.PointChartValue>(
                data: errorData,
                color: pdf.PdfColors.red,
                width: 0.3,
                offset: 0.16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _timelineChart(
    List<MatchEvent> events, {
    List<DateTime> matchTimes = const <DateTime>[],
  }) {
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
        if (scoredEvents[index].category == 'Gegner Fehler') {
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

  static pw.Widget _selectedMatchesTable(List<MatchGame> matches) {
    return pw.Table(
      border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        _tableRow(['Partie', 'Spielart', 'Spielzeit'], header: true),
        for (final sourceMatch in matches)
          _tableRow([
            sourceMatch.opponentTeam.isEmpty
                ? 'Ohne Gegner'
                : 'vs. ${sourceMatch.opponentTeam}',
            sourceMatch.matchType,
            _formatPdfDateTime(sourceMatch.matchDateTime),
          ]),
      ],
    );
  }

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
            '${events.where((event) => event.playerId == player.id && event.kind == 'point').length}',
            '${events.where((event) => event.playerId == player.id && event.kind == 'error').length}',
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

  static Future<void> _exportJson(
    BuildContext context,
    String dialogTitle,
    String suggestedName,
    String jsonText,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonText));

    try {
      final selectedPath = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
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
    String suggestedName,
    String jsonText,
    String subject,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$suggestedName');
    await file.writeAsString(jsonText);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
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
  }) async {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows) {
      await _exportJson(context, dialogTitle, suggestedName, jsonText);
      return;
    }

    await _shareJson(suggestedName, jsonText, subject);
  }

  static Future<void> exportMatchStatsPdf(
    BuildContext context,
    MatchGame match, {
    required String title,
    List<MatchGame>? sourceMatches,
  }) async {
    final bytes = await buildMatchStatsPdf(
      match,
      title: title,
      sourceMatches: sourceMatches,
    );
    if (!context.mounted) return;
    final platform = Theme.of(context).platform;
    final suggestedName =
        'volleyace-statistik-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows) {
      try {
        final selectedPath = await FilePicker.saveFile(
          dialogTitle: 'Statistik als PDF speichern',
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

  static Future<void> exportBackup(
      BuildContext context, Database database) async {
    final payload = await _readBackup(database);
    final jsonText = encodeBackup(payload);
    final suggestedName =
        'volleyace-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    await _exportJson(
      context,
      'VolleyAce Export speichern',
      suggestedName,
      jsonText,
    );
  }

  static Future<void> exportTeam(BuildContext context, Team team) async {
    final jsonText = encodeBackup(buildTeamBackup(team));
    final suggestedName =
        'volleyace-team-${_safeFileName(team.name)}-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    await _exportJson(
      context,
      'Team exportieren',
      suggestedName,
      jsonText,
    );
  }

  static Future<void> shareTeam(BuildContext context, Team team) async {
    final jsonText = encodeBackup(buildTeamBackup(team));
    final suggestedName =
        'volleyace-team-${_safeFileName(team.name)}-${DateTime.now().millisecondsSinceEpoch}.json';
    await shareOrSaveJson(
      context,
      suggestedName: suggestedName,
      jsonText: jsonText,
      subject: 'VolleyAce Team-Backup',
      dialogTitle: 'Team speichern',
    );
  }

  static Future<void> exportMatch(BuildContext context, MatchGame match) async {
    final jsonText = encodeBackup(buildMatchBackup(match));
    final suggestedName =
        'volleyace-match-${_safeFileName(match.opponentTeam.isEmpty ? 'spiel' : match.opponentTeam)}-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    await _exportJson(
      context,
      'Spiel exportieren',
      suggestedName,
      jsonText,
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
    );
  }

  static Future<Map<String, dynamic>?> _pickJsonMap(String dialogTitle) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
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

  static Future<bool> _importFullBackupData(
    BuildContext context,
    Database database,
    Map<String, dynamic> data,
  ) async {
    final teamsData = data['teams'];
    final matchStatsData = data['matchStats'];
    if (teamsData is! List || matchStatsData is! Map) {
      throw const FormatException(
        'Das Backup enthält nicht alle erwarteten Daten.',
      );
    }

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importieren?'),
        content: const Text(
          'Der aktuelle Stand von Teams und Punktewertungen wird durch den Import ersetzt.',
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

    final teams = teamsData
        .whereType<Map>()
        .map((item) => Team.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final matchStats = MatchStatsState.fromJson(
      Map<String, dynamic>.from(matchStatsData),
    );

    await TeamsRepository(database).save(teams);
    await MatchStatsRepository(database).save(matchStats);

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

    final team = Team.fromJson(Map<String, dynamic>.from(teamData));
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Team importieren?'),
        content: Text(
            '„${team.name.isEmpty ? 'Unbenanntes Team' : team.name}“ wird importiert.'),
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

    final repository = TeamsRepository(database);
    final teams = await repository.load();
    final index = teams.indexWhere((entry) => entry.id == team.id);
    if (index >= 0) {
      teams[index] = team;
    } else {
      teams.add(team);
    }
    await repository.save(teams);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Team „${team.name}“ importiert.')),
      );
    }
    return true;
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
    final matches = List<MatchGame>.from(state.matches);
    final index = matches.indexWhere((entry) => entry.id == match.id);
    if (index >= 0) {
      matches[index] = match;
    } else {
      matches.add(match);
    }
    await repository.save(MatchStatsState(matches: matches));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Spiel importiert: ${match.opponentTeam.isEmpty ? 'Spiel' : match.opponentTeam}')),
      );
    }
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
