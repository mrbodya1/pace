import 'participant_sex.dart';
import 'specialization.dart';

/// Saved calculation snapshot: history never depends on the current profile.
class WorkoutXp {
  const WorkoutXp({
    required this.distance,
    required this.pace,
    required this.duration,
    required this.elevation,
    required this.bonusFraction,
    required this.total,
    this.specialization,
    this.participantSex,
    this.version = 1,
  });

  final double distance, pace, duration, elevation, bonusFraction;
  final int total, version;
  final Specialization? specialization;
  final ParticipantSex? participantSex;
  double get base => distance + pace + duration + elevation;
  double get bonus => base * bonusFraction;

  Map<String, dynamic> toJson() => {
    'version': version,
    'distance': distance,
    'pace': pace,
    'duration': duration,
    'elevation': elevation,
    'bonusFraction': bonusFraction,
    'total': total,
    'specializationId': specialization?.name,
    'participantSex': participantSex?.name,
  };

  factory WorkoutXp.fromJson(Map<String, dynamic> json) => WorkoutXp(
    version: (json['version'] as num).toInt(),
    distance: (json['distance'] as num).toDouble(),
    pace: (json['pace'] as num).toDouble(),
    duration: (json['duration'] as num).toDouble(),
    elevation: (json['elevation'] as num).toDouble(),
    bonusFraction: (json['bonusFraction'] as num).toDouble(),
    total: (json['total'] as num).toInt(),
    specialization: Specialization.fromId(json['specializationId']),
    participantSex: ParticipantSex.fromId(json['participantSex']),
  );
}
