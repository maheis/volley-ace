import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenArcade,
    required this.onOpenScoreboard,
    required this.onOpenMatchStats,
    required this.onOpenTeams,
    required this.onOpenTactics,
    required this.onOpenTraining,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenArcade;
  final VoidCallback onOpenScoreboard;
  final VoidCallback onOpenMatchStats;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenTactics;
  final VoidCallback onOpenTraining;

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
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.scoreboard, color: highlightColor),
              title: const Text('Punktetafel'),
              subtitle: const Text('Volleyball-Spielstand erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenScoreboard,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.sports_volleyball, color: highlightColor),
              title: const Text('Taktiktafel'),
              subtitle: const Text('Aufstellungen und Laufwege zeichnen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenTactics,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined, color: highlightColor),
              title: const Text('Teams'),
              subtitle: const Text('Teams, Spieler und Trainer verwalten.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenTeams,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.fact_check_outlined, color: highlightColor),
              title: const Text('Training'),
              subtitle:
                  const Text('Teilnahme von Trainern und Spielern erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenTraining,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.analytics_outlined, color: highlightColor),
              title: const Text('Punktewertung'),
              subtitle: const Text('Spieler anlegen und Statistiken erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenMatchStats,
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
}
