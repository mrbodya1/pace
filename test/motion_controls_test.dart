import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/widgets/glass_segmented_control.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Navigation lens slides while central record button stays fixed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PaceApp());
      await tester.pumpAndSettle();
      final before = tester.getRect(
        find.byKey(const ValueKey('navigation-lens')),
      );
      final record = tester.getRect(
        find.byKey(const ValueKey('record-workout')),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Профиль'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final middle = tester.getRect(
        find.byKey(const ValueKey('navigation-lens')),
      );
      await tester.pumpAndSettle();
      final after = tester.getRect(
        find.byKey(const ValueKey('navigation-lens')),
      );
      expect(middle.left, greaterThan(before.left));
      expect(middle.left, lessThan(after.left));
      expect(
        tester.getRect(find.byKey(const ValueKey('record-workout'))),
        record,
      );
      await tester.tap(find.byKey(const ValueKey('record-workout')));
      await tester.pumpAndSettle();
      expect(find.text('Тренировка'), findsOneWidget);
      expect(find.byType(GlassNavigation), findsNothing);
      await tester.tap(find.byKey(const ValueKey('close-workout')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('navigation-lens'))),
        after,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sport lens moves and persists the original sport indices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-workout')));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('sport-lens')));
    await tester.tap(find.text('Лыжи'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final middle = tester.getRect(find.byKey(const ValueKey('sport-lens')));
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const ValueKey('sport-lens')));
    expect(middle.left, greaterThan(before.left));
    expect(middle.left, lessThan(after.left));
    final prefs = await SharedPreferences.getInstance();
    expect(
      (jsonDecode(prefs.getString('pace_local_data')!) as Map)['selectedSport'],
      3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Other sport has no false quick selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pace_local_data': jsonEncode({
        'xp': 6840,
        'selectedSport': 1,
        'workouts': [],
      }),
    });
    await tester.pumpWidget(const PaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-workout')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Ходьба'), findsOneWidget);
    final selector = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );
    expect(selector.selectedIndex, isNull);
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(GlassSegmentedControl),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion and large labels still allow sport selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassSegmentedControl(
                      labels: const ['Бег', 'Велосипед', 'Лыжи'],
                      selectedIndex: selected,
                      onChanged: (index) => setState(() => selected = index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Лыжи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Лыжи'));
    await tester.pump();
    expect(selected, 2);
    final snapped = tester.getRect(find.byKey(const ValueKey('sport-lens')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(find.byKey(const ValueKey('sport-lens'))), snapped);
    expect(tester.takeException(), isNull);
  });
}
