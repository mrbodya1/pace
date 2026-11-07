import 'package:flutter/material.dart';

const lime = Color(0xFFC7F36B);
const bg = Color(0xFF111310);
const panel = Color(0xFF1C1F1A);
const muted = Color(0xFF92978A);

final ThemeData paceTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.dark(
    primary: lime,
    surface: panel,
  ),
  useMaterial3: true,
);
