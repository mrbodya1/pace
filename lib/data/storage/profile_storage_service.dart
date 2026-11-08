import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorageService {
  static const _key = 'pace_profile_data';

  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> save(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(profile));
    if (!saved) throw StateError('Profile was not saved');
  }
}
