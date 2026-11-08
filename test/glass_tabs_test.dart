import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/widgets/glass_tabs.dart';

Widget tabsApp({bool reduceMotion = false, double textScale = 1}) {
  return MaterialApp(
    theme: paceTheme,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: DefaultTabController(
        length: 3,
        animationDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 360),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const GlassTabs(labels: ['Друзья', 'Клубы', 'Соревнования']),
                const Expanded(
                  child: TabBarView(
                    children: [
                      Center(child: Text('friends-page')),
                      Center(child: Text('clubs-page')),
                      Center(child: Text('events-page')),
                    ],
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

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Lens follows tap and page swipe at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tabsApp());
      await tester.pumpAndSettle();
      final controller = DefaultTabController.of(
        tester.element(find.byType(GlassTabs)),
      );
      await tester.ensureVisible(find.text('Соревнования'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Соревнования'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.animation!.value, greaterThan(0));
      expect(controller.animation!.value, lessThan(2));
      await tester.pumpAndSettle();
      expect(find.text('events-page').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(TabBarView), Offset(width * 0.8, 0));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(find.text('clubs-page').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Large labels remain accessible and reduced motion skips sliding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tabsApp(reduceMotion: true, textScale: 1.8));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Соревнования'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Соревнования'));
      await tester.pump();
      final controller = DefaultTabController.of(
        tester.element(find.byType(GlassTabs)),
      );
      expect(controller.indexIsChanging, isFalse);
      expect(controller.animation!.value, 2);
      expect(find.text('events-page').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
