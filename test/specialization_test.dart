import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/data/storage/profile_storage_service.dart';
import 'package:sport_platform/features/profile/specialization_page.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

class UnavailableProfileStorage extends ProfileStorageService {
  @override
  Future<Map<String, dynamic>> selectSpecialization(
    Specialization specialization,
  ) async {
    throw StateError('Unavailable');
  }
}

Widget host({ProfileStorageService? storage, double scale = 1}) => MaterialApp(
  theme: paceTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => SpecializationPage(storage: storage),
          ),
        ),
        child: const Text('Открыть'),
      ),
    ),
  ),
);

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile settings opens all specializations and reflects a saved change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PaceApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Профиль'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-specialization')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-specialization')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Все 7 специализаций'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Все 7 специализаций'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Бегун'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-specialization')));
      await tester.pumpAndSettle();
      expect(find.byType(SpecializationPage), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-specialization')),
          matching: find.text('Бегун'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Changes are unrestricted, merge profile fields, preserve old workout XP',
    () async {
      final legacy = jsonEncode({'xp': 6840, 'workouts': []});
      SharedPreferences.setMockInitialValues({
        'pace_local_data': legacy,
        'pace_profile_data': jsonEncode({'name': 'Фёдор', 'height': 180}),
      });
      final storage = ProfileStorageService();
      await storage.selectSpecialization(Specialization.runner);
      final first = await storage.load();
      expect(first['name'], 'Фёдор');
      expect(first['height'], 180);
      expect(
        DateTime.parse(first['specializationChangedAt'] as String).isUtc,
        isTrue,
      );
      final same = await storage.selectSpecialization(Specialization.runner);
      expect(same['specializationChangedAt'], first['specializationChangedAt']);
      await storage.selectSpecialization(Specialization.swimmer);
      expect((await storage.load())['specializationId'], 'swimmer');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pace_local_data'), legacy);
    },
  );

  testWidgets(
    'Browsing and cancel do not save; confirm persists and reopen restores',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host());
      await open(tester);
      await tester.drag(
        find.byKey(const ValueKey('specialization-heroes')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pace_profile_data'), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await open(tester);
      await tester.drag(
        find.byKey(const ValueKey('specialization-heroes')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-specialization')));
      await tester.pumpAndSettle();
      expect(find.byType(SpecializationPage), findsNothing);
      expect(
        (await ProfileStorageService().load())['specializationId'],
        'skier',
      );
      await open(tester);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('save-specialization')),
      );
      expect(button.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('+20% за лыжи'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('+20% за лыжи'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed save leaves selection open and permits retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host(storage: UnavailableProfileStorage()));
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('save-specialization')));
    await tester.pumpAndSettle();
    expect(find.byType(SpecializationPage), findsOneWidget);
    expect(
      find.text('Не удалось сохранить специализацию. Попробуй снова.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('save-specialization')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('pace_profile_data'),
      isNull,
    );
  });

  testWidgets(
    'Small screen and large type retain access to selection and rules',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host(scale: 2));
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('Бонус специализации'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const ValueKey('save-specialization')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
