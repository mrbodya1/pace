import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/glass_tabs.dart';
import '../../app/theme/pace_theme.dart';
import '../../widgets/glass_widgets.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Text(
              'Сообщество',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GlassTabs(labels: ['Друзья', 'Клубы', 'Соревнования']),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _CommunityEmpty(
                  icon: CupertinoIcons.person_2,
                  title: 'Тренироваться вместе',
                  description:
                      'Здесь появятся друзья, их тренировки и достижения.',
                ),
                _CommunityEmpty(
                  icon: CupertinoIcons.person_3,
                  title: 'Своя команда',
                  description:
                      'Здесь будут твои клубы, участники и клубные события.',
                ),
                _CommunityEmpty(
                  icon: CupertinoIcons.rosette,
                  title: 'Новая цель',
                  description: 'Здесь появятся соревнования, участие и таблицы результатов.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityEmpty extends StatelessWidget {
  const _CommunityEmpty({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 48, 22, 140),
      children: [
        Icon(icon, size: 48, color: lime),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 28),
        const GlassPanel(
          child: Text(
            'Сообщество готовится к запуску. Пока можно записывать тренировки '
            'и следить за своим прогрессом.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}
