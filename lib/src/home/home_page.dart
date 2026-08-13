import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenScoreboard,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenScoreboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            tooltip: 'Settings',
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
              leading: Icon(Icons.scoreboard, color: scheme.primary),
              title: const Text('Punktetafel'),
              subtitle: const Text('Volleyball-Spielstand erfassen.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenScoreboard,
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.campaign, color: scheme.primary),
              title: const Text('Soundboard'),
              subtitle: const Text('Use assets/sounds for your clips.'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.rotate_right, color: scheme.primary),
              title: const Text('Rotation'),
              subtitle: const Text('Add team and player rotation flows.'),
            ),
          ),
        ],
      ),
    );
  }
}
