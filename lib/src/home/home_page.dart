import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../analytics/match_stats_page.dart';
import '../training/training_page.dart';

enum _TrainingDisplayState { upcoming, active, completed }

class _DisplayedTraining {
  const _DisplayedTraining(this.session, this.state);

  final TrainingSession session;
  final _TrainingDisplayState state;
}

enum _MatchDisplayState { active, upcoming, completed }

class _DisplayedMatch {
  const _DisplayedMatch(this.match, this.state);

  final MatchGame match;
  final _MatchDisplayState state;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.database,
    required this.onOpenSettings,
    required this.onOpenArcade,
    required this.onOpenScoreboard,
    required this.onOpenMatchStats,
    required this.onOpenTeams,
    required this.onOpenTactics,
    required this.onOpenTraining,
    required this.onOpenTrainingSession,
    required this.onOpenMatchSession,
  });

  final Database database;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenArcade;
  final VoidCallback onOpenScoreboard;
  final VoidCallback onOpenMatchStats;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenTactics;
  final Future<void> Function() onOpenTraining;
  final Future<void> Function(TrainingSession session) onOpenTrainingSession;
  final Future<void> Function(MatchGame match) onOpenMatchSession;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TrainingRepository _trainingRepository =
      TrainingRepository(widget.database);
  late final MatchStatsRepository _matchRepository =
      MatchStatsRepository(widget.database);
  static final StoreRef<String, Map<String, dynamic>> _homeStore =
      StoreRef<String, Map<String, dynamic>>('home');
  final List<_DisplayedTraining> _displayedTrainings = <_DisplayedTraining>[];
  final List<_DisplayedMatch> _displayedMatches = <_DisplayedMatch>[];
  final Set<int> _hiddenMatchIds = <int>{};
  Timer? _trainingRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFeaturedContent();
    _trainingRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadFeaturedContent(),
    );
  }

  @override
  void dispose() {
    _trainingRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFeaturedContent() async {
    final results = await Future.wait<Object?>([
      _trainingRepository.load(),
      _matchRepository.load(),
      _homeStore.record('state').get(widget.database),
    ]);
    final sessions = results[0] as List<TrainingSession>;
    final matchState = results[1] as MatchStatsState;
    final homeState = results[2] as Map<String, dynamic>?;
    final storedHiddenIds = homeState?['hiddenMatchIds'];
    final hiddenMatchIds = storedHiddenIds is List
        ? storedHiddenIds.whereType<num>().map((id) => id.toInt()).toSet()
        : <int>{};
    final now = DateTime.now();
    final displayedTrainings = <_DisplayedTraining>[];
    for (final session in sessions) {
      final duration = _durationInMinutes(session.duration);
      if (session.date.isAfter(now)) {
        displayedTrainings.add(
          _DisplayedTraining(session, _TrainingDisplayState.upcoming),
        );
        continue;
      }
      if (duration == null) continue;
      final endsAt = session.date.add(Duration(minutes: duration));
      final displayUntil = endsAt.add(const Duration(minutes: 30));
      if (now.isBefore(endsAt)) {
        displayedTrainings.add(
          _DisplayedTraining(session, _TrainingDisplayState.active),
        );
      } else if (now.isBefore(displayUntil)) {
        displayedTrainings.add(
          _DisplayedTraining(session, _TrainingDisplayState.completed),
        );
      }
    }
    final active = displayedTrainings
        .where((training) => training.state == _TrainingDisplayState.active)
        .toList()
      ..sort(
          (first, second) => first.session.date.compareTo(second.session.date));
    final completed = displayedTrainings
        .where((training) => training.state == _TrainingDisplayState.completed)
        .toList()
      ..sort(
          (first, second) => second.session.date.compareTo(first.session.date));
    final upcoming = displayedTrainings
        .where((training) => training.state == _TrainingDisplayState.upcoming)
        .toList()
      ..sort(
          (first, second) => first.session.date.compareTo(second.session.date));
    final selected = active.isNotEmpty
        ? active
        : completed.isNotEmpty
            ? completed
            : upcoming.isEmpty
                ? <_DisplayedTraining>[]
                : <_DisplayedTraining>[upcoming.first];
    final displayedMatches = matchState.matches
        .where((match) => !hiddenMatchIds.contains(match.id))
        .map((match) => _DisplayedMatch(
              match,
              match.stopwatchRunning
                  ? _MatchDisplayState.active
                  : match.matchDateTime.isAfter(now)
                      ? _MatchDisplayState.upcoming
                      : _MatchDisplayState.completed,
            ))
        .toList()
      ..sort((first, second) {
        final stateComparison = first.state.index.compareTo(second.state.index);
        return stateComparison != 0
            ? stateComparison
            : second.match.matchDateTime.compareTo(first.match.matchDateTime);
      });
    if (!mounted) return;
    setState(() {
      _displayedTrainings
        ..clear()
        ..addAll(selected);
      _displayedMatches
        ..clear()
        ..addAll(displayedMatches);
      _hiddenMatchIds
        ..clear()
        ..addAll(hiddenMatchIds);
    });
  }

  Future<void> _hideMatch(int matchId) async {
    _hiddenMatchIds.add(matchId);
    setState(() {
      _displayedMatches
          .removeWhere((displayed) => displayed.match.id == matchId);
    });
    await _homeStore.record('state').put(widget.database, <String, dynamic>{
      'hiddenMatchIds': _hiddenMatchIds.toList(),
    });
  }

  int? _durationInMinutes(String value) {
    final match = RegExp(
      r'^(\d+)\s*(?:min|m|minutes?|minuten?)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).iconTheme.color;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 95,
        leadingWidth: 100,
        leading: Padding(
          padding:
              const EdgeInsets.only(left: 16, top: 16, right: 4, bottom: 4),
          child: Image.asset(
            'assets/icons/color_transparent_icon.png',
            width: 75,
            height: 75,
          ),
        ),
        title: const Text('VolleyAce'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_displayedTrainings.isNotEmpty) ...[
            for (final displayedTraining in _displayedTrainings)
              Card(
                child: ListTile(
                  leading:
                      Icon(Icons.event_note_outlined, color: highlightColor),
                  title: Text(_trainingTitle(displayedTraining.state)),
                  subtitle: Text(
                    '${displayedTraining.session.name}\n${_formatSession(displayedTraining.session)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpenTrainingSession(
                      displayedTraining.session,
                    );
                    await _loadFeaturedContent();
                  },
                ),
              ),
            const Divider(height: 28),
          ],
          if (_displayedMatches.isNotEmpty) ...[
            for (final displayedMatch in _displayedMatches)
              Card(
                child: ListTile(
                  leading:
                      Icon(Icons.analytics_outlined, color: highlightColor),
                  title: Text(_matchTitle(displayedMatch.state)),
                  subtitle: Text(
                    '${displayedMatch.match.opponentTeam.isEmpty ? 'Punktewertung' : 'vs. ${displayedMatch.match.opponentTeam}'}\n${_formatMatch(displayedMatch.match)}',
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    await widget.onOpenMatchSession(displayedMatch.match);
                    await _loadFeaturedContent();
                  },
                  trailing: IconButton(
                    tooltip: 'Von Startseite entfernen',
                    icon: const Icon(Icons.close),
                    onPressed: () => _hideMatch(displayedMatch.match.id),
                  ),
                ),
              ),
            const Divider(height: 28),
          ],
          Card(
            child: ListTile(
              leading: Icon(Icons.scoreboard, color: highlightColor),
              title: const Text('Punktetafel'),
              subtitle: const Text('Volleyball-Spielstand erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenScoreboard,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.sports_volleyball, color: highlightColor),
              title: const Text('Taktiktafel'),
              subtitle: const Text('Aufstellungen und Laufwege zeichnen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenTactics,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined, color: highlightColor),
              title: const Text('Teams'),
              subtitle: const Text('Teams, Spieler und Trainer verwalten.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenTeams,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.fact_check_outlined, color: highlightColor),
              title: const Text('Training'),
              subtitle: const Text('Training verwalten.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await widget.onOpenTraining();
                await _loadFeaturedContent();
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.analytics_outlined, color: highlightColor),
              title: const Text('Punktewertung'),
              subtitle: const Text('Spieler anlegen und Statistiken erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenMatchStats,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: false,
              leading: const Icon(Icons.sports_esports),
              title: const Text('Volley-Arcade'),
              subtitle: const Text('Work in progress...'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSession(TrainingSession session) {
    final date = session.date;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
    return '$dateText, $timeText';
  }

  String _trainingTitle(_TrainingDisplayState state) => switch (state) {
        _TrainingDisplayState.upcoming => 'Nächstes Training',
        _TrainingDisplayState.active => 'Laufendes Training',
        _TrainingDisplayState.completed => 'Abgeschlossenes Training',
      };

  String _matchTitle(_MatchDisplayState state) => switch (state) {
        _MatchDisplayState.upcoming => 'Nächste Punktewertung',
        _MatchDisplayState.active => 'Laufende Punktewertung',
        _MatchDisplayState.completed => 'Abgeschlossene Punktewertung',
      };

  String _formatMatch(MatchGame match) {
    final date = match.matchDateTime;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
    return '$dateText, $timeText';
  }
}
