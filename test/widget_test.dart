import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:volley_ace/src/settings/app_settings.dart';
import 'package:volley_ace/src/settings/settings_page.dart';

void main() {
  testWidgets('Settings page shows typography controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(initial: AppSettings.defaults)),
    );

    expect(find.text('settings'), findsOneWidget);
    expect(find.text('font'), findsOneWidget);
    expect(find.text('save'), findsOneWidget);
  });
}
