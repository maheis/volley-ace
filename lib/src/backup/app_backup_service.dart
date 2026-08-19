import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';

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

  static String _safeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unbenannt';
    return trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .toLowerCase();
  }

  static Future<bool> importBackup(
      BuildContext context, Database database) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'VolleyAce Export importieren',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result.isEmpty) return false;
    final path = result.single.path;
    if (path == null) return false;

    final rawText = await File(path).readAsString();
    final decoded = jsonDecode(rawText);
    if (decoded is! Map) {
      throw const FormatException('Ungültiges Backup-Format.');
    }
    final data = Map<String, dynamic>.from(decoded);

    final teamsData = data['teams'];
    final matchStatsData = data['matchStats'];
    if (teamsData is! List || matchStatsData is! Map) {
      throw const FormatException(
          'Das Backup enthält nicht alle erwarteten Daten.');
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
}
