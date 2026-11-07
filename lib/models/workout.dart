class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
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

  Workout({
    required this.date,
    required this.distance,
    required this.duration,
    required this.xp,
    required this.sport,
    this.route = const [],
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'distance': distance,
        'durationSeconds': duration.inSeconds,
        'xp': xp,
        'sport': sport,
        'route': route.map((point) => point.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final savedRoute = (json['route'] as List<dynamic>? ?? [])
        .map((item) => RoutePoint.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();

    return Workout(
      date: DateTime.parse(json['date'] as String),
      distance: (json['distance'] as num).toDouble(),
      duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
      xp: (json['xp'] as num).toInt(),
      sport: json['sport'] as String,
      route: savedRoute,
    );
  }
}
