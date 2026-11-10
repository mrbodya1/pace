import 'personal_record.dart';
import 'workout_xp.dart';

class RoutePoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime? timestamp;
  final double? accuracy;
  final int segment;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.timestamp,
    this.accuracy,
    this.segment = 0,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
    if (timestamp != null) 'timestamp': timestamp!.toUtc().toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (segment != 0) 'segment': segment,
  };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      segment: (json['segment'] as num?)?.toInt() ?? 0,
    );
  }
}

class Workout {
  final DateTime date;
  final double distance;
  final Duration duration;
  final int xp;
  final String sport;
  final int achievementXp;
  final List<String> achievementIds;
  final List<RoutePoint> route;
  final List<RoutePoint> timedRoute;
  final int recordXp;
  final List<PersonalRecord> records;
  final double? elevationGain;
  final WorkoutXp? xpBreakdown;
  final DateTime? startedAt;
  final String? sessionId;

  Workout({
    required this.date,
    required this.distance,
    required this.duration,
    required this.xp,
    required this.sport,
    this.route = const [],
    this.timedRoute = const [],
    this.recordXp = 0,
    this.records = const [],
    this.achievementXp = 0,
    this.achievementIds = const [],
    this.elevationGain,
    this.xpBreakdown,
    this.startedAt,
    this.sessionId,
  });

  Workout withAchievements(
    int reward,
    List<String> ids, {
    int recordReward = 0,
    List<PersonalRecord> recordResults = const [],
  }) => Workout(
    date: date,
    distance: distance,
    duration: duration,
    xp: xp + reward + recordReward,
    sport: sport,
    route: route,
    timedRoute: timedRoute,
    recordXp: recordReward,
    records: recordResults,
    elevationGain: elevationGain,
    xpBreakdown: xpBreakdown,
    startedAt: startedAt,
    sessionId: sessionId,
    achievementXp: reward,
    achievementIds: ids,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'distance': distance,
    'durationSeconds': duration.inSeconds,
    'xp': xp,
    'sport': sport,
    if (achievementXp != 0) 'achievementXp': achievementXp,
    if (achievementIds.isNotEmpty) 'achievementIds': achievementIds,
    if (timedRoute.isNotEmpty)
      'timedRoute': timedRoute.map((p) => p.toJson()).toList(),
    if (recordXp > 0) 'recordXp': recordXp,
    if (records.isNotEmpty) 'records': records.map((r) => r.toJson()).toList(),
    'route': route.map((point) => point.toJson()).toList(),
    if (elevationGain != null) 'elevationGain': elevationGain,
    if (xpBreakdown != null) 'xpBreakdown': xpBreakdown!.toJson(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (sessionId != null) 'sessionId': sessionId,
  };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final savedRoute = (json['route'] as List<dynamic>? ?? [])
        .map(
          (item) => RoutePoint.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return Workout(
      date: DateTime.parse(json['date'] as String),
      distance: (json['distance'] as num).toDouble(),
      duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
      xp: (json['xp'] as num).toInt(),
      sport: json['sport'] as String,
      achievementXp: (json['achievementXp'] as num?)?.toInt() ?? 0,
      achievementIds: List<String>.from(json['achievementIds'] as List? ?? []),
      route: savedRoute,
      timedRoute: (json['timedRoute'] as List? ?? [])
          .map((p) => RoutePoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      recordXp: (json['recordXp'] as num?)?.toInt() ?? 0,
      records: (json['records'] as List? ?? [])
          .map(
            (p) => PersonalRecord.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList(),
      elevationGain: (json['elevationGain'] as num?)?.toDouble(),
      xpBreakdown: json['xpBreakdown'] == null
          ? null
          : WorkoutXp.fromJson(
              Map<String, dynamic>.from(json['xpBreakdown'] as Map),
            ),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      sessionId: json['sessionId'] as String?,
    );
  }
}
