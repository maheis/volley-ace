import 'package:flutter/material.dart';

class ArcadePage extends StatelessWidget {
  const ArcadePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volley-Arcade'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Neuschreibung in Dart',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Das alte SDL2-Spiel aus .notes/volley-arcade wird hier als neues Flutter-Modul neu aufgebaut.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.extension, color: scheme.primary),
              title: const Text('Übernommen werden soll'),
              subtitle: const Text(
                'Menü, Spielmodus, Highscore, Sound, Schwierigkeit und die Volleyball-Spielregeln.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.checklist, color: scheme.secondary),
              title: const Text('Nächster sinnvoller Schritt'),
              subtitle: const Text(
                'Erst Spielzustand und Physik in Dart modellieren, dann UI und Gegnerlogik ergänzen.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
