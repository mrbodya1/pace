import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/participant_sex.dart';
import '../models/workout_xp.dart';
import 'glass_widgets.dart';

class WorkoutXpPanel extends StatelessWidget {
  const WorkoutXpPanel({
    super.key,
    required this.value,
    this.achievementXp = 0,
    this.recordXp = 0,
    this.framed = true,
  });
  final WorkoutXp value;
  final int achievementXp;
  final int recordXp;
  final bool framed;

  String _number(double number) =>
      number.toStringAsFixed(1).replaceAll('.', ',');

  Widget _row(String label, String amount, {bool accent = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(color: accent ? Colors.white : muted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: accent ? lime : Colors.white,
              fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'За что начислены XP',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _row('Дистанция', '${_number(value.distance)} XP'),
        _row('Темп', '${_number(value.pace)} XP'),
        _row('Длительность', '${_number(value.duration)} XP'),
        _row('Подъём', '${_number(value.elevation)} XP'),
        const Divider(height: 22),
        _row('Базовые очки', '${_number(value.base)} XP'),
        const SizedBox(height: 8),
        Text(
          value.specialization?.titleFor(
                value.participantSex ?? ParticipantSex.male,
              ) ??
              'Без специализации',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        _row(
          'Бонус ${(value.bonusFraction * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
          '+${_number(value.bonus)} XP',
        ),
        const Divider(height: 22),
        if (achievementXp > 0)
          _row('Новые достижения', '+$achievementXp XP', accent: true),
        if (recordXp > 0) _row('Рекорды', '+$recordXp XP', accent: true),
        _row(
          'Итого',
          '${value.total + achievementXp + recordXp} XP',
          accent: true,
        ),
        const SizedBox(height: 8),
        const Text(
          'Время без пауз. Итог округлён один раз.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
    return framed
        ? GlassPanel(
            key: const ValueKey('workout-xp-breakdown'),
            child: content,
          )
        : content;
  }
}
