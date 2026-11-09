import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_app.dart';
import 'package:sport_platform/services/workout_location_settings.dart';
import 'package:sport_platform/services/workout_notifications.dart';

import 'recording_flow_test.dart' show AlphaGps;

class BackgroundGps extends AlphaGps {
  final sessions = <StreamController<Position>>[];
  final settings = <LocationSettings?>[];
  Completer<void>? cancelGate;
  Completer<Position>? firstFix;
  int cancelled = 0;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => firstFix == null ? AlphaGps.point(0) : await firstFix!.future;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings.add(locationSettings);
    final controller = StreamController<Position>(
      sync: true,
      onCancel: () async {
        final gate = cancelGate;
        if (gate != null) await gate.future;
        cancelled++;
      },
    );
    sessions.add(controller);
    return controller.stream;
  }
}

Future<void> openRecording(WidgetTester tester, BackgroundGps gps) async {
  SharedPreferences.setMockInitialValues({});
  GeolocatorPlatform.instance = gps;
  await tester.pumpWidget(const TestPaceApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('record-workout')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('start-workout')));
}

void main() {
  late GeolocatorPlatform original;
  late BackgroundGps gps;
  setUp(() {
    original = GeolocatorPlatform.instance;
    gps = BackgroundGps();
  });
  tearDown(() async {
    GeolocatorPlatform.instance = original;
    if (gps.cancelGate != null && !gps.cancelGate!.isCompleted) {
      gps.cancelGate!.complete();
    }
    await gps.positions.close();
    // Cancelled single-subscription controllers can safely be closed here.
    for (final session in gps.sessions) {
      unawaited(session.close());
    }
  });

  test(
    'Mobile streams request the native background modes and CPU wake lock',
    () {
      final android = WorkoutLocationSettings.forPlatform(
        TargetPlatform.android,
      ) as AndroidSettings;
      expect(android.foregroundNotificationConfig!.enableWakeLock, isTrue);
      expect(android.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(android.foregroundNotificationConfig!.enableWifiLock, isFalse);
      final ios = WorkoutLocationSettings.forPlatform(
        TargetPlatform.iOS,
      ) as AppleSettings;
      expect(ios.allowBackgroundLocationUpdates, isTrue);
      expect(ios.showBackgroundLocationIndicator, isTrue);
      expect(ios.pauseLocationUpdatesAutomatically, isFalse);
      expect(ios.activityType, ActivityType.fitness);
      expect(
        WorkoutLocationSettings.forPlatform(TargetPlatform.android, web: true),
        isNot(isA<AndroidSettings>()),
      );
    },
  );

  testWidgets(
    'Notification refusal is requested once and does not block recording',
    (tester) async {
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pace/workout_notifications'),
            (call) async {
              if (call.method == 'requestPermission') requests++;
              return false;
            },
          );
      await openRecording(tester, gps);
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 1);
      expect(requests, 1);
      await WorkoutNotifications.requestOnce();
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Background location points remain in the same session and save XP once',
    (tester) async {
      await openRecording(tester, gps);
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      for (var step = 1; step <= 4; step++) {
        gps.sessions.single.add(AlphaGps.point(step));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 1);
      expect(gps.cancelled, 0);
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
      expect(gps.cancelled, 1);
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString('pace_local_data')!) as Map;
      final workout = (data['workouts'] as List).single as Map;
      expect((workout['route'] as List).length, 5);
      expect(workout['distance'], closeTo(.08896, .001));
      expect(data['xp'], workout['xp'] as int);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Resume waits for old native cancellation before creating a new stream',
    (tester) async {
      await openRecording(tester, gps);
      await tester.pumpAndSettle();
      gps.cancelGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pump();
      expect(gps.sessions.length, 1);
      gps.cancelGate!.complete();
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 2);
      expect(gps.cancelled, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'GPS error pauses recording and requires explicit foreground resume',
    (tester) async {
      await openRecording(tester, gps);
      await tester.pumpAndSettle();
      gps.sessions.single.addError(StateError('Location permission lost'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Продолжить'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      expect(gps.sessions.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Leaving app before first fix does not launch a new service in background',
    (tester) async {
      gps.firstFix = Completer<Position>();
      await openRecording(tester, gps);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gps.firstFix!.complete(AlphaGps.point(0));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gps.sessions, isEmpty);
      expect(find.byKey(const ValueKey('start-workout')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
