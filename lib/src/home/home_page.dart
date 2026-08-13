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
        title: const Text('VolleyAce'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Image.asset(
              'assets/icons/color_transparent_icon.png',
              width: 30,
              height: 30,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SimplePresent-inspired starter',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
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
