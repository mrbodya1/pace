import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../services/account_service.dart';
import '../../widgets/pace_page_scaffold.dart';

class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({
    super.key,
    required this.accounts,
    this.register = true,
  });
  final AccountService accounts;
  final bool register;
  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _register = widget.register;
  bool _busy = false, _hidden = true;
  bool _needsCharacter = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.accounts.register(
          email: _email.text,
          password: _password.text,
          passwordConfirm: _confirm.text,
          name: _name.text,
        );
      } else {
        await widget.accounts.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(_register || _needsCharacter);
    } on AccountError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        if (error.accountCreated) {
          _register = false;
          _needsCharacter = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось завершить вход. Повтори попытку.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: PacePageScaffold(
      title: _register ? 'Регистрация' : 'Вход по почте',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _register ? 'Создай аккаунт PACE' : 'С возвращением',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Тренировки и XP пока хранятся только на этом устройстве.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  children: [
                    if (_register) ...[
                      TextFormField(
                        key: const ValueKey('auth-name'),
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Имя (необязательно)',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => (value?.trim().length ?? 0) > 40
                            ? 'Не больше 40 символов'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const ValueKey('auth-email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Укажи корректный email',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('auth-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hidden,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        helperText: _register ? 'Не менее 12 символов' : null,
                        suffixIcon: IconButton(
                          tooltip: _hidden
                              ? 'Показать пароль'
                              : 'Скрыть пароль',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Укажи пароль'
                          : _register && value.runes.length < 12
                          ? 'Не менее 12 символов'
                          : null,
                    ),
                    if (_register) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const ValueKey('auth-confirm'),
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: _hidden,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Повтори пароль',
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : 'Пароли не совпадают',
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('auth-submit'),
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? 'Подожди…'
                              : _register
                              ? 'Создать аккаунт'
                              : 'Войти',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _register = !_register;
                              _error = null;
                              _password.clear();
                              _confirm.clear();
                              _form.currentState?.reset();
                            }),
                      child: Text(
                        _register
                            ? 'Уже есть аккаунт? Войти'
                            : 'Создать новый аккаунт',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Подтверждение email и восстановление пароля письмом пока недоступны.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
