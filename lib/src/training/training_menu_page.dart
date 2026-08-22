import 'package:flutter/material.dart';

class TrainingMenuPage extends StatelessWidget {
  const TrainingMenuPage({
    super.key,
    required this.onOpenTraining,
    required this.onOpenTrainingPlans,
    required this.onOpenTrainingExercises,
  });

  final VoidCallback onOpenTraining;
  final VoidCallback onOpenTrainingPlans;
  final VoidCallback onOpenTrainingExercises;

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).iconTheme.color;

    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _TrainingMenuItem(
            icon: Icons.event_note_outlined,
            title: 'Training',
            subtitle: 'Trainings erfassen, Teilnahme verwalten und teilen.',
            highlightColor: highlightColor,
            onTap: onOpenTraining,
          ),
          const SizedBox(height: 12),
          _TrainingMenuItem(
            icon: Icons.view_list_outlined,
            title: 'Trainingspläne',
            subtitle: 'Trainingsabläufe mit Übungen planen.',
            highlightColor: highlightColor,
            onTap: onOpenTrainingPlans,
          ),
          const SizedBox(height: 12),
          _TrainingMenuItem(
            icon: Icons.fitness_center_outlined,
            title: 'Trainingsübungen',
            subtitle: 'Einzelne Übungen konfigurieren.',
            highlightColor: highlightColor,
            onTap: onOpenTrainingExercises,
          ),
        ],
      ),
    );
  }
}

class _TrainingMenuItem extends StatelessWidget {
  const _TrainingMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlightColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? highlightColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: highlightColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class TrainingPlaceholderPage extends StatelessWidget {
  const TrainingPlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title werden hier künftig verwaltet.'),
      ),
    );
  }
}
