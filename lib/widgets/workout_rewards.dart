import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/achievement.dart';
import '../models/personal_record.dart';
import '../models/workout.dart';
import 'glass_widgets.dart';
import 'reward_badge.dart';

class WorkoutRewards extends StatelessWidget {
  const WorkoutRewards({
    super.key,
    required this.workout,
    required this.onAchievement,
    required this.onRecord,
  });
  final Workout workout;
  final ValueChanged<AchievementRule> onAchievement;
  final ValueChanged<PersonalRecord> onRecord;
  @override
  Widget build(BuildContext context) {
    final earned = AchievementCatalog.rules
        .where((r) => workout.achievementIds.contains(r.id))
        .toList();
    return Column(
      children: [
        if (earned.isNotEmpty)
          _RewardSection(
            key: ValueKey('achievement-rewards-${workout.sessionId}'),
            title: 'Достижения',
            count: earned.length,
            xp: workout.achievementXp,
            icon: Icons.verified_outlined,
            accent: lime,
            rows: [
              for (final r in earned)
                _RewardRow(
                  key: ValueKey('earned-${r.id}'),
                  badge: RewardBadge.achievement(r),
                  title: r.metric == 'Тренировки по виду' && r.threshold == 1
                      ? 'Первая тренировка · ${r.sport}'
                      : '${r.metric}: ${r.target}',
                  subtitle: r.sport,
                  xp: r.xp,
                  accent: lime,
                  onTap: () => onAchievement(r),
                ),
            ],
          ),
        if (workout.records.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: earned.isEmpty ? 0 : 12),
            child: _RewardSection(
              key: ValueKey('record-rewards-${workout.sessionId}'),
              title: 'Рекорды',
              count: workout.records.length,
              xp: workout.recordXp,
              icon: Icons.emoji_events_outlined,
              accent: recordGold,
              rows: [
                for (final r in workout.records)
                  _RewardRow(
                    key: ValueKey('earned-record-${r.id}'),
                    badge: RewardBadge.record(r.meters),
                    title:
                        '${RecordDistance(r.sport, r.meters).label} · ${r.timeLabel}',
                    subtitle: r.improvements == 0
                        ? 'Первый результат'
                        : 'Новый личный рекорд',
                    xp: r.xp,
                    accent: recordGold,
                    onTap: () => onRecord(r),
                  ),
              ],
            ),
          ),
        if (earned.isEmpty && workout.records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Новых достижений и рекордов пока нет. Продолжай свой путь.',
              style: TextStyle(color: muted),
            ),
          ),
      ],
    );
  }
}

class _RewardSection extends StatelessWidget {
  const _RewardSection({
    super.key,
    required this.title,
    required this.count,
    required this.xp,
    required this.icon,
    required this.accent,
    required this.rows,
  });
  final String title;
  final int count, xp;
  final IconData icon;
  final Color accent;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      key: PageStorageKey(key.toString()),
      initiallyExpanded: false,
      maintainState: false,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: accent,
      collapsedIconColor: muted,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Icon(icon, color: accent),
      title: Text(
        '$title · $count',
        key: ValueKey('rewards-heading-$title'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      subtitle: Text('+$xp XP', style: TextStyle(color: accent, fontSize: 13)),
      childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      children: [
        for (final row in rows)
          Padding(padding: const EdgeInsets.only(top: 8), child: row),
      ],
    ),
  );
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.accent,
    required this.onTap,
  });
  final Widget badge;
  final String title, subtitle;
  final int xp;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF252736),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '+$xp XP',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 17, color: muted),
          ],
        ),
      ),
    ),
  );
}
