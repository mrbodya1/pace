import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [320.0, 390.0]) {
    testWidgets('Navigation and local progress at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode({
          'xp': 9100,
          'selectedSport': 1,
          'workouts': [],
        }),
      });
      await tester.pumpWidget(const PaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Обзор'), findsOneWidget);
      expect(find.text('9 100 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Профиль'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Ходьба'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ходьба'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Бег'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(
        prefs.getString('pace_local_data')!,
      ) as Map<String, dynamic>;
      expect(saved['selectedSport'], 0);
      expect(saved['xp'], 9100);
      expect(saved['workouts'], isEmpty);

      await tester.ensureVisible(find.text('Войти в аккаунт'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Войти в аккаунт'));
      await tester.pumpAndSettle();
      expect(find.text('Войти через Mail'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Главная'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassWorkoutButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('record-workout')));
      await tester.pumpAndSettle();
      expect(find.text('GPS подключится после старта'), findsOneWidget);
      expect(find.byType(GlassNavigation), findsNothing);
      await tester.tap(find.byKey(const ValueKey('close-workout')));
      await tester.pumpAndSettle();
      expect(find.byType(GlassNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Large text overview has no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const PaceHome(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
