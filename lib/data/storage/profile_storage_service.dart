import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/specialization.dart';
import '../../services/account_service.dart';
import '../../models/participant_sex.dart';

class ProfileStorageService {
  ProfileStorageService({AccountService? accounts})
    : accounts = accounts ?? AccountService.instance;
  final AccountService accounts;
  String get _owner => "${accounts.baseUrl}|${accounts.account!.id}";
  static const _key = 'pace_profile_data';
  static Future<void>? _pending;

  Future<Map<String, dynamic>> load() async {
    await accounts.initialize();
    await _pending;
    final profile = await _read();
    final account = accounts.account;
    if (account != null &&
        account.supportsProfile &&
        account.profile == null &&
        profile.isNotEmpty) {
      // Import through the same queue as edits so a late import cannot undo a choice.
      return _update((_) {});
    }
    return profile;
  }

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final account = accounts.account;
    if (account != null) {
      if (account.profile != null) {
        return {...account.profile!, 'name': account.name};
      }
      final owner = prefs.getString('pace_profile_legacy_owner');
      if (owner != null && owner != _owner) return {'name': account.name};
      // Claim the pre-account device profile once; never share it with another account.
      await prefs.setString('pace_profile_legacy_owner', _owner);
    }
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final profile = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return profile;
  }

  Future<Map<String, dynamic>> _update(
    void Function(Map<String, dynamic>) change,
  ) {
    final owner = accounts.account?.id;
    final task = (_pending ?? Future<void>.value()).then((_) async {
      if (accounts.account?.id != owner) {
        throw const AccountError('Аккаунт изменился. Повтори сохранение.');
      }
      final profile = await _read();
      if (accounts.account?.id != owner) {
        throw const AccountError('Аккаунт изменился. Повтори сохранение.');
      }
      change(profile);
      await save(profile);
      return profile;
    });
    final completion = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = completion;
    completion.then((_) {
      if (identical(_pending, completion)) _pending = null;
    });
    return task;
  }

  /// Merge into the latest profile instead of saving a stale editor snapshot.
  Future<Map<String, dynamic>> updateFields(
    Map<String, dynamic> fields, {
    Set<String> remove = const {},
  }) => _update((profile) {
    for (final key in remove) {
      profile.remove(key);
    }
    profile.addAll(fields);
  });

  Future<void> save(Map<String, dynamic> profile) async {
    if (accounts.account != null) {
      final value = Map<String, dynamic>.from(profile)..remove('name');
      await accounts.updateProfile(value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(profile));
    if (!saved) throw StateError('Profile was not saved');
  }

  /// No cooldown in alpha. Keep the date for a future monthly change policy.
  Future<Map<String, dynamic>> selectSpecialization(
    Specialization specialization, {
    ParticipantSex? participantSex,
  }) => _update((profile) {
    final changed = profile['specializationId'] != specialization.name;
    final sexChanged =
        participantSex != null && profile['sex'] != participantSex.name;
    if (!changed && !sexChanged) return;
    if (changed) {
      profile['specializationId'] = specialization.name;
      profile['specializationChangedAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }
    if (participantSex != null) profile['sex'] = participantSex.name;
  });
}
