import 'package:flutter/material.dart';

/// Stable IDs are stored separately from the workout sport selection.
enum Specialization {
  multiathlete(
    'Мультиатлет',
    'Разные виды спорта',
    '+5% за любой вид спорта',
    Icons.apps_rounded,
  ),
  runner(
    'Бегун',
    'Скорость и ритм',
    '+20% за бег',
    Icons.directions_run_rounded,
  ),
  marathoner(
    'Марафонец',
    'Дальше с каждым шагом',
    '+20% за каждые 21 км бега',
    Icons.route_rounded,
  ),
  trailrunner(
    'Трейлраннер',
    'Твой путь — к вершинам',
    '+20% за каждые 300 м набора в беге',
    Icons.landscape_rounded,
  ),
  skier(
    'Лыжник',
    'Движение сквозь зиму',
    '+20% за лыжи',
    Icons.downhill_skiing_rounded,
  ),
  cyclist(
    'Велосипедист',
    'Свобода на двух колёсах',
    '+20% за велосипед',
    Icons.directions_bike_rounded,
  ),
  swimmer('Пловец', 'В своей стихии', '+20% за плавание', Icons.pool_rounded);

  const Specialization(this.title, this.subtitle, this.bonus, this.icon);
  final String title, subtitle, bonus;
  final IconData icon;
  String get image => 'assets/images/specializations/$name.png';

  static Specialization? fromId(Object? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }

  String get explanation => switch (this) {
    marathoner => 'Бонус растёт плавно с дистанцией: 10 км — +9,52%, 21 км — +20%, 42 км — +40%. Верхнего ограничения нет.',
    trailrunner => 'Бонус растёт плавно с набором высоты: 150 м — +10%, 300 м — +20%, 600 м — +40%. Верхнего ограничения нет.',
    multiathlete =>
      'Небольшой постоянный бонус для тех, кто любит менять дисциплины.',
    _ => 'В своей дисциплине — дополнительный бонус. За остальные виды спорта ты получаешь обычные базовые очки.',
  };
}
