import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_app.dart';
import 'package:sport_platform/models/sport_catalog.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

class AlphaGps extends GeolocatorPlatform {
  final positions = StreamController<Position>.broadcast(sync: true);
  bool enabled = true;
  static Position point(int step) => Position(
    latitude: 56 + step * 0.0002,
    longitude: 60,
    timestamp: DateTime(2026, 11, 8, 12).add(Duration(seconds: step * 10)),
    accuracy: 5,
    altitude: 200,
    altitudeAccuracy: 5,
    heading: 0,
    headingAccuracy: 0,
    speed: 2.2,
    speedAccuracy: 0.2,
  );
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => point(0);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positions.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Full recording flow survives minimize, pause and finish at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final originalGps = GeolocatorPlatform.instance;
        final gps = AlphaGps();
        GeolocatorPlatform.instance = gps;
        addTearDown(() async {
          GeolocatorPlatform.instance = originalGps;
          await gps.positions.close();
        });
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const TestPaceApp());
        await tester.pumpAndSettle();
        expect(find.text('Начать тренировку'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('record-workout')));
        await tester.pumpAndSettle();
        expect(find.byType(GlassNavigation), findsNothing);
        await tester.tap(find.text('Лыжи'));
        await tester.pumpAndSettle();
        var prefs = await SharedPreferences.getInstance();
        var data = jsonDecode(
          prefs.getString('pace_local_data')!,
        ) as Map<String, dynamic>;
        expect(data['selectedSport'], 3);
        expect(SportCatalog.names[1], 'Ходьба');
        expect(SportCatalog.names[2], 'Велосипед');
        await tester.tap(find.byKey(const ValueKey('start-workout')));
        await tester.pumpAndSettle();
        for (var i = 1; i <= 3; i++) {
          gps.positions.add(AlphaGps.point(i));
          await tester.pump();
        }
        expect(find.text('0,07'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('close-workout')));
        await tester.pumpAndSettle();
        expect(find.text('Обзор'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('record-workout')));
        await tester.pumpAndSettle();
        expect(find.text('0,07'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('pause-workout')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('На паузе'),
          -100,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('На паузе'), findsOneWidget);
        gps.positions.add(AlphaGps.point(4));
        await tester.pump();
        expect(find.text('0,07'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('pause-workout')));
        await tester.pumpAndSettle();
        expect(find.text('Запись маршрута'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('finish-workout')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Продолжить запись'));
        await tester.pumpAndSettle();
        expect(find.text('Запись маршрута'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('finish-workout')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Завершить'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(find.text('Тренировка сохранена'), findsOneWidget);
        prefs = await SharedPreferences.getInstance();
        data = jsonDecode(
          prefs.getString('pace_local_data')!,
        ) as Map<String, dynamic>;
        expect((data['workouts'] as List).length, 1);
        expect(data['selectedSport'], 3);
        expect(data.keys.toSet(), {'xp', 'selectedSport', 'workouts'});
        final record =
            (data['workouts'] as List).single as Map<String, dynamic>;
        expect(record['sport'], 'Лыжи');
        expect(data['xp'], record['xp'] as int);
        final breakdown = record['xpBreakdown'] as Map;
        expect(breakdown['version'], 1);
        expect(breakdown['total'], record['xp']);
        expect(breakdown['specializationId'], isNull);
        expect(
          (breakdown['distance'] as num).toDouble(),
          closeTo((record['distance'] as num) * 100 / 15, .000001),
        );
        expect(record['elevationGain'], 0);
        expect((record['route'] as List).length, 4);
        await tester.tap(find.text('Готово'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassNavigation), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('record-workout')));
        await tester.pumpAndSettle();
        expect(find.text('GPS подключится после старта'), findsOneWidget);
        expect(find.text('0,00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Other sports preserve old walking selection and return to previous tab',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode({
          'xp': 6840,
          'selectedSport': 1,
          'workouts': [],
        }),
      });
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сообщество'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Соревнования'));
      await tester.pumpAndSettle();
      expect(find.text('Новая цель'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('record-workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Ходьба'));
      await tester.pumpAndSettle();
      expect(find.text('Виды спорта'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Роллеры'),
        100,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Поход'), findsNothing);
      expect(find.text('Скандинавская ходьба'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Роллеры'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Роллеры'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Новая цель'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
