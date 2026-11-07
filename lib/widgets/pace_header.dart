import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';

class PaceHeader extends StatelessWidget {
  const PaceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: bg,
            size: 29,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PACE',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            Text(
              'ATHLETE COMMUNITY',
              style: TextStyle(
                fontSize: 8,
                color: muted,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
        const Spacer(),
        const Icon(Icons.notifications_none_rounded),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 19,
          backgroundColor: panel,
          child: Text(
            'B',
            style: TextStyle(color: lime, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
