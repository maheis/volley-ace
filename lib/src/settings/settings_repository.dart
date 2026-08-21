import 'package:sembast/sembast.dart';

import 'app_settings.dart';
import '../theme/app_palette.dart';

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
    final storedHighlightColor = data?['highlightColorValue'];
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
    final storedHighlightValue = storedHighlightColor is num
        ? storedHighlightColor.toInt()
        : AppPalette.orange.toARGB32();
    final highlightColorValue = AppPalette.accentColors.any(
      (color) => color.toARGB32() == storedHighlightValue,
    )
        ? storedHighlightValue
        : AppPalette.orange.toARGB32();

    if (!fontMigrationApplied || !themeMigrationApplied) {
      await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
        'fontFamily': fontFamily,
        'uiTextScaleFactor': _clampScale(scale),
        _fontMigrationKey: true,
        'useLightTheme': useLightTheme,
        'accentColorValue': accentColorValue,
        'highlightColorValue': highlightColorValue,
        _themeMigrationKey: true,
      });
    }

    return AppSettings(
      fontFamily: fontFamily,
      textScaleFactor: _clampScale(scale),
      useLightTheme: useLightTheme,
      accentColorValue: accentColorValue,
      highlightColorValue: highlightColorValue,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
      'fontFamily': settings.fontFamily,
      'uiTextScaleFactor': _clampScale(settings.textScaleFactor),
      'useLightTheme': settings.useLightTheme,
      'accentColorValue': settings.accentColorValue,
      'highlightColorValue': settings.highlightColorValue,
      _fontMigrationKey: true,
      _themeMigrationKey: true,
    });
  }

  double _clampScale(double value) => value.clamp(0.5, 1.6);
}
