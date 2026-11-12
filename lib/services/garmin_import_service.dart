import '../data/storage/local_storage_service.dart';
import '../models/workout.dart';
import '../models/specialization.dart';
import '../models/participant_sex.dart';
import '../models/sport_catalog.dart';
import 'account_service.dart';
import 'workout_xp_calculator.dart';

/// Automatic checks are event-driven; no timer is installed by this gate.
class GarminRefreshGate {
  DateTime? _lastAttempt;
  bool claim(DateTime now, {bool force = false}) {
    final last = _lastAttempt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(minutes: 5)) {
      return false;
    }
    _lastAttempt = now;
    return true;
  }
}

abstract final class GarminImportService {
  static Workout parse(
    Map<String, dynamic> a,
    DateTime since,
    Map<String, dynamic> profile,
  ) {
    final id = a['externalId'];
    final source = a['source'];
    final start = DateTime.parse(a['startedAt'] as String).toUtc();
    final km = a['distanceKm'];
    final seconds = a['durationSeconds'];
    final sport = a['sport'];
    final elevation = a['elevationGain'];
    final sportIndex = SportCatalog.names.indexOf(sport is String ? sport : '');
    if (source != 'garmin-personal' ||
        id is! String ||
        !RegExp(r'^[0-9]{1,20}$').hasMatch(id) ||
        start.isBefore(since) ||
        start.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5))) ||
        km is! num ||
        !km.isFinite ||
        km < .05 ||
        seconds is! int ||
        seconds <= 0 ||
        !SportCatalog.isSelectable(sportIndex) ||
        (elevation != null &&
            (elevation is! num || !elevation.isFinite || elevation < 0))) {
      throw const FormatException('Invalid new Garmin activity');
    }
    final rawRoute = a['route'] as List? ?? [];
    final end = a['endedAt'] is String
        ? DateTime.parse(a['endedAt'] as String).toUtc()
        : null;
    if (end != null &&
        (end.difference(start).inMilliseconds < seconds * 1000 - 1000 ||
            end.isAfter(
              DateTime.now().toUtc().add(const Duration(minutes: 5)),
            ))) {
      throw const FormatException('Invalid Garmin finish time');
    }
    final rawHeart = a['heartRateSamples'] as List? ?? [];
    if (rawRoute.length > 30000 || rawHeart.length > 100000) {
      throw const FormatException('Garmin activity too large');
    }
    final route = rawRoute
        .map((p) => RoutePoint.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    final heart = rawHeart
        .map(
          (p) => HeartRateSample.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList();
    for (final p in route) {
      if (!p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180 ||
          p.timestamp == null ||
          p.timestamp!.isBefore(start)) {
        throw const FormatException('Invalid Garmin route');
      }
    }
    final breakdown = WorkoutXpCalculator.calculate(
      sport: sport as String,
      distanceKm: km.toDouble(),
      activeDuration: Duration(seconds: seconds),
      elevationMeters: (elevation as num?)?.toDouble() ?? 0,
      specialization: Specialization.fromId(profile['specializationId']),
      participantSex: ParticipantSex.fromId(profile['sex']),
    );
    return Workout(
      date: start,
      startedAt: start,
      endedAt: end,
      sessionId: 'garmin-personal:$id',
      sport: sport,
      distance: km.toDouble(),
      duration: Duration(seconds: seconds),
      xp: breakdown.total,
      xpBreakdown: breakdown,
      elevationGain: (elevation)?.toDouble(),
      route: route,
      timedRoute: route,
      source: source as String,
      externalId: id,
      sourceFitHash: a['fitSha256'] as String?,
      importedAt: DateTime.parse(a['receivedAt'] as String).toUtc(),
      heartRateSamples: heart,
    );
  }

  static bool possibleDuplicate(Workout incoming, Workout existing) {
    if (existing.source == 'garmin-personal' ||
        existing.sport != incoming.sport) {
      return false;
    }
    return existing.date.difference(incoming.date).inSeconds.abs() <= 120 &&
        (existing.distance - incoming.distance).abs() <=
            (incoming.distance * .02).clamp(.05, double.infinity) &&
        (existing.duration.inSeconds - incoming.duration.inSeconds).abs() <=
            (incoming.duration.inSeconds * .02).clamp(60, double.infinity);
  }

  static Future<({int imported, int conflicts})> importNew({
    required AccountService accounts,
    required LocalStorageService storage,
    required Map<String, dynamic> profile,
    bool refresh = false,
    bool force = false,
    bool Function()? shouldContinue,
    Future<void> Function(Duration)? wait,
  }) async {
    final owner = storage.owner;
    if (owner == null || owner != accounts.progressOwner) {
      return (imported: 0, conflicts: 0);
    }
    if (refresh) {
      // First read is cheap: unlinked users must never start the shared collector.
      final linked = await accounts.requestGarmin(owner: owner);
      if (linked['available'] != true) return (imported: 0, conflicts: 0);
      await accounts.requestGarminRefresh(owner: owner, force: force);
    }
    var response = await accounts.requestGarmin(owner: owner);
    for (
      var poll = 0;
      refresh && (response['refresh'] as Map?)?['phase'] == 'running';
      poll++
    ) {
      if (poll >= 45) {
        throw const AccountError(
          'Garmin ещё обновляется. Повтори обновление позже.',
        );
      }
      if (shouldContinue != null && !shouldContinue()) {
        return (imported: 0, conflicts: 0);
      }
      await (wait ?? Future<void>.delayed)(const Duration(seconds: 2));
      if (shouldContinue != null && !shouldContinue()) {
        return (imported: 0, conflicts: 0);
      }
      response = await accounts.requestGarmin(owner: owner);
    }
    if (refresh && (response['refresh'] as Map?)?['phase'] == 'error') {
      throw const AccountError('Не удалось обновить Garmin. Повтори позже.');
    }
    if (response['available'] != true) return (imported: 0, conflicts: 0);
    final since = DateTime.parse(response['sinceUtc'] as String).toUtc();
    final raw = response['activities'] as List;
    if (raw.length > 200) throw const FormatException('Garmin inbox too large');
    final incoming =
        raw
            .map(
              (v) => parse(Map<String, dynamic>.from(v as Map), since, profile),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    var imported = 0, conflicts = 0;
    for (final workout in incoming) {
      if (owner != accounts.progressOwner) {
        throw const AccountError('Аккаунт изменился. Повтори синхронизацию.');
      }
      final saved = await storage.loadProgress();
      final history = (saved?['workouts'] as List? ?? [])
          .map((v) => Workout.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      if (history.any((w) => w.sessionId == workout.sessionId)) continue;
      if (history.any((w) => possibleDuplicate(workout, w))) {
        conflicts++;
        continue;
      }
      await storage.completeWorkout(
        workout: workout,
        initialXp: (saved?['xp'] as num?)?.toInt() ?? 0,
        selectedSport: (saved?['selectedSport'] as num?)?.toInt() ?? 0,
        initialWorkouts: history,
        clearActiveDraft: false,
      );
      imported++;
    }
    return (imported: imported, conflicts: conflicts);
  }
}
