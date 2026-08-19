import 'package:flutter/material.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.fontFamily,
    required this.textScaleFactor,
    required this.useLightTheme,
  });

  static const List<String> availableFonts = <String>[
    'OpenDyslexic',
    'NotoSans',
    'CourierPrime',
    'Ubuntu',
    'Ubuntu Mono',
  ];

  static const AppSettings defaults = AppSettings(
    fontFamily: 'Ubuntu',
    textScaleFactor: 1.0,
    useLightTheme: false,
  );

  final String fontFamily;
  final double textScaleFactor;
  final bool useLightTheme;

  AppSettings copyWith({
    String? fontFamily,
    double? textScaleFactor,
    bool? useLightTheme,
  }) {
    return AppSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      useLightTheme: useLightTheme ?? this.useLightTheme,
    );
  }
}
