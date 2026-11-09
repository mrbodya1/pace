import 'package:flutter/material.dart';
import 'package:sport_platform/main.dart';
export 'package:sport_platform/main.dart' show PaceHome;
import 'package:sport_platform/app/theme/pace_theme.dart';

class TestPaceApp extends StatelessWidget {
  const TestPaceApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(theme: paceTheme, home: const PaceHome());
}
