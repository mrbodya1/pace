import '../models/participant_sex.dart';
import '../models/specialization.dart';
import '../models/sport_catalog.dart';
import '../models/workout_xp.dart';

abstract final class WorkoutXpCalculator {
  static WorkoutXp calculate({
    required String sport,
    required double distanceKm,
    required Duration activeDuration,
    required double elevationMeters,
    Specialization? specialization,
    ParticipantSex? participantSex,
  }) {
    if (!distanceKm.isFinite ||
        distanceKm < 0 ||
        !elevationMeters.isFinite ||
        elevationMeters < 0 ||
        activeDuration.isNegative) {
      throw ArgumentError('Workout metrics must be finite and nonnegative');
    }
    final activity = SportCatalog.displayName(sport);
    final referenceKm = switch (activity) {
      'Бег' || 'Трейл' => 10.0,
      'Ходьба' => 5.0,
      'Лыжи' || 'Роллеры' => 15.0,
      'Велосипед' => 30.0,
      'Плавание' => 2.0,
      _ => throw ArgumentError.value(sport, 'sport', 'No XP reference'),
    };
    // Use the same whole active seconds that are stored in Workout.duration.
    final hours = activeDuration.inSeconds / 3600;
    final distance = 100 * distanceKm / referenceKm;
    final pace = hours > 0 && distanceKm > 0
        ? 100 * (distanceKm / hours) / referenceKm
        : 0.0;
    final duration = hours * 100;
    final elevation = activity == 'Плавание' ? 100.0 : elevationMeters;
    final running = activity == 'Бег' || activity == 'Трейл';
    final bonusFraction = switch (specialization) {
      Specialization.multiathlete => .05,
      Specialization.runner when running => .20,
      Specialization.marathoner when running => distanceKm / 21 * .20,
      Specialization.trailrunner when running => elevationMeters / 300 * .20,
      Specialization.skier when activity == 'Лыжи' => .20,
      Specialization.cyclist when activity == 'Велосипед' => .20,
      Specialization.swimmer when activity == 'Плавание' => .20,
      _ => 0.0,
    };
    final base = distance + pace + duration + elevation;
    return WorkoutXp(
      distance: distance,
      pace: pace,
      duration: duration,
      elevation: elevation,
      bonusFraction: bonusFraction,
      total: (base * (1 + bonusFraction)).round(),
      specialization: specialization,
      participantSex: participantSex,
    );
  }
}
