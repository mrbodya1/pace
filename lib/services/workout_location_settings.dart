import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

abstract final class WorkoutLocationSettings {
  static bool get supportsBackground =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static LocationSettings get current =>
      forPlatform(defaultTargetPlatform, web: kIsWeb);

  static LocationSettings forPlatform(
    TargetPlatform platform, {
    bool web = false,
  }) {
    if (!web && platform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'PACE — запись тренировки',
          notificationText: 'Маршрут записывается. Нажми, чтобы открыть PACE.',
          notificationChannelName: 'Запись тренировки',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!web && platform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }
}
