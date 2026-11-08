import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/specialization.dart';
import '../../models/participant_sex.dart';

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

  /// No cooldown in alpha. Keep the date for a future monthly change policy.
  Future<Map<String, dynamic>> selectSpecialization(
    Specialization specialization, {
    ParticipantSex? participantSex,
  }) async {
    final profile = await load();
    final changed = profile['specializationId'] != specialization.name;
    final sexChanged =
        participantSex != null && profile['sex'] != participantSex.name;
    if (!changed && !sexChanged) return profile;
    if (changed) {
      profile['specializationId'] = specialization.name;
      profile['specializationChangedAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }
    if (participantSex != null) profile['sex'] = participantSex.name;
    await save(profile);
    return profile;
  }
}
