import 'dart:io';
import 'dart:typed_data';

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
  Uint8List? initialVaceContent;
  for (final argument in Platform.executableArguments) {
    if (!argument.toLowerCase().endsWith('.vace')) continue;
    final file = File(argument);
    if (await file.exists()) {
      initialVaceContent = await file.readAsBytes();
      break;
    }
  }

  runApp(
    VolleyAceApp(
      settingsController: settingsController,
      database: database,
      initialVaceContent: initialVaceContent,
    ),
  );
}
