import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_widgets.dart';
import '../auth/sign_in_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.sports,
    required this.sportIcons,
    required this.selectedSport,
    required this.tracking,
    required this.onSelectSport,
  });

  final List<String> sports;
  final List<IconData> sportIcons;
  final int selectedSport;
  final bool tracking;
  final ValueChanged<int> onSelectSport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 132),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Профиль',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 28),
        const CircleAvatar(
          radius: 46,
          backgroundColor: panel,
          child: Icon(Icons.person_rounded, size: 54, color: lime),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'BODYA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 5),
        const Center(
          child: Text('Универсальный атлет', style: TextStyle(color: muted)),
        ),
        const SizedBox(height: 25),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SignInPage()),
            );
          },
          icon: const Icon(Icons.login_rounded),
          label: const Text('Войти в аккаунт'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 25),
        sectionTitle('СПОРТИВНЫЙ ПРОФИЛЬ'),
        const SizedBox(height: 12),
        ...sports.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: GlassPanel(
              padding: EdgeInsets.zero,
              radius: 24,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(
                  sportIcons[entry.key],
                  color: selectedSport == entry.key ? lime : muted,
                ),
                title: Text(entry.value),
                trailing: selectedSport == entry.key
                    ? const Icon(Icons.check_circle, color: lime)
                    : null,
                onTap: tracking ? null : () => onSelectSport(entry.key),
              ),
            ),
          );
        }),
        const SizedBox(height: 15),
        const Text(
          'PACE · Локальный прототип',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}
