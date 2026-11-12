import 'package:flutter/material.dart';

import '../../models/competition.dart';

class CompetitionRuleDraft {
  String metric = 'distance', sex = 'any';
  final distance = TextEditingController(),
      duration = TextEditingController(),
      ascent = TextEditingController(),
      minPace = TextEditingController(),
      maxPace = TextEditingController();
  void dispose() {
    for (final controller in [distance, duration, ascent, minPace, maxPace]) {
      controller.dispose();
    }
  }

  static double? numeric(String text) {
    if (text.trim().isEmpty) return 0;
    return double.tryParse(text.replaceAll(',', '.').trim());
  }

  static int? parsePace(String text) {
    if (text.trim().isEmpty) return 0;
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]), seconds = int.tryParse(parts[1]);
    if (minutes == null ||
        minutes < 0 ||
        seconds == null ||
        seconds < 0 ||
        seconds > 59) {
      return null;
    }
    return minutes * 60 + seconds;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'metric': metric,
    'sex': sex,
    'requireHeartRate': false,
    'minDistanceKm': numeric(distance.text),
    'minDurationSeconds': (numeric(duration.text) ?? 0) * 60,
    'minAscentMeters': numeric(ascent.text),
    'minPaceSeconds': parsePace(minPace.text),
    'maxPaceSeconds': parsePace(maxPace.text),
  };
  String? get paceError {
    for (final entry in [(distance, 1.0), (duration, 60.0), (ascent, 1.0)]) {
      final value = numeric(entry.$1.text);
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value * entry.$2 > 10000000) {
        return 'Проверь числовые условия тренировки.';
      }
    }
    final min = parsePace(minPace.text), max = parsePace(maxPace.text);
    if (min == null || max == null || min > 10000000 || max > 10000000) {
      return 'Введи темп в формате мин:сек.';
    }
    return min > 0 && max > 0 && min > max ? 'Границы темпа перепутаны.' : null;
  }
}

class CompetitionRulesForm extends StatefulWidget {
  const CompetitionRulesForm({
    super.key,
    required this.draft,
    required this.enabled,
  });
  final CompetitionRuleDraft draft;
  final bool enabled;
  @override
  State<CompetitionRulesForm> createState() => _CompetitionRulesFormState();
}

class _CompetitionRulesFormState extends State<CompetitionRulesForm> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        initialValue: widget.draft.metric,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Зачёт'),
        items: [
          for (final item in CompetitionRule.labels.entries)
            DropdownMenuItem(value: item.key, child: Text(item.value)),
        ],
        onChanged: widget.enabled
            ? (v) => setState(() => widget.draft.metric = v!)
            : null,
      ),
      const SizedBox(height: 12),
      const Text(
        'Результат — сумма подходящих тренировок. Больше результат — выше место. Условия фиксируются при публикации.',
      ),
      Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Условия тренировки'),
          subtitle: const Text('Необязательно'),
          children: [
            DropdownButtonFormField<String>(
              initialValue: widget.draft.sex,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Категория участников',
              ),
              items: const [
                DropdownMenuItem(value: 'any', child: Text('Все участники')),
                DropdownMenuItem(value: 'male', child: Text('Мужчины')),
                DropdownMenuItem(value: 'female', child: Text('Женщины')),
              ],
              onChanged: widget.enabled
                  ? (v) => setState(() => widget.draft.sex = v!)
                  : null,
            ),
            _number(widget.draft.distance, 'Минимальная дистанция, км'),
            _number(widget.draft.duration, 'Минимальное время, мин'),
            _number(widget.draft.ascent, 'Минимальный набор, м'),
            _pace(widget.draft.minPace, 'Темп не быстрее, мин:сек/км'),
            _pace(widget.draft.maxPace, 'Темп не медленнее, мин:сек/км'),
            const SizedBox(height: 12),
            const Text(
              'Категория берётся из сохранённого расчёта тренировки. Темп — среднее время движения на километр; паузы не входят.',
            ),
          ],
        ),
      ),
    ],
  );
  Widget _number(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Без ограничения',
      ),
      validator: (v) {
        final value = CompetitionRuleDraft.numeric(v ?? '');
        return value == null || !value.isFinite || value < 0 || value > 10000000
            ? 'Введи число от 0 до 10000000'
            : null;
      },
    ),
  );
  Widget _pace(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: label, hintText: 'Например, 6:30'),
      validator: (v) => CompetitionRuleDraft.parsePace(v ?? '') == null
          ? 'Введи темп в формате мин:сек'
          : null,
    ),
  );
}
