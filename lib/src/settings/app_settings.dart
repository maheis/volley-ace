import 'package:flutter/material.dart';

@immutable
class AppSettings {
  const AppSettings({required this.fontFamily, required this.textScaleFactor});

  static const List<String> availableFonts = <String>[
    'OpenDyslexic',
    'NotoSans',
    'CourierPrime',
  ];

  static const AppSettings defaults = AppSettings(
    fontFamily: 'OpenDyslexic',
    textScaleFactor: 1.0,
  );

  final String fontFamily;
  final double textScaleFactor;

  AppSettings copyWith({String? fontFamily, double? textScaleFactor}) {
    return AppSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }
}
