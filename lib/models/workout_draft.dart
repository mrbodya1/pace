import 'workout.dart';

import 'dart:math';

import 'package:geolocator/geolocator.dart';

import 'participant_sex.dart';
import 'specialization.dart';
import 'sport_catalog.dart';

class WorkoutDraft {
  const WorkoutDraft({
    required this.id,
    required this.sportIndex,
    required this.startedAt,
    required this.savedAt,
    required this.activeDuration,
    required this.distanceMeters,
    required this.elevationMeters,
    required this.route,
    this.timedRoute = const [],
    this.specialization,
    this.participantSex,
  });

  final String id;
  final int sportIndex;
  final DateTime startedAt, savedAt;
  final Duration activeDuration;
  final double distanceMeters, elevationMeters;
  final List<Position> route;
  final List<RoutePoint> timedRoute;
  final Specialization? specialization;
  final ParticipantSex? participantSex;

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'sportIndex': sportIndex,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'savedAt': savedAt.toUtc().toIso8601String(),
    'activeMilliseconds': activeDuration.inMilliseconds,
    'distanceMeters': distanceMeters,
    'elevationMeters': elevationMeters,
    'specializationId': specialization?.name,
    'participantSex': participantSex?.name,
    'timedRoute': timedRoute.map((p) => p.toJson()).toList(),
    'route': route
        .map(
          (p) => p.toJson().map(
            (key, value) =>
                MapEntry(key, value is num && !value.isFinite ? null : value),
          ),
        )
        .toList(),
  };

  factory WorkoutDraft.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final sport = (json['sportIndex'] as num).toInt();
    final duration = (json['activeMilliseconds'] as num).toInt();
    final distance = (json['distanceMeters'] as num).toDouble();
    final elevation = (json['elevationMeters'] as num).toDouble();
    if (json['version'] != 1 ||
        id.isEmpty ||
        !SportCatalog.isSelectable(sport) ||
        duration < 0 ||
        !distance.isFinite ||
        distance < 0 ||
        !elevation.isFinite ||
        elevation < 0) {
      throw const FormatException('Unsupported workout draft');
    }
    return WorkoutDraft(
      id: id,
      timedRoute: (json['timedRoute'] as List? ?? [])
          .map((p) => RoutePoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      sportIndex: sport,
      startedAt: DateTime.parse(json['startedAt'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
      activeDuration: Duration(milliseconds: duration),
      distanceMeters: distance,
      elevationMeters: elevation,
      specialization: Specialization.fromId(json['specializationId']),
      participantSex: ParticipantSex.fromId(json['participantSex']),
      route: (json['route'] as List)
          .map((p) => Position.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}
