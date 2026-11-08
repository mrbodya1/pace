import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class WorkoutNotifications {
  static const _channel = MethodChannel('pace/workout_notifications');
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool?> isGranted() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<bool>('isGranted');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Android 13+ needs consent to show the service notification in the drawer.
  /// Denial does not prevent the user-started foreground location service.
  static Future<void> requestOnce() async {
    if (!_android || await isGranted() != false) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('pace_workout_notifications_prompted') ?? false) return;
    await prefs.setBool('pace_workout_notifications_prompted', true);
    try {
      await _channel.invokeMethod<bool>('requestPermission');
    } on PlatformException {
      /* Recording still works without drawer consent. */
    } on MissingPluginException {
      /* Non-native hosts do not expose this channel. */
    }
  }
}
