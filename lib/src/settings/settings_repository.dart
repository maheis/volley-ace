import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

class SettingsRepository {
  static const String _fontFamilyKey = 'fontFamily';
  static const String _textScaleFactorKey = 'uiTextScaleFactor';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFont = prefs.getString(_fontFamilyKey);
    final storedScale = prefs.getDouble(_textScaleFactorKey);

    final fontFamily = AppSettings.availableFonts.contains(storedFont)
        ? storedFont!
        : AppSettings.defaults.fontFamily;

    final textScaleFactor = _clampScale(
      storedScale ?? AppSettings.defaults.textScaleFactor,
    );

    return AppSettings(
      fontFamily: fontFamily,
      textScaleFactor: textScaleFactor,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, settings.fontFamily);
    await prefs.setDouble(
      _textScaleFactorKey,
      _clampScale(settings.textScaleFactor),
    );
  }

  double _clampScale(double value) => value.clamp(0.5, 1.6);
}
