import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';

/// Frosted controls inspired by the selected concept, rendered in Flutter.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final reduceEffects =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.highContrastOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: reduceEffects ? 0 : 18,
            sigmaY: reduceEffects ? 0 : 18,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: reduceEffects ? panel : const Color(0xA632384D),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: const Color(0x506F748E)),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

class PaceBackground extends StatelessWidget {
  const PaceBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: bg,
        image: DecorationImage(
          image: AssetImage('assets/images/pace_ambient.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

class GlassNavigation extends StatelessWidget {
  const GlassNavigation({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onRecord,
    this.recording = false,
    this.paused = false,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;
  final bool recording, paused;

  @override
  Widget build(BuildContext context) {
    const labels = ['Главная', 'Сообщество', 'Прогресс', 'Профиль'];
    const icons = [
      CupertinoIcons.house,
      CupertinoIcons.person_2,
      CupertinoIcons.chart_bar,
      CupertinoIcons.person,
    ];

    Widget destination(int i) {
      final selected = index == i;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: labels[i],
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x45D6D9F5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: selected
                        ? const Color(0x66E0E3FF)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: 24,
                      color: selected ? Colors.white : muted,
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : muted,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GlassPanel(
      radius: 36,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          destination(0),
          destination(1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Semantics(
              button: true,
              label: recording
                  ? (paused
                        ? 'Вернуться к тренировке на паузе'
                        : 'Вернуться к записи')
                  : 'Записать тренировку',
              child: ExcludeSemantics(
                child: IconButton.filled(
                  key: const ValueKey('record-workout'),
                  onPressed: onRecord,
                  style: IconButton.styleFrom(
                    backgroundColor: lime,
                    foregroundColor: bg,
                    fixedSize: const Size(52, 52),
                  ),
                  icon: Icon(
                    recording
                        ? (paused
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.waveform)
                        : CupertinoIcons.plus,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
          destination(2),
          destination(3),
        ],
      ),
    );
  }
}

class GlassWorkoutButton extends StatelessWidget {
  const GlassWorkoutButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Начать тренировку',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: GlassPanel(
            radius: 32,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.directions_run_rounded, size: 30),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Начать тренировку',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                const CircleAvatar(
                  backgroundColor: lime,
                  radius: 22,
                  child: Icon(CupertinoIcons.play_fill, color: bg, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
