import 'package:sembast/sembast.dart';

import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository(Database database) : _database = database;

  static const String _settingsRecordKey = 'app';
  static const String _fontMigrationKey = 'fontFamilyMigratedToNotoSans';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('settings');

  final Database _database;

  Future<AppSettings> load() async {
    final data = await _store.record(_settingsRecordKey).get(_database);
    final storedFont = data?['fontFamily'];
    final storedScale = data?['uiTextScaleFactor'];
    final fontMigrationApplied = data?[_fontMigrationKey] == true;

    final fontFamily = fontMigrationApplied
        ? AppSettings.availableFonts.contains(storedFont)
            ? storedFont as String
            : AppSettings.defaults.fontFamily
        : AppSettings.defaults.fontFamily;

    final scale = storedScale is num
        ? storedScale.toDouble()
        : AppSettings.defaults.textScaleFactor;

    if (!fontMigrationApplied) {
      await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
        'fontFamily': fontFamily,
        'uiTextScaleFactor': _clampScale(scale),
        _fontMigrationKey: true,
      });
    }

    return AppSettings(
      fontFamily: fontFamily,
      textScaleFactor: _clampScale(scale),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _store.record(_settingsRecordKey).put(_database, <String, dynamic>{
      'fontFamily': settings.fontFamily,
      'uiTextScaleFactor': _clampScale(settings.textScaleFactor),
      _fontMigrationKey: true,
    });
  }

  double _clampScale(double value) => value.clamp(0.5, 1.6);
}
