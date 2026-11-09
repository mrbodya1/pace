import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

import 'package:sport_platform/main.dart' as app;
import 'package:sport_platform/features/onboarding/welcome_stories.dart';
import 'package:sport_platform/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Production root opens welcome before any application content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const app.PaceApp());
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeStories), findsOneWidget);
    expect(find.text('Обзор'), findsNothing);
    expect(find.text('Главная'), findsNothing);
  });

  testWidgets('PACE app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TestPaceApp());
    await tester.pumpAndSettle();
    expect(tester.widget<HomePage>(find.byType(HomePage)).xp, 0);

    expect(find.text('Обзор'), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
  });
}
