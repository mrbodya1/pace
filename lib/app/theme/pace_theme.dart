import 'package:flutter/material.dart';

const lime = Color(0xFFC7F36B);
const bg = Color(0xFF080B10);
const panel = Color(0xFF191C29);
const muted = Color(0xFFA6A9BB);

final ThemeData paceTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.dark(
    primary: lime,
    onPrimary: bg,
    surface: panel,
    onSurface: Color(0xFFF5F6FA),
    outline: Color(0xFF50556B),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15, height: 1.4),
    bodyLarge: TextStyle(fontSize: 17, height: 1.4),
    titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF33374A), space: 32),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      textStyle: ThemeData.dark().textTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 54),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF5B6078)),
      shape: const StadiumBorder(),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    textColor: Colors.white,
  ),
  useMaterial3: true,
);
