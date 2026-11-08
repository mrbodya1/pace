import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

void main() {
  testWidgets('Profile edits persist separately from legacy workout progress', (
    tester,
  ) async {
    final progress = jsonEncode({
      'xp': 6840,
      'selectedSport': 1,
      'workouts': [],
    });
    SharedPreferences.setMockInitialValues({'pace_local_data': progress});
    await tester.pumpWidget(const PaceApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(GlassNavigation),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать профиль'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Фёдор');
    await tester.enterText(find.byType(TextFormField).at(1), 'Екатеринбург');
    await tester.enterText(find.byType(TextFormField).at(2), 'Бег и лыжи');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Фёдор'), findsOneWidget);
    expect(find.text('Екатеринбург'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Личные параметры'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Личные параметры'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '180');
    await tester.enterText(find.byType(TextFormField).at(1), '75,5');
    await tester.enterText(find.byType(TextFormField).at(2), '31.02.2000');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Проверь дату'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '01.02.2000');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pace_local_data'), progress);
    final profile = jsonDecode(prefs.getString('pace_profile_data')!) as Map;
    expect(profile['name'], 'Фёдор');
    expect(profile['height'], 180);
    expect(profile['weight'], 75.5);
    expect(profile['birthday'], '01.02.2000');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const PaceApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(GlassNavigation),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Фёдор'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress tabs and workout detail use real persisted workouts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pace_local_data': jsonEncode({
        'xp': 7000,
        'selectedSport': 0,
        'workouts': [
          {
            'date': '2026-11-06T12:00:00',
            'distance': 5.2,
            'durationSeconds': 1938,
            'xp': 520,
            'sport': 'Бег',
            'route': [],
          },
        ],
      }),
    });
    await tester.pumpWidget(const PaceApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(GlassNavigation),
        matching: find.text('Прогресс'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тренировки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бег'));
    await tester.pumpAndSettle();
    expect(find.text('5,20 км'), findsOneWidget);
    expect(find.text('СРЕДНИЙ ТЕМП'), findsOneWidget);
    expect(find.text('32:18'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Достижения'));
    await tester.pumpAndSettle();
    expect(find.text('Первый шаг'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
