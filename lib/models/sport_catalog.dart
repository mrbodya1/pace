import 'package:flutter/material.dart';

/// Existing indices are part of pace_local_data: never reuse retired IDs.
abstract final class SportCatalog {
  static const names = [
    'Бег',
    'Ходьба',
    'Велосипед',
    'Лыжи',
    'Трейл',
    'Скандинавская ходьба',
    'Поход',
    'Роллеры',
    'Плавание',
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
    Icons.pool_rounded,
  ];
  static const quickIndices = [0, 2, 3];
  // IDs 5 and 6 remain reserved for old Nordic-walk/hike data.
  static const selectableIndices = [0, 1, 2, 3, 4, 7, 8];

  static bool isSelectable(int index) => selectableIndices.contains(index);

  static int restoreSelection(int index) =>
      isSelectable(index) ? index : (index == 5 || index == 6 ? 1 : 0);

  static String displayName(String sport) =>
      sport == 'Ролики' ? 'Роллеры' : sport;

  static bool usesSpeed(String sport) =>
      sport == 'Велосипед' || displayName(sport) == 'Роллеры';
}
