import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_repository.dart';
import 'src/storage/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await openAppDatabase();
  final settingsController = SettingsController(SettingsRepository(database));
  await settingsController.load();

  runApp(VolleyAceApp(settingsController: settingsController));
}
