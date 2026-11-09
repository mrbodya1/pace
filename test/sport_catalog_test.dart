import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_app.dart';
import 'package:sport_platform/models/sport_catalog.dart';

void main() {
  test('Retired IDs stay reserved and old roller names remain speed-based', () {
    expect(SportCatalog.selectableIndices, [0, 1, 2, 3, 4, 7, 8]);
    expect(SportCatalog.names[7], 'Роллеры');
    expect(SportCatalog.restoreSelection(7), 7);
    expect(SportCatalog.restoreSelection(5), 1);
    expect(SportCatalog.restoreSelection(6), 1);
    expect(SportCatalog.restoreSelection(-1), 0);
    expect(SportCatalog.usesSpeed('Ролики'), isTrue);
    expect(SportCatalog.usesSpeed('Роллеры'), isTrue);
    expect(SportCatalog.displayName('Ролики'), 'Роллеры');
  });

  for (final retired in [5, 6]) {
    testWidgets(
      'Retired default $retired restores walking without changing history',
      (tester) async {
        final history = [
          {
            'date': '2026-11-06T12:00:00.000',
            'distance': 2.0,
            'durationSeconds': 3600,
            'xp': 200,
            'sport': 'Поход',
            'route': [],
          },
        ];
        SharedPreferences.setMockInitialValues({
          'pace_local_data': jsonEncode({
            'xp': 9100,
            'selectedSport': retired,
            'workouts': history,
          }),
        });
        await tester.pumpWidget(const TestPaceApp());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('record-workout')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Ходьба'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Поход'), findsNothing);
        expect(
          find.widgetWithText(ListTile, 'Скандинавская ходьба'),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.widgetWithText(ListTile, 'Роллеры'),
          120,
          scrollable: find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.widgetWithText(ListTile, 'Роллеры'));
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        final data = jsonDecode(prefs.getString('pace_local_data')!) as Map;
        expect(data['selectedSport'], 7);
        expect(data['xp'], 9100);
        expect(data['workouts'], history);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
