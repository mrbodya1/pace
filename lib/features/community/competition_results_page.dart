import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/competition.dart';
import '../../services/account_service.dart';
import '../../widgets/glass_widgets.dart';

class CompetitionResultsPage extends StatefulWidget {
  const CompetitionResultsPage({
    super.key,
    required this.accounts,
    required this.eventId,
    required this.title,
  });
  final AccountService accounts;
  final String eventId, title;
  @override
  State<CompetitionResultsPage> createState() => _CompetitionResultsPageState();
}

class _CompetitionResultsPageState extends State<CompetitionResultsPage> {
  late final String? owner = widget.accounts.progressOwner;
  CompetitionResults? results;
  List<CompetitionStanding> rows = [];
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (loading || owner != widget.accounts.progressOwner) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = CompetitionResults.fromJson(
        await widget.accounts.requestCommunity(
          action: {
            'action': 'results',
            'id': widget.eventId,
            'page': more ? results!.page + 1 : 0,
          },
        ),
      );
      if (mounted && owner == widget.accounts.progressOwner) {
        setState(() {
          results = value;
          rows = more
              ? {
                  ...{for (final row in rows) row.id: row},
                  ...{for (final row in value.rows) row.id: row},
                }.values.toList()
              : value.rows;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AccountError
              ? e.message
              : 'Не удалось загрузить результаты.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.accounts,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Результаты'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PaceBackground(
        child: owner != widget.accounts.progressOwner
            ? const Center(
                child: Text('Аккаунт изменился. Вернись в сообщество.'),
              )
            : RefreshIndicator(
                onRefresh: () => _load(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(22),
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null) ...[
                      Text(error!),
                      TextButton(
                        onPressed: () => _load(),
                        child: const Text('Повторить'),
                      ),
                    ],
                    if (results != null && !results!.available)
                      const Text(
                        'Для этого соревнования ещё не заданы условия зачёта.',
                      ),
                    if (results?.available == true) ...[
                      Text(
                        results!.rule!.title,
                        style: const TextStyle(color: lime, fontSize: 19),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'С результатом: ${results!.ranked} из ${results!.participants} участников',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Таблица учитывает синхронизированные тренировки. При равных результатах место общее.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 20),
                      if (results!.mine != null)
                        GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Твой результат',
                                style: TextStyle(color: lime),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                results!.rule!.format(
                                  results!.mine!['score'] as int,
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${CompetitionRule.workoutCount(results!.mine!['workouts'] as int)}${results!.mine!['rank'] == null ? '' : ' · место ${results!.mine!['rank']}'}',
                              ),
                              if ((results!.mine!['excluded'] as Map? ?? {})
                                  .isNotEmpty)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text('Не вошли в зачёт'),
                                  children: [
                                    for (final entry
                                        in (results!.mine!['excluded'] as Map)
                                            .entries)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          CompetitionResults.reasons[entry
                                                  .key] ??
                                              'Не соответствует правилам',
                                        ),
                                        trailing: Text('${entry.value}'),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (rows.isEmpty)
                        const GlassPanel(
                          child: Text(
                            'Подходящих тренировок пока нет. Первый результат появится после синхронизации.',
                          ),
                        ),
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassPanel(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    '${row.rank}',
                                    style: const TextStyle(
                                      color: lime,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row.name}${row.me ? ' · ты' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        results!.rule!.format(row.score),
                                        style: const TextStyle(color: lime),
                                      ),
                                      Text(
                                        CompetitionRule.workoutCount(
                                          row.workouts,
                                        ),
                                        style: const TextStyle(color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (results!.hasMore)
                        OutlinedButton(
                          onPressed: loading ? null : () => _load(more: true),
                          child: const Text('Загрузить ещё'),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    ),
  );
}
