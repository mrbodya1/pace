class CompetitionRule {
  static String workoutCount(int count) {
    final suffix = count % 100 >= 11 && count % 100 <= 14
        ? 'тренировок'
        : count % 10 == 1
        ? 'тренировка'
        : count % 10 >= 2 && count % 10 <= 4
        ? 'тренировки'
        : 'тренировок';
    return '$count $suffix';
  }

  CompetitionRule.fromJson(Map<String, dynamic> data)
    : metric = data['metric'] as String,
      sex = data['sex'] as String? ?? 'any',
      minDistance = (data['minDistanceKm'] as num?)?.toDouble() ?? 0,
      minDuration = (data['minDurationSeconds'] as num?)?.toDouble() ?? 0,
      minAscent = (data['minAscentMeters'] as num?)?.toDouble() ?? 0,
      minPace = (data['minPaceSeconds'] as num?)?.toDouble() ?? 0,
      maxPace = (data['maxPaceSeconds'] as num?)?.toDouble() ?? 0;
  static const labels = {
    'distance': 'Больше километров',
    'duration': 'Больше времени',
    'ascent': 'Больше набора высоты',
    'workouts': 'Больше тренировок',
  };
  final String metric, sex;
  final double minDistance, minDuration, minAscent, minPace, maxPace;
  String get title => labels[metric] ?? 'Соревнование';
  static String number(num value) => value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  static String pace(num seconds) =>
      '${seconds ~/ 60}:${(seconds.round() % 60).toString().padLeft(2, '0')}';
  String format(int score) => switch (metric) {
    'distance' => '${number(score / 1000)} км',
    'duration' =>
      '${score ~/ 3600} ч ${((score % 3600) ~/ 60).toString().padLeft(2, '0')} мин ${(score % 60).toString().padLeft(2, '0')} с',
    'ascent' => '$score м',
    _ => '$score трен.',
  };
  List<String> get conditions => [
    'Сумма подходящих тренировок за период соревнования',
    if (sex != 'any')
      sex == 'male' ? 'Категория: мужчины' : 'Категория: женщины',
    if (minDistance > 0) 'Дистанция тренировки: от ${number(minDistance)} км',
    if (minDuration > 0) 'Время тренировки: от ${number(minDuration / 60)} мин',
    if (minAscent > 0) 'Набор за тренировку: от ${number(minAscent)} м',
    if (minPace > 0) 'Темп не быстрее ${pace(minPace)} /км',
    if (maxPace > 0) 'Темп не медленнее ${pace(maxPace)} /км',
    'Без обязательной записи пульса',
    'Тренировки должны начаться после вступления и полностью пройти в срок соревнования.',
  ];
}

class CompetitionStanding {
  CompetitionStanding.fromJson(Map<String, dynamic> data)
    : id = data['entryId'] as String,
      name = data['name'] as String,
      me = data['me'] == true,
      score = data['score'] as int,
      workouts = data['workouts'] as int,
      rank = data['rank'] as int;
  final String id, name;
  final bool me;
  final int score, workouts, rank;
}

class CompetitionResults {
  CompetitionResults.fromJson(Map<String, dynamic> data)
    : available = data['available'] == true,
      rule = data['rule'] is Map
          ? CompetitionRule.fromJson(
              Map<String, dynamic>.from(data['rule'] as Map),
            )
          : null,
      page = data['page'] as int? ?? 0,
      hasMore = data['hasMore'] == true,
      participants = data['participants'] as int? ?? 0,
      ranked = data['ranked'] as int? ?? 0,
      rows = (data['rows'] as List? ?? [])
          .map(
            (e) => CompetitionStanding.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      mine = data['mine'] is Map
          ? Map<String, dynamic>.from(data['mine'] as Map)
          : null;
  final bool available, hasMore;
  final CompetitionRule? rule;
  final int page, participants, ranked;
  final List<CompetitionStanding> rows;
  final Map<String, dynamic>? mine;
  static const reasons = {
    'time': 'Нет точного времени начала или окончания',
    'beforeJoin': 'Началась до вступления',
    'period': 'Завершилась за пределами срока',
    'duplicate': 'Повторная запись тренировки',
    'sport': 'Другой вид спорта',
    'sex': 'Не соответствует категории участников',
    'metrics': 'Недостаточные или некорректные показатели',
    'ascent': 'Нет данных о наборе высоты',
    'conditions': 'Не соответствует условиям тренировки',
  };
}
