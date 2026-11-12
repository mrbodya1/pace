import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'progress_v2.dart';
import 'workout.dart';

/// Stable identity uses base measurements, never rewards rebased during sync.
class WorkoutUpload {
  WorkoutUpload(Workout workout) {
    final json = workout.toJson();
    for (final kind in ['route', 'timedRoute', 'heartRateSamples']) {
      final data = json[kind] as List? ?? [];
      for (var offset = 0; offset < data.length; offset += 500) {
        final raw = jsonEncode(
          data.sublist(offset, (offset + 500).clamp(0, data.length)),
        );
        if (utf8.encode(raw).length > 131072) {
          throw const FormatException('Telemetry part too large');
        }
        parts.add({'kind': kind, 'part': offset ~/ 500, 'digest': digest(raw)});
        payloads.add(raw);
      }
    }
    fingerprint = digest(
      jsonEncode({'summary': ProgressV2.summary(workout), 'parts': parts}),
    );
  }
  static String digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  final parts = <Map<String, dynamic>>[];
  final payloads = <String>[];
  late final String fingerprint;
}
