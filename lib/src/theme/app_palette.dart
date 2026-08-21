import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const green = Color(0xFFAED581);
  static const yellow = Color(0xFFFFF176);
  static const blue = Color(0xFF64B5F6);
  static const red = Color(0xFFE57373);
  static const mint = Color(0xFF8fdcbe);
  static const purple = Color(0xFF9575CD);
  static const orange = Color(0xFFFFB74D);

  static const accentColors = <Color>[
    red,
    orange,
    green,
    yellow,
    blue,
    mint,
    purple,
  ];

  static const accentNames = <String>[
    'Rot',
    'Orange',
    'Grün',
    'Gelb',
    'Blau',
    'Mint',
    'Lila',
  ];

  static const defaultAccent = red;
}
