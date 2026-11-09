import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AccountError implements Exception {
  const AccountError(this.message, {this.accountCreated = false});
  final String message;
  final bool accountCreated;
  @override
  String toString() => message;
}

class PaceAccount {
  const PaceAccount({
    required this.id,
    required this.email,
    required this.name,
    this.profile,
    this.supportsProfile = false,
  });
  final String id;
  final String email;
  final String name;
  final Map<String, dynamic>? profile;
  final bool supportsProfile;
}

abstract interface class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  static const _key = 'pace_account_session_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Account state is independent of the local workout and profile stores.
class AccountService extends ChangeNotifier {
  AccountService({http.Client? client, SessionVault? vault, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _vault = vault ?? SecureSessionVault(),
      baseUrl = baseUrl ?? defaultBaseUrl();

  static final instance = AccountService();
  final http.Client _client;
  final SessionVault _vault;
  final Uri baseUrl;
  PaceAccount? account;
  String? _token;
  bool initialized = false;
  Future<void>? _initializing;

  static Uri defaultBaseUrl() {
    const configured = String.fromEnvironment('PACE_API_URL');
    if (configured.isNotEmpty) return Uri.parse(configured);
    if (kReleaseMode) return Uri();
    return Uri.parse(
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8090'
          : 'http://127.0.0.1:8090',
    );
  }

  void _checkUrl() {
    final local = const [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '::1',
    ].contains(baseUrl.host);
    if (!baseUrl.hasAuthority ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.scheme != 'https' &&
            !(baseUrl.scheme == 'http' && local && !kReleaseMode))) {
      throw const AccountError('Сервер аккаунтов ещё не настроен.');
    }
  }

  String get _server => baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');

  Future<void> initialize() {
    if (initialized) return Future.value();
    return _initializing ??= _restore().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _restore() async {
    String? saved;
    try {
      saved = await _vault.read();
    } catch (_) {
      throw const AccountError(
        'Не удалось открыть защищённое хранилище. Повтори попытку.',
      );
    }
    if (saved != null) {
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      } catch (_) {
        await _clear();
        initialized = true;
        notifyListeners();
        return;
      }
      // Never transmit a stored token to a different configured server.
      if (data['server'] != _server || data['token'] is! String) {
        await _clear();
      } else {
        try {
          final response = await _request(
            'auth-refresh',
            {},
            token: data['token'] as String,
          );
          await _accept(response);
        } on _RejectedSession {
          await _clear();
        }
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
  }) async {
    await initialize();
    await _request('records', {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': passwordConfirm,
      'name': name.trim(),
    });
    try {
      await signIn(email: email, password: password);
    } on AccountError catch (error) {
      throw AccountError(
        'Аккаунт создан, но вход не завершён. Войди с тем же email и паролем. ${error.message}',
        accountCreated: true,
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await initialize();
    final response = await _request('auth-with-password', {
      'identity': email.trim(),
      'password': password,
    });
    await _accept(response);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clear();
    account = null;
    _token = null;
    initialized = true;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final current = account;
    final token = _token;
    if (current == null || token == null) {
      throw const AccountError('Сначала войди в аккаунт.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 40) {
      throw const AccountError('Имя должно содержать от 1 до 40 символов.');
    }
    final record = await _request(
      'records/${Uri.encodeComponent(current.id)}',
      {'name': trimmed},
      token: token,
      method: 'PATCH',
    );
    if (account?.id != current.id || _token != token) {
      throw const AccountError('Аккаунт изменился. Повтори сохранение.');
    }
    if (record['id'] != current.id || record['name'] is! String) {
      throw const AccountError('Сервер не подтвердил изменение имени.');
    }
    account = PaceAccount(
      id: current.id,
      email: current.email,
      name: record['name'] as String,
      profile: current.profile,
      supportsProfile: current.supportsProfile,
    );
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final current = account;
    final token = _token;
    if (current == null || token == null) {
      throw const AccountError('Сначала войди в аккаунт.');
    }
    if (!current.supportsProfile) {
      throw const AccountError(
        'Перезапусти сервер PACE, чтобы включить сохранение профиля.',
      );
    }
    final record = await _request(
      'records/${Uri.encodeComponent(current.id)}',
      {'profile': profile},
      token: token,
      method: 'PATCH',
    );
    if (account?.id != current.id || _token != token) {
      throw const AccountError('Аккаунт изменился. Повтори сохранение.');
    }
    if (record['id'] != current.id ||
        record['profile'] is! Map ||
        !mapEquals(
          Map<String, dynamic>.from(record['profile'] as Map),
          profile,
        )) {
      throw const AccountError('Сервер не подтвердил сохранение профиля.');
    }
    account = PaceAccount(
      id: current.id,
      email: current.email,
      name: current.name,
      profile: Map<String, dynamic>.unmodifiable(profile),
      supportsProfile: true,
    );
    notifyListeners();
  }

  Future<void> _clear() async {
    try {
      await _vault.clear();
    } catch (_) {
      throw const AccountError(
        'Не удалось удалить сохранённую сессию. Повтори попытку.',
      );
    }
  }

  Future<void> _accept(Map<String, dynamic> data) async {
    final token = data['token'];
    final record = data['record'];
    if (token is! String ||
        token.isEmpty ||
        record is! Map ||
        record['collectionName'] != 'pace_users' ||
        record['id'] is! String ||
        record['email'] is! String) {
      throw const AccountError(
        'Сервер вернул некорректную сессию. Повтори вход.',
      );
    }
    try {
      final saved = jsonEncode({'server': _server, 'token': token});
      await _vault.write(saved);
      if (await _vault.read() != saved) {
        throw StateError('Session write was not persisted');
      }
    } catch (_) {
      throw const AccountError(
        'Не удалось безопасно сохранить вход. Повтори попытку.',
      );
    }
    _token = token;
    account = PaceAccount(
      id: record['id'] as String,
      email: record['email'] as String,
      name: record['name'] as String? ?? '',
      profile: record['profile'] is Map
          ? Map<String, dynamic>.from(record['profile'] as Map)
          : null,
      supportsProfile: record.containsKey('profile'),
    );
  }

  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, dynamic> body, {
    String? token,
    String method = 'POST',
  }) async {
    _checkUrl();
    http.Response response;
    try {
      final request =
          http.Request(
              method,
              Uri.parse('$_server/api/collections/pace_users/$action'),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': ?token,
            })
            ..body = jsonEncode(body);
      Future<http.Response> send() async =>
          http.Response.fromStream(await _client.send(request));
      response = await send().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AccountError(
        action == 'records'
            ? 'Нет ответа сервера. Если аккаунт уже создан, попробуй войти.'
            : 'Нет связи с сервером. Проверь интернет и повтори попытку.',
      );
    }
    if (action == 'auth-refresh' &&
        const [400, 401, 403].contains(response.statusCode)) {
      throw const _RejectedSession();
    }
    if (response.statusCode == 429) {
      throw const AccountError('Слишком много попыток. Подожди немного.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (action == 'auth-with-password' && response.statusCode == 400) {
        throw const AccountError('Неверный email или пароль.');
      }
      if (action == 'records' && response.statusCode == 400) {
        throw const AccountError(
          'Не удалось создать аккаунт. Проверь поля; если email уже использован, выбери вход.',
        );
      }
      throw const AccountError(
        'Сервер временно недоступен. Повтори попытку позже.',
      );
    }
    try {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } catch (_) {
      throw const AccountError('Не удалось прочитать ответ сервера.');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _RejectedSession implements Exception {
  const _RejectedSession();
}
