import 'workout_xp.dart';

class RoutePoint {
  final double latitude;
  final double longitude;
  final double? altitude;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
  };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
    );
  }
}

class Workout {
  final DateTime date;
  final double distance;
  final Duration duration;
  final int xp;
  final String sport;
  final List<RoutePoint> route;
  final double? elevationGain;
  final WorkoutXp? xpBreakdown;
  final DateTime? startedAt;

  Workout({
    required this.date,
    required this.distance,
    required this.duration,
    required this.xp,
    required this.sport,
    this.route = const [],
    this.elevationGain,
    this.xpBreakdown,
    this.startedAt,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'distance': distance,
    'durationSeconds': duration.inSeconds,
    'xp': xp,
    'sport': sport,
    'route': route.map((point) => point.toJson()).toList(),
    if (elevationGain != null) 'elevationGain': elevationGain,
    if (xpBreakdown != null) 'xpBreakdown': xpBreakdown!.toJson(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
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
      route: savedRoute,
      elevationGain: (json['elevationGain'] as num?)?.toDouble(),
      xpBreakdown: json['xpBreakdown'] == null
          ? null
          : WorkoutXp.fromJson(
              Map<String, dynamic>.from(json['xpBreakdown'] as Map),
            ),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
    );
  }
}
