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

const Color _brandColor = Color(0xffc83737);

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
          title: 'VolleyAce',
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
            brightness: Brightness.light,
          ),
          darkTheme: _buildTheme(
            settings.fontFamily,
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

  ThemeData _buildTheme(
    String fontFamily, {
    required Brightness brightness,
  }) {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandColor,
        brightness: brightness,
      ),
      iconTheme: const IconThemeData(color: _brandColor),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: _brandColor),
        actionsIconTheme: IconThemeData(color: _brandColor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: _brandColor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _brandColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandColor,
          side: const BorderSide(color: _brandColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandColor,
          foregroundColor: Colors.black,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandColor,
          foregroundColor: Colors.black,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF202124),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: _brandColor,
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
