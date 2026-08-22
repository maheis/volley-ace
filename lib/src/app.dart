import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sembast/sembast.dart';

import 'home/home_page.dart';
import 'analytics/match_stats_page.dart';
import 'arcade/arcade_page.dart';
import 'scoreboard/scoreboard_page.dart';
import 'settings/app_settings.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_page.dart';
import 'teams/teams_page.dart';
import 'tactics/tactics_page.dart';
import 'training/training_page.dart';
import 'training/training_exercises_page.dart';
import 'training/training_menu_page.dart';
import 'theme/app_palette.dart';

class VolleyAceApp extends StatelessWidget {
  const VolleyAceApp({
    super.key,
    required this.settingsController,
    required this.database,
  });

  final SettingsController settingsController;
  final Database database;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;
        return MaterialApp(
          title: 'Volley Ace',
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en', 'GB'),
            Locale('de', 'DE'),
          ],
          theme: _buildTheme(
            settings.fontFamily,
            accentColor: Color(settings.accentColorValue),
            highlightColor: Color(settings.highlightColorValue),
            brightness: Brightness.light,
          ),
          darkTheme: _buildTheme(
            settings.fontFamily,
            accentColor: Color(settings.accentColorValue),
            highlightColor: Color(settings.highlightColorValue),
            brightness: Brightness.dark,
          ),
          themeMode: settings.useLightTheme ? ThemeMode.light : ThemeMode.dark,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Builder(
            builder: (homeContext) => HomePage(
              onOpenSettings: () => _openSettings(homeContext, settings),
              onOpenArcade: () => _openArcade(homeContext),
              onOpenScoreboard: () => _openScoreboard(homeContext),
              onOpenMatchStats: () => _openMatchStats(homeContext),
              onOpenTeams: () => _openTeams(homeContext),
              onOpenTactics: () => _openTactics(homeContext),
              onOpenTraining: () => _openTrainingMenu(homeContext),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openScoreboard(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScoreboardPage(database: database),
      ),
    );
  }

  Future<void> _openMatchStats(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchStatsPage(database: database),
      ),
    );
  }

  Future<void> _openArcade(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ArcadePage(database: database),
      ),
    );
  }

  Future<void> _openTeams(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TeamsPage(database: database)),
    );
  }

  Future<void> _openTactics(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TacticsPage(database: database)),
    );
  }

  Future<void> _openTrainingMenu(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrainingMenuPage(
          onOpenTraining: () => _openTraining(context),
          onOpenTrainingPlans: () => _openTrainingPlans(context),
          onOpenTrainingExercises: () => _openTrainingExercises(context),
        ),
      ),
    );
  }

  Future<void> _openTraining(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TrainingPage(database: database)),
    );
  }

  Future<void> _openTrainingPlans(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TrainingPlaceholderPage(
          title: 'Trainingspläne',
        ),
      ),
    );
  }

  Future<void> _openTrainingExercises(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrainingExercisesPage(database: database),
      ),
    );
  }

  ThemeData _buildTheme(
    String fontFamily, {
    required Color accentColor,
    required Color highlightColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
      ).copyWith(
        primary: accentColor,
        secondary: AppPalette.orange,
        tertiary: AppPalette.mint,
        surfaceTint: AppPalette.purple,
      ),
      iconTheme: IconThemeData(color: highlightColor),
      appBarTheme: AppBarTheme(
        iconTheme: IconThemeData(color: highlightColor),
        actionsIconTheme: IconThemeData(color: highlightColor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: highlightColor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: highlightColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: highlightColor,
          side: BorderSide(color: highlightColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highlightColor,
          foregroundColor: Colors.black,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: highlightColor,
          foregroundColor: Colors.black,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? highlightColor : null;
        }),
        side: WidgetStateBorderSide.resolveWith(
          (_) => BorderSide(color: highlightColor),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(highlightColor),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? highlightColor : null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? highlightColor.withValues(alpha: 0.5)
              : null;
        }),
      ),
      sliderTheme: SliderThemeData(
        thumbColor: highlightColor,
        activeTrackColor: highlightColor,
        inactiveTrackColor: highlightColor.withValues(alpha: 0.35),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highlightColor,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: highlightColor, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: highlightColor),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: highlightColor,
        selectionColor: highlightColor.withValues(alpha: 0.3),
        selectionHandleColor: highlightColor,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF202124),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: AppPalette.orange,
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, AppSettings current) async {
    final result = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute<AppSettings>(
        builder: (_) => SettingsPage(initial: current),
      ),
    );

    if (result == null) return;
    await settingsController.update(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    }
  }
}
