import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import 'glass_widgets.dart';

class PaceHeader extends StatelessWidget {
  const PaceHeader({super.key, this.onProfile});
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'P A C E',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Обзор',
                style: TextStyle(
                  fontSize: 36,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Открыть профиль',
          child: IconButton(
            onPressed: onProfile,
            tooltip: 'Профиль',
            padding: EdgeInsets.zero,
            icon: const GlassPanel(
              radius: 28,
              padding: EdgeInsets.all(14),
              child: Icon(CupertinoIcons.person, size: 25, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
