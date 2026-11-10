class RecordDistance {
  const RecordDistance(this.sport, this.meters);
  final String sport;
  final double meters;
  String get id => '$sport:$meters';
  String get label => meters < 1000
      ? '${meters.round()} м'
      : '${(meters / 1000).toString().replaceAll(RegExp(r"\.0$"), "").replaceAll(".", ",")} км';
  static const catalog = [
    RecordDistance("Бег", 100.0),
    RecordDistance("Бег", 200.0),
    RecordDistance("Бег", 400.0),
    RecordDistance("Бег", 800.0),
    RecordDistance("Бег", 1000),
    RecordDistance("Бег", 1500.0),
    RecordDistance("Бег", 3000),
    RecordDistance("Бег", 5000),
    RecordDistance("Бег", 10000),
    RecordDistance("Бег", 15000),
    RecordDistance("Бег", 21097.5),
    RecordDistance("Бег", 42195.0),
    RecordDistance("Бег", 50000),
    RecordDistance("Бег", 100000),
    RecordDistance("Трейл", 5000),
    RecordDistance("Трейл", 10000),
    RecordDistance("Трейл", 15000),
    RecordDistance("Трейл", 21097.5),
    RecordDistance("Трейл", 30000),
    RecordDistance("Трейл", 50000),
    RecordDistance("Трейл", 80000),
    RecordDistance("Трейл", 100000),
    RecordDistance("Ходьба", 1000),
    RecordDistance("Ходьба", 3000),
    RecordDistance("Ходьба", 5000),
    RecordDistance("Ходьба", 10000),
    RecordDistance("Ходьба", 20000),
    RecordDistance("Ходьба", 30000),
    RecordDistance("Ходьба", 50000),
    RecordDistance("Лыжи", 1000),
    RecordDistance("Лыжи", 3000),
    RecordDistance("Лыжи", 5000),
    RecordDistance("Лыжи", 10000),
    RecordDistance("Лыжи", 15000),
    RecordDistance("Лыжи", 20000),
    RecordDistance("Лыжи", 30000),
    RecordDistance("Лыжи", 50000),
    RecordDistance("Лыжи", 70000),
    RecordDistance("Велосипед", 1000),
    RecordDistance("Велосипед", 5000),
    RecordDistance("Велосипед", 10000),
    RecordDistance("Велосипед", 20000),
    RecordDistance("Велосипед", 40000),
    RecordDistance("Велосипед", 50000),
    RecordDistance("Велосипед", 100000),
    RecordDistance("Велосипед", 150000),
    RecordDistance("Велосипед", 200000),
    RecordDistance("Роллеры", 1000),
    RecordDistance("Роллеры", 3000),
    RecordDistance("Роллеры", 5000),
    RecordDistance("Роллеры", 10000),
    RecordDistance("Роллеры", 15000),
    RecordDistance("Роллеры", 20000),
    RecordDistance("Роллеры", 30000),
    RecordDistance("Роллеры", 50000),
    RecordDistance("Плавание", 50.0),
    RecordDistance("Плавание", 100.0),
    RecordDistance("Плавание", 200.0),
    RecordDistance("Плавание", 400.0),
    RecordDistance("Плавание", 800.0),
    RecordDistance("Плавание", 1000),
    RecordDistance("Плавание", 1500.0),
    RecordDistance("Плавание", 2000),
    RecordDistance("Плавание", 3000),
    RecordDistance("Плавание", 4000),
    RecordDistance("Плавание", 5000),
    RecordDistance("Плавание", 10000),
  ];
}

class PersonalRecord {
  const PersonalRecord({
    required this.sport,
    required this.meters,
    required this.milliseconds,
    required this.at,
    required this.sessionId,
    this.improvements = 0,
    this.xp = 0,
  });
  final String sport, sessionId;
  final double meters;
  final int milliseconds, improvements, xp;
  final DateTime at;
  String get id => '$sport:$meters';
  String get timeLabel {
    final tenths = milliseconds ~/ 100;
    final seconds = tenths ~/ 10;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')},${tenths % 10}';
  }

  Map<String, dynamic> toJson() => {
    'sport': sport,
    'meters': meters,
    'milliseconds': milliseconds,
    'at': at.toUtc().toIso8601String(),
    'sessionId': sessionId,
    'improvements': improvements,
    'xp': xp,
  };
  factory PersonalRecord.fromJson(Map<String, dynamic> j) {
    final time = (j['milliseconds'] as num).toInt();
    if (time <= 0) throw const FormatException('Invalid record time');
    return PersonalRecord(
      sport: j['sport'] as String,
      meters: (j['meters'] as num).toDouble(),
      milliseconds: time,
      at: DateTime.parse(j['at'] as String),
      sessionId: j['sessionId'] as String,
      improvements: (j['improvements'] as num?)?.toInt() ?? 0,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
    );
  }
}
