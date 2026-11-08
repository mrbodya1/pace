import 'package:flutter/material.dart';

import 'glass_widgets.dart';

/// A single ambient canvas continues behind the toolbar and page content.
class PacePageScaffold extends StatelessWidget {
  const PacePageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.background,
  });

  final String title;
  final Widget body;
  final Widget? background;

  @override
  Widget build(BuildContext context) => PaceBackground(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (background != null) Positioned.fill(child: background!),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            forceMaterialTransparency: true,
          ),
          body: body,
        ),
      ],
    ),
  );
}
