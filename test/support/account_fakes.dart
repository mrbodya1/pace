import 'dart:convert';

import 'package:sport_platform/services/account_service.dart';

class MemorySessionVault implements SessionVault {
  String? value;
  bool failWrite = false, failClear = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (failWrite) throw StateError('Storage unavailable');
    value = data;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Storage unavailable');
    value = null;
  }
}

String accountResponse({String token = 'test-session'}) => jsonEncode({
  'token': token,
  'record': {
    'collectionName': 'pace_users',
    'id': 'test-user',
    'email': 'athlete@example.com',
    'name': 'Атлет',
    'profile': null,
  },
});
