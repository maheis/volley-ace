import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;

  AppSettings _settings = AppSettings.defaults;
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _settings = await _repository.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _repository.save(newSettings);
  }
}
