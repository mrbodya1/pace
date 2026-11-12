import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/features/workouts/paged_workout_history.dart';
import 'package:sport_platform/models/workout.dart';

class _Pages extends LocalStorageService {
  final requests = <({int offset, String? sport})>[];
  int details = 0;
  final rows = List.generate(
    43,
    (i) => Workout(
      sessionId: 'phone:$i',
      date: DateTime.utc(2026, 11, 12).subtract(Duration(days: i)),
      sport: i < 30 ? 'Бег' : 'Велосипед',
      distance: 10,
      duration: const Duration(hours: 1),
      xp: 100,
    ),
  );
  @override
  Future<List<Workout>> loadHistory({
    int limit = 20,
    int offset = 0,
    String? sport,
  }) async {
    requests.add((offset: offset, sport: sport));
    return rows
        .where((w) => sport == null || w.sport == sport)
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<Workout?> loadWorkout(String id) async {
    details++;
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() async => null;
}

void main() {
  testWidgets(
    'history requests twenty summaries, loads next page and fetches detail only after tapping',
    (tester) async {
      final storage = _Pages();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedWorkoutHistory(storage: storage, sports: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(storage.requests, [(offset: 0, sport: null)]);
      expect(storage.details, 0);
      await tester.scrollUntilVisible(
        find.text('Загрузить ещё'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Загрузить ещё'));
      await tester.pumpAndSettle();
      expect(storage.requests.last.offset, 20);
      expect(storage.details, 0);
      // Return to the start, then opening a row requests its full data.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == 'Открыть тренировку Бег',
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(storage.details, 1);
      expect(find.text('Тренировка недоступна.'), findsOneWidget);
    },
  );
  testWidgets('sport filter queries storage from the first page', (
    tester,
  ) async {
    final storage = _Pages();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedWorkoutHistory(
            storage: storage,
            sports: const ['Бег', 'Велосипед'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все виды спорта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Велосипед').last);
    await tester.pumpAndSettle();
    expect(storage.requests.last, (offset: 0, sport: 'Велосипед'));
    expect(find.text('Загрузить ещё'), findsNothing);
    expect(storage.details, 0);
  });
}
