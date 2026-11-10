import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/personal_record.dart';
import '../../models/workout.dart';
import '../../widgets/glass_widgets.dart';

class RecordsView extends StatefulWidget {
  const RecordsView({super.key, required this.workouts});
  final List<Workout> workouts;
  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  String? sport;
  @override
  Widget build(BuildContext context) {
    final best = <String, PersonalRecord>{};
    for (final workout in widget.workouts) {
      for (final r in workout.records) {
        if (!best.containsKey(r.id) ||
            r.milliseconds < best[r.id]!.milliseconds) {
          best[r.id] = r;
        }
      }
    }
    final rules = RecordDistance.catalog
        .where((r) => sport == null || r.sport == sport)
        .toList();
    return ListView.builder(
      key: const PageStorageKey('personal-records'),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
      itemCount: rules.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Личные рекорды',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Первый результат +50 XP. Каждое улучшение +100 XP. Лучший непрерывный отрезок по GPS; паузы и разрывы не соединяются. Старые записи без времени точек не учитываются.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 12),
              const Text(
                'Рельеф и условия могут отличаться. Плавание — только GPS на открытой воде; бассейн пока не поддерживается.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: sport ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Вид спорта'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Все виды спорта'),
                  ),
                  ...RecordDistance.catalog
                      .map((r) => r.sport)
                      .toSet()
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => sport = v == '' ? null : v),
              ),
              const SizedBox(height: 18),
            ],
          );
        }
        final rule = rules[index - 1];
        final r = best[rule.id];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rule.sport} · ${rule.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  r?.timeLabel ?? 'Пока нет результата',
                  style: const TextStyle(color: lime, fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  r == null
                      ? 'Нужна непрерывная запись с точным GPS'
                      : '${r.at.day}.${r.at.month.toString().padLeft(2, '0')}.${r.at.year} · Улучшений: ${r.improvements}',
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
