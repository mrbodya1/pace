
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/main.dart';

void main() {
  testWidgets('PACE app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PaceApp());

    expect(find.text('Обзор'), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
  });
}
