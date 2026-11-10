import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/personal_record.dart';
import '../models/sport_catalog.dart';
import '../models/workout.dart';

abstract final class PersonalRecordEngine {
  static Map<String, PersonalRecord> restore(
    dynamic raw,
    List<Workout> history,
  ) {
    if (raw != null) {
      final json = Map<String, dynamic>.from(raw as Map);
      if (json['version'] != 1) {
        throw const FormatException('Unknown records version');
      }
      return {
        for (final r in (json['best'] as List).map(
          (v) => PersonalRecord.fromJson(Map<String, dynamic>.from(v as Map)),
        ))
          r.id: r,
      };
    }
    var best = <String, PersonalRecord>{};
    for (final w in history.reversed) {
      best = apply(best, w).best;
    }
    return best;
  }

  static Map<String, dynamic> toJson(Map<String, PersonalRecord> best) => {
    'version': 1,
    'best': best.values.map((r) => r.toJson()).toList(),
  };
  static ({
    Map<String, PersonalRecord> best,
    List<PersonalRecord> awards,
    int xp,
  })
  apply(Map<String, PersonalRecord> previous, Workout workout) {
    final best = Map<String, PersonalRecord>.from(previous);
    final awards = <PersonalRecord>[];
    if (workout.sessionId == null) return (best: best, awards: awards, xp: 0);
    for (final rule in RecordDistance.catalog.where(
      (r) => r.sport == SportCatalog.displayName(workout.sport),
    )) {
      final time = fastest(workout.timedRoute, rule.meters);
      if (time == null || time > workout.duration.inMilliseconds) continue;
      final old = best[rule.id];
      if (old != null &&
          (old.sessionId == workout.sessionId || time >= old.milliseconds)) {
        continue;
      }
      final result = PersonalRecord(
        sport: rule.sport,
        meters: rule.meters,
        milliseconds: time,
        at: workout.date,
        sessionId: workout.sessionId!,
        improvements: old == null ? 0 : old.improvements + 1,
        xp: old == null ? 50 : 100,
      );
      best[result.id] = result;
      awards.add(result);
    }
    return (
      best: best,
      awards: awards,
      xp: awards.fold(0, (sum, r) => sum + r.xp),
    );
  }

  // Only uninterrupted, sufficiently precise GPS stretches are eligible.
  // Time is interpolated on measured distance, never derived from average pace.
  static int? fastest(List<RoutePoint> route, double meters) {
    if (!meters.isFinite || meters <= 0) return null;
    final maxAccuracy = math.min(10.0, meters * .05);
    final chunks = <List<(double, double)>>[];
    var points = <(double, double)>[];
    RoutePoint? previous;
    var distance = 0.0;
    for (final p in route) {
      if (p.timestamp == null ||
          p.accuracy == null ||
          !p.accuracy!.isFinite ||
          p.accuracy! < 0 ||
          p.accuracy! > maxAccuracy ||
          !p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180) {
        previous = null;
        points = [];
        continue;
      }
      final before = previous;
      var delta = 0.0;
      var valid = false;
      if (before != null) {
        final dt =
            p.timestamp!.difference(before.timestamp!).inMilliseconds / 1000;
        delta = Geolocator.distanceBetween(
          before.latitude,
          before.longitude,
          p.latitude,
          p.longitude,
        );
        valid =
            p.segment == before.segment &&
            dt > 0 &&
            dt <= 15 &&
            delta <= 100 &&
            delta / dt <= 20;
      }
      if (!valid) {
        points = [];
        chunks.add(points);
        distance = 0;
      } else {
        distance += delta >= 1 ? delta : 0;
      }
      points.add((distance, p.timestamp!.millisecondsSinceEpoch.toDouble()));
      previous = p;
    }
    double? best;
    for (final chunk in chunks) {
      if (chunk.length < 2 || chunk.last.$1 < meters) continue;
      // A minimum of a piecewise linear duration occurs when either endpoint
      // coincides with a sample. Check both sets of breakpoints (O(n log n)).
      for (final p in chunk) {
        for (final start in [p.$1, p.$1 - meters]) {
          final end = start + meters;
          if (start < 0 || end > chunk.last.$1) continue;
          final duration = _time(chunk, end, false) - _time(chunk, start, true);
          if (duration > 0 && (best == null || duration < best)) {
            best = duration;
          }
        }
      }
    }
    return best?.ceil();
  }

  static double _time(
    List<(double, double)> points,
    double distance,
    bool departure,
  ) {
    var low = 0, high = points.length;
    // At stationary plateaus use last departure / first arrival, so waiting
    // outside the selected interval cannot falsely slow down that interval.
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (departure
          ? points[middle].$1 <= distance
          : points[middle].$1 < distance) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (departure && low > 0 && points[low - 1].$1 == distance) {
      return points[low - 1].$2;
    }
    if (low == 0) return points.first.$2;
    if (low == points.length) return points.last.$2;
    final a = points[low - 1], b = points[low];
    return a.$2 + (b.$2 - a.$2) * (distance - a.$1) / (b.$1 - a.$1);
  }
}
