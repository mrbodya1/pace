import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/storage/local_storage_service.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import 'workout_details_page.dart';

class PagedWorkoutHistory extends StatefulWidget {
  const PagedWorkoutHistory({
    super.key,
    required this.storage,
    required this.sports,
    this.updates,
  });
  final LocalStorageService storage;
  final List<String> sports;
  final ValueListenable<List<Workout>>? updates;
  @override
  State<PagedWorkoutHistory> createState() => _PagedWorkoutHistoryState();
}

class _PagedWorkoutHistoryState extends State<PagedWorkoutHistory> {
  List<Workout> rows = [];
  String? sport, error;
  bool loading = false, more = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.updates?.addListener(_refresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant PagedWorkoutHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updates != widget.updates) {
      oldWidget.updates?.removeListener(_refresh);
      widget.updates?.addListener(_refresh);
    }
    if (oldWidget.storage != widget.storage) {
      rows = [];
      sport = null;
      _load();
    }
  }

  @override
  void dispose() {
    generation++;
    widget.updates?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (next && loading) return;
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.storage.loadHistory(
        limit: 20,
        offset: next ? rows.length : 0,
        sport: sport,
      );
      if (mounted && version == generation) {
        setState(() {
          rows = next ? [...rows, ...page] : page;
          more = page.length == 20;
        });
      }
    } catch (_) {
      if (mounted && version == generation) {
        setState(() => error = 'Не удалось прочитать историю.');
      }
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _load(),
    child: ListView(
      key: const PageStorageKey('progress-history-v2'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
      children: [
        if (widget.sports.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: sport ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Вид спорта'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Все виды спорта')),
              for (final s in widget.sports)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              setState(() => sport = v == '' ? null : v);
              _load();
            },
          ),
          const SizedBox(height: 20),
        ],
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: () => _load(), child: const Text('Повторить')),
        ],
        if (!loading && rows.isEmpty && error == null)
          emptyCard('Здесь появятся твои записанные тренировки.'),
        for (final workout in rows)
          Semantics(
            button: true,
            label: 'Открыть тренировку ${workout.sport}',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutDetailsPage(
                    workout: workout,
                    storage: widget.storage,
                    historyUpdates: widget.updates,
                  ),
                ),
              ),
              child: workoutCard(workout, showRoute: false),
            ),
          ),
        if (more && rows.isNotEmpty)
          OutlinedButton(
            onPressed: loading ? null : () => _load(next: true),
            child: const Text('Загрузить ещё'),
          ),
      ],
    ),
  );
}
