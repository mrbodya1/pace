import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../services/account_service.dart';
import '../../data/storage/profile_storage_service.dart';
import '../../widgets/pace_page_scaffold.dart';
import '../profile/specialization_page.dart';
import 'email_auth_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    this.accounts,
    this.allowGuest = true,
    this.onAuthenticated,
  });
  final AccountService? accounts;
  final bool allowGuest;
  final VoidCallback? onAuthenticated;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late final accounts = widget.accounts ?? AccountService.instance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await accounts.initialize();
      if (mounted && accounts.account != null) _complete();
    } on AccountError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось восстановить вход. Повтори попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _complete() {
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _email({required bool register}) async {
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmailAuthPage(accounts: accounts, register: register),
      ),
    );
    if (!mounted) return;
    if (registered == true) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SpecializationPage(
            storage: ProfileStorageService(accounts: accounts),
          ),
        ),
      );
    }
    if (mounted && accounts.account != null) _complete();
  }

  Widget _provider(String name, Widget icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вход через $name пока не подключён.')),
      ),
      icon: icon,
      label: Text('Войти через $name'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: panel,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Color(0x506F748E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.allowGuest,
      child: PacePageScaffold(
        title: 'Вход в PACE',
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.bolt_rounded, size: 64, color: lime),
              const SizedBox(height: 24),
              Text(
                'Твой путь начинается здесь',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error == null) ...[
                _provider(
                  'VK',
                  const Text(
                    'VK',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _provider(
                  'Яндекс',
                  const Text(
                    'Я',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _provider('Mail', const Icon(Icons.alternate_email_rounded)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _email(register: true),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Регистрация'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _email(register: false),
                  child: const Text('Войти'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Повторить проверку входа'),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Тренировки и XP сохраняются только на этом устройстве. '
                'Вход пока не переносит их на другие устройства.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (widget.allowGuest)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Продолжить без входа'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
