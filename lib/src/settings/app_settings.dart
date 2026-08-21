import 'package:flutter/material.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.fontFamily,
    required this.textScaleFactor,
    required this.useLightTheme,
    required this.accentColorValue,
    required this.highlightColorValue,
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
    accentColorValue: 0xFFE57373,
    highlightColorValue: 0xFFFFB74D,
  );

  final String fontFamily;
  final double textScaleFactor;
  final bool useLightTheme;
  final int accentColorValue;
  final int highlightColorValue;

  AppSettings copyWith({
    String? fontFamily,
    double? textScaleFactor,
    bool? useLightTheme,
    int? accentColorValue,
    int? highlightColorValue,
  }) {
    return AppSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      useLightTheme: useLightTheme ?? this.useLightTheme,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
    );
  }
}
