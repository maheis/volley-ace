import 'package:sembast/sembast.dart';

import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository(Database database) : _database = database;

  static const String _settingsRecordKey = 'app';
  static const String _fontMigrationKey = 'fontFamilyMigratedToUbuntu';
  static const String _themeMigrationKey = 'themePreferenceMigratedToLightMode';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('settings');

  final Database _database;

  Future<AppSettings> load() async {
    final data = await _store.record(_settingsRecordKey).get(_database);
    final storedFont = data?['fontFamily'];
    final storedScale = data?['uiTextScaleFactor'];
    final storedUseLightTheme = data?['useLightTheme'];
    final storedAccentColor = data?['accentColorValue'];
    final fontMigrationApplied = data?[_fontMigrationKey] == true;
    final themeMigrationApplied = data?[_themeMigrationKey] == true;

    final fontFamily = fontMigrationApplied
        ? AppSettings.availableFonts.contains(storedFont)
            ? storedFont as String
            : AppSettings.defaults.fontFamily
        : AppSettings.defaults.fontFamily;

    final scale = storedScale is num
        ? storedScale.toDouble()
        : AppSettings.defaults.textScaleFactor;
    final useLightTheme = themeMigrationApplied
        ? storedUseLightTheme is bool
            ? storedUseLightTheme
            : AppSettings.defaults.useLightTheme
        : AppSettings.defaults.useLightTheme;
    final accentColorValue = storedAccentColor is num
        ? storedAccentColor.toInt()
        : AppSettings.defaults.accentColorValue;

    if (!fontMigrationApplied || !themeMigrationApplied) {
      await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
        'fontFamily': fontFamily,
        'uiTextScaleFactor': _clampScale(scale),
        _fontMigrationKey: true,
        'useLightTheme': useLightTheme,
        'accentColorValue': accentColorValue,
        _themeMigrationKey: true,
      });
    }

    return AppSettings(
      fontFamily: fontFamily,
      textScaleFactor: _clampScale(scale),
      useLightTheme: useLightTheme,
      accentColorValue: accentColorValue,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
      'fontFamily': settings.fontFamily,
      'uiTextScaleFactor': _clampScale(settings.textScaleFactor),
      'useLightTheme': settings.useLightTheme,
      'accentColorValue': settings.accentColorValue,
      _fontMigrationKey: true,
      _themeMigrationKey: true,
    });
  }

  double _clampScale(double value) => value.clamp(0.5, 1.6);
}
