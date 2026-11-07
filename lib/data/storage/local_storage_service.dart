import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout.dart';

class LocalStorageService {
  static const String _storageKey = 'pace_local_data';

  Future<Map<String, dynamic>?> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) return null;

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveProgress({
    required int xp,
    required int selectedSport,
    required List<Workout> workouts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'xp': xp,
      'selectedSport': selectedSport,
      'workouts': workouts.map((workout) => workout.toJson()).toList(),
    };

    await prefs.setString(_storageKey, jsonEncode(data));
  }
}
