import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../widgets/glass_widgets.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  void _showUnavailable(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Вход через $provider пока не подключён.')),
    );
  }

  Widget _providerButton(
    BuildContext context, {
    required String name,
    required String label,
    required Widget icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: () => _showUnavailable(context, name),
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: panel,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: Color(0x506F748E)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт PACE'), backgroundColor: bg),
      body: PaceBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.bolt_rounded, size: 64, color: lime),
              const SizedBox(height: 24),
              const Text(
                'Твой путь начинается здесь',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Выбери удобный способ входа',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 16),
              ),
              const SizedBox(height: 32),
              _providerButton(
                context,
                name: 'VK',
                label: 'Войти через VK',
                icon: const Text(
                  'VK',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _providerButton(
                context,
                name: 'Яндекс',
                label: 'Войти через Яндекс',
                icon: const Text(
                  'Я',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _providerButton(
                context,
                name: 'Mail ID',
                label: 'Войти через Mail',
                icon: const Icon(Icons.alternate_email_rounded),
              ),
              const SizedBox(height: 8),
              _providerButton(
                context,
                name: 'электронную почту',
                label: 'Войти по почте',
                icon: const Icon(Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 12),
              const Text(
                'Вход скоро появится. Сейчас PACE сохраняет тренировки и XP '
                'только на этом устройстве.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
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
