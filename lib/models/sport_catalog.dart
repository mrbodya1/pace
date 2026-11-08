import 'package:flutter/material.dart';

/// Existing indices are part of pace_local_data: append sports, never reorder.
abstract final class SportCatalog {
  static const names = [
    'Бег',
    'Ходьба',
    'Велосипед',
    'Лыжи',
    'Трейл',
    'Скандинавская ходьба',
    'Поход',
    'Ролики',
  ];
  static const icons = [
    Icons.directions_run_rounded,
    Icons.directions_walk_rounded,
    Icons.directions_bike_rounded,
    Icons.downhill_skiing_rounded,
    Icons.terrain_rounded,
    Icons.nordic_walking_rounded,
    Icons.hiking_rounded,
    Icons.roller_skating_rounded,
  ];
  static const quickIndices = [0, 2, 3];

  static bool usesSpeed(String sport) =>
      sport == 'Велосипед' || sport == 'Ролики';
}
