import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home/home_page.dart';
import 'settings/app_settings.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_page.dart';

class VolleyAceApp extends StatelessWidget {
  const VolleyAceApp({super.key, required this.settingsController});

  final SettingsController settingsController;

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
          theme: _buildTheme(settings.fontFamily),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomePage(
            onOpenSettings: () => _openSettings(context, settings),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(String fontFamily) {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('settings saved')));
    }
  }
}
