import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/features/onboarding/welcome_stories.dart';

import 'workout_result_test.dart' as preview;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['PACE_RESULT_PREVIEW'] == null) return;
    final text = FontLoader('Roboto')
      ..addFont(
        File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('All four onboarding foregrounds contain real transparent and visible pixels', () async {
    for (final name in ['home', 'specializations', 'experience', 'community']) {
      final data = await rootBundle.load(
        'assets/images/onboarding/$name-v2.png',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var empty = 0, visible = 0;
      for (var i = 3; i < rgba.lengthInBytes; i += 4) {
        final a = rgba.getUint8(i);
        if (a == 0) empty++;
        if (a > 200) visible++;
      }
      expect(
        empty,
        greaterThan(1000),
        reason: '$name needs actual alpha, not a painted backdrop',
      );
      expect(
        visible,
        greaterThan(5000),
        reason: '$name must retain its foreground',
      );
      for (final pixel in [
        0,
        image.width - 1,
        (image.height - 1) * image.width,
        image.width * image.height - 1,
      ]) {
        expect(
          rgba.getUint8(pixel * 4 + 3),
          lessThan(10),
          reason: '$name canvas corner',
        );
      }
      image.dispose();
      codec.dispose();
    }
  });
  for (final layout in [
    (const Size(390, 844), 1.0),
    (const Size(1200, 800), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'Transparent stories retain navigation at ${layout.$1} / ${layout.$2}',
      (tester) async {
        tester.view.physicalSize = layout.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var completed = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('result-preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: paceTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.$2)),
                child: child!,
              ),
              home: WelcomeStories(
                onComplete: () async {
                  completed++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(WelcomeStories));
          for (final name in [
            'home',
            'specializations',
            'experience',
            'community',
          ]) {
            await precacheImage(
              AssetImage('assets/images/onboarding/$name-v2.png'),
              context,
            );
          }
        });
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('welcome-background'))),
          layout.$1,
        );
        for (var page = 0; page < 4; page++) {
          expect(find.text('${page + 1} / 4'), findsOneWidget);
          final image = find.byType(Image).first;
          expect(tester.widget<Image>(image).fit, BoxFit.contain);
          if (layout.$2 == 1) {
            await preview.capture(
              tester,
              '${layout.$1.width.toInt()}-story-${page + 1}',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(page == 3 ? 'Начать' : 'Дальше'));
          await tester.pumpAndSettle();
        }
        expect(completed, 1);
      },
    );
  }
}
