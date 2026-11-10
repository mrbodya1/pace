import '../../widgets/reward_badge.dart';

import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/achievement.dart';
import '../../models/workout.dart';
import '../../widgets/glass_widgets.dart';

class AchievementsView extends StatefulWidget {
  const AchievementsView({
    super.key,
    required this.workouts,
    this.state,
    this.initialSport,
    this.initialMetric,
    this.selectedId,
  });
  final List<Workout> workouts;
  final AchievementState? state;
  final String? initialSport, initialMetric, selectedId;
  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView> {
  late String? sport = widget.initialSport;
  late String? metric = widget.initialMetric;
  @override
  Widget build(BuildContext context) {
    final state =
        widget.state ?? AchievementEngine.restore(null, widget.workouts);
    final progress = AchievementProgress(widget.workouts);
    final rules = AchievementCatalog.rules
        .where(
          (r) =>
              (sport == null || r.sport == sport) &&
              (metric == null || r.metric == metric),
        )
        .toList();
    final selected = rules.indexWhere((r) => r.id == widget.selectedId);
    if (selected > 0) {
      final rule = rules.removeAt(selected);
      rules.insert(0, rule);
    }
    final earned = rules.where((r) => state.unlocked.containsKey(r.id)).length;
    return ListView.builder(
      key: const PageStorageKey('earned-achievements'),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
      itemCount: rules.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Достижения: $earned / ${rules.length}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: sport,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Вид спорта'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Все виды и общие'),
                  ),
                  ...AchievementCatalog.rules
                      .map((r) => r.sport)
                      .toSet()
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s == 'Все виды' ? 'Общие достижения' : s),
                        ),
                      ),
                ],
                onChanged: (v) => setState(() => sport = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metric,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Показатель'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Все показатели'),
                  ),
                  ...AchievementCatalog.rules
                      .map((r) => r.metric)
                      .toSet()
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => metric = v),
              ),
              const SizedBox(height: 20),
            ],
          );
        }
        final rule = rules[index - 1];
        final unlock = state.unlocked[rule.id];
        final value = progress.value(rule);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassPanel(
            key: ValueKey('achievement-${rule.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RewardBadge.achievement(
                      rule,
                      earned: unlock != null,
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rule.id == widget.selectedId)
                            const Text(
                              'Выбранное достижение',
                              style: TextStyle(color: lime, fontSize: 12),
                            ),
                          Text(
                            '${rule.sport} · ${rule.metric}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${rule.target} · +${rule.xp} XP',
                  style: const TextStyle(color: lime, fontSize: 17),
                ),
                const SizedBox(height: 10),
                if (unlock == null) ...[
                  LinearProgressIndicator(
                    value: (value / rule.threshold).clamp(0, 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${value.toStringAsFixed(rule.unit == 'км'
                        ? 2
                        : rule.unit == 'ч'
                        ? 1
                        : 0).replaceAll('.', ',')} / ${rule.target}',
                    style: const TextStyle(color: muted),
                  ),
                ] else
                  Text(
                    unlock.historical
                        ? 'Засчитано из истории · XP не пересчитывались'
                        : 'Получено ${unlock.at.day}.${unlock.at.month.toString().padLeft(2, '0')}.${unlock.at.year} · +${unlock.xp} XP',
                    style: const TextStyle(color: muted),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
