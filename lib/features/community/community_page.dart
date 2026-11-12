import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/community.dart';
import '../../models/sport_catalog.dart';
import '../../models/xp_progress.dart';
import '../../services/account_service.dart';
import '../../widgets/glass_tabs.dart';
import '../../widgets/glass_widgets.dart';
import 'competition_rules_form.dart';
import 'competition_results_page.dart';

const _sports = [
  'Все виды',
  'Бег',
  'Ходьба',
  'Велосипед',
  'Лыжи',
  'Трейл',
  'Роллеры',
  'Плавание',
];

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.accounts, this.active = true});
  final AccountService? accounts;
  final bool active;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  AccountService get accounts => widget.accounts ?? AccountService.instance;
  CommunityFeed? feed;
  List<CommunityItem> clubs = [], events = [];
  String? error;
  bool loading = false, mine = false;
  String search = '';
  Timer? searchDelay;
  final searchInput = TextEditingController();
  int generation = 0;
  String? owner;

  @override
  void initState() {
    super.initState();
    owner = accounts.progressOwner;
    accounts.addListener(_accountChanged);
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CommunityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accounts != widget.accounts) {
      (oldWidget.accounts ?? AccountService.instance).removeListener(
        _accountChanged,
      );
      accounts.addListener(_accountChanged);
      _accountChanged();
    }
    if (widget.active && !oldWidget.active) unawaited(_load());
  }

  void _accountChanged() {
    if (owner == accounts.progressOwner) return;
    generation++;
    setState(() {
      owner = accounts.progressOwner;
      feed = null;
      clubs = [];
      events = [];
      error = null;
      loading = false;
      search = '';
      mine = false;
    });
    searchDelay?.cancel();
    searchInput.clear();
    if (widget.active) unawaited(_load());
  }

  @override
  void dispose() {
    generation++;
    searchDelay?.cancel();
    searchInput.dispose();
    accounts.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if ((loading && more) || !accounts.hasSession) return;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await accounts.requestCommunity(
        action: more || search.isNotEmpty || mine
            ? {
                'action': 'list',
                'page': more ? feed!.page + 1 : 0,
                'search': search,
                'mine': mine,
              }
            : null,
      );
      final next = CommunityFeed.fromJson(response);
      if (!mounted || request != generation) return;
      setState(() {
        feed = next;
        clubs = more ? _merge(clubs, next.clubs) : next.clubs;
        events = more ? _merge(events, next.events) : next.events;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(
          () => error = e is AccountError
              ? e.message
              : 'Не удалось загрузить сообщество. Повтори попытку.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  List<CommunityItem> _merge(
    List<CommunityItem> old,
    List<CommunityItem> next,
  ) => {
    ...{for (final item in old) item.id: item},
    ...{for (final item in next) item.id: item},
  }.values.toList();

  Future<void> _create(String kind) async {
    final result = await Navigator.of(context).push<CommunityItem>(
      MaterialPageRoute(
        builder: (_) => _CreatePage(
          accounts: accounts,
          kind: kind,
          ownedClubs: feed!.ownedClubs,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _load();
    if (mounted) await _details(result);
  }

  Future<void> _details(CommunityItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _DetailPage(accounts: accounts, item: item, xp: feed!.xp),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 12, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Сообщество',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.8,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: loading ? null : () => _load(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: GlassTabs(labels: ['Клубы', 'Соревнования', 'Мероприятия']),
        ),
        Expanded(
          child: !accounts.hasSession
              ? const Center(
                  child: Text(
                    'Войди в аккаунт PACE, чтобы открыть сообщество.',
                  ),
                )
              : feed == null
              ? _initialState()
              : TabBarView(
                  children: [
                    _list('club'),
                    _list('competition'),
                    _list('event'),
                  ],
                ),
        ),
      ],
    ),
  );
  Widget _initialState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error ?? 'Сообщество ещё не загружено',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _load(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
    ),
  );

  Widget _list(String kind) {
    final isClub = kind == 'club';
    final data = (isClub ? clubs : events.where((e) => e.kind == kind))
        .where(
          (item) =>
              (!mine || item.joined || item.owner) &&
              '${item.name} ${item.city} ${item.sport}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    final canCreate = isClub ? feed!.xp >= 65000 : feed!.ownedClubs.isNotEmpty;
    final creationHint = isClub
        ? 'Создание клуба — с уровня 10. Осталось ${65000 - feed!.xp} XP.'
        : 'События создаёт владелец клуба. Свой клуб можно создать с уровня 10.';
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 140),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            isClub
                ? 'Найди свою команду'
                : kind == 'competition'
                ? 'Следующая цель — вместе'
                : 'Встречаемся на тренировке',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isClub
                ? 'Вступление с уровня 5 · создание с уровня 10'
                : kind == 'competition'
                ? 'Открытые старты с уровня 2 · клубные с уровня 5'
                : 'Клубные встречи и совместные тренировки',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уровень ${XpProgress(feed!.xp).level} · ${feed!.xp} XP',
                  style: const TextStyle(
                    color: lime,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canCreate && !loading
                        ? () => _create(kind)
                        : null,
                    icon: Icon(
                      canCreate ? Icons.add : Icons.lock_outline_rounded,
                    ),
                    label: Text(
                      isClub
                          ? 'Создать клуб'
                          : kind == 'competition'
                          ? 'Создать соревнование'
                          : 'Создать мероприятие',
                    ),
                  ),
                ),
                if (!canCreate) ...[
                  const SizedBox(height: 10),
                  Text(creationHint, style: const TextStyle(color: muted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey('search-$kind'),
            controller: searchInput,
            maxLength: 80,
            onChanged: (value) {
              // Invalidate the old query immediately, before the debounce fires.
              generation++;
              setState(() {
                search = value;
                loading = true;
                error = null;
              });
              searchDelay?.cancel();
              searchDelay = Timer(
                const Duration(milliseconds: 400),
                () => _load(),
              );
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Название, город или вид спорта',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: !mine,
                selectedColor: lime.withValues(alpha: .18),
                checkmarkColor: lime,
                labelStyle: TextStyle(color: !mine ? lime : muted),
                onSelected: (_) {
                  searchDelay?.cancel();
                  setState(() => mine = false);
                  unawaited(_load());
                },
              ),
              ChoiceChip(
                label: Text(isClub ? 'Мои клубы' : 'Я участвую'),
                selected: mine,
                selectedColor: lime.withValues(alpha: .18),
                checkmarkColor: lime,
                labelStyle: TextStyle(color: mine ? lime : muted),
                onSelected: (_) {
                  searchDelay?.cancel();
                  setState(() => mine = true);
                  unawaited(_load());
                },
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Повторить загрузку'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (data.isEmpty && !loading)
            GlassPanel(
              child: Column(
                children: [
                  Icon(
                    isClub
                        ? Icons.groups_rounded
                        : kind == 'competition'
                        ? Icons.emoji_events_outlined
                        : Icons.event_outlined,
                    size: 44,
                    color: lime,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    search.isNotEmpty
                        ? 'Ничего не найдено'
                        : mine
                        ? 'Пока нет участия'
                        : isClub
                        ? 'Клубов пока нет'
                        : 'Событий пока нет',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mine
                        ? 'Выбери клуб или событие во вкладке «Все».'
                        : search.isNotEmpty
                        ? 'Попробуй другой запрос.'
                        : 'Здесь появятся реальные клубы и события участников PACE.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          for (final item in data)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ItemCard(
                item: item,
                xp: feed!.xp,
                onTap: () => _details(item),
              ),
            ),
          if (feed!.hasMore)
            OutlinedButton(
              onPressed: loading ? null : () => _load(more: true),
              child: const Text('Загрузить ещё'),
            ),
        ],
      ),
    );
  }
}

IconData _sportIcon(String sport) {
  final index = SportCatalog.names.indexOf(sport);
  return index < 0 ? Icons.bolt_rounded : SportCatalog.icons[index];
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.xp, required this.onTap});
  final CommunityItem item;
  final int xp;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lime.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_sportIcon(item.sport), color: lime),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              [item.sport, if (item.city.isNotEmpty) item.city].join(' · '),
              style: const TextStyle(color: muted),
            ),
            if (item.startsAt != null)
              Text(_date(item.startsAt!), style: const TextStyle(color: lime)),
            const SizedBox(height: 8),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              '${item.members} участников${item.owner
                  ? (item.isClub ? ' · Твой клуб' : ' · Ты организатор')
                  : item.joined
                  ? ' · Ты участвуешь'
                  : ''}',
              style: const TextStyle(color: muted),
            ),
            if (!item.joined && !item.owner) ...[
              const SizedBox(height: 6),
              Text(
                item.joinRestriction(xp, DateTime.now()) ??
                    (item.audience == 'club'
                        ? 'Для участников клуба'
                        : 'Открыто для вступления'),
                style: const TextStyle(color: lime),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DetailPage extends StatefulWidget {
  const _DetailPage({
    required this.accounts,
    required this.item,
    required this.xp,
  });
  final AccountService accounts;
  final CommunityItem item;
  final int xp;
  @override
  State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> {
  late CommunityItem item = widget.item;
  late final String? owner = widget.accounts.progressOwner;
  bool busy = false;
  String? error;
  Future<void> _act() async {
    if (item.joined) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.isClub ? 'Покинуть клуб?' : 'Отменить участие?'),
          content: Text(item.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.accounts.requestCommunity(
        action: {
          'action': item.joined ? 'leave' : 'join',
          'targetKind': item.isClub ? 'club' : 'event',
          'id': item.id,
        },
      );
      if (mounted) setState(() => item = CommunityItem.fromJson(result));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AccountError
              ? e.message
              : 'Не удалось выполнить действие.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.accounts,
    builder: (context, _) {
      final changed = owner != widget.accounts.progressOwner;
      final restriction = item.joinRestriction(widget.xp, DateTime.now());
      return Scaffold(
        appBar: AppBar(
          title: Text(
            item.isClub
                ? 'Клуб'
                : item.kind == 'competition'
                ? 'Соревнование'
                : 'Мероприятие',
          ),
        ),
        body: PaceBackground(
          child: changed
              ? const Center(
                  child: Text('Аккаунт изменился. Вернись в сообщество.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        _sportIcon(item.sport),
                        size: 60,
                        color: lime,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        item.sport,
                        if (item.city.isNotEmpty) item.city,
                      ].join(' · '),
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.clubName != null) ...[
                            Text(
                              'Клуб «${item.clubName}»',
                              style: const TextStyle(color: lime),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(item.description),
                          const SizedBox(height: 18),
                          if (item.startsAt != null)
                            Text('Начало: ${_date(item.startsAt!)}'),
                          if (item.endsAt != null)
                            Text('Окончание: ${_date(item.endsAt!)}'),
                          const SizedBox(height: 12),
                          Text(
                            '${item.members} участников',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (item.scoring != null) ...[
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.scoring!.title,
                              style: const TextStyle(
                                color: lime,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            for (final condition in item.scoring!.conditions)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(condition),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CompetitionResultsPage(
                              accounts: widget.accounts,
                              eventId: item.id,
                              title: item.name,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.leaderboard_outlined),
                        label: const Text('Таблица результатов'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'После вступления твоё имя, результат и число зачтённых тренировок будут видны в таблице. Маршрут и пульс не публикуются.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      item.isClub
                          ? 'Открытый клуб · вступление с уровня 5'
                          : item.audience == 'club'
                          ? 'Для участников клуба с уровня 5'
                          : 'Открытое соревнование · участие с уровня 2',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 14),
                    if (item.owner && item.isClub)
                      const Text(
                        'Ты — владелец клуба',
                        style: TextStyle(color: lime),
                      )
                    else if (item.joined)
                      OutlinedButton(
                        onPressed: busy ? null : _act,
                        child: Text(
                          item.isClub ? 'Покинуть клуб' : 'Отменить участие',
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: busy || restriction != null ? null : _act,
                        child: Text(
                          item.isClub ? 'Вступить в клуб' : 'Участвовать',
                        ),
                      ),
                    if (!item.joined && restriction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          restriction,
                          style: const TextStyle(color: lime),
                        ),
                      ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      );
    },
  );
}

class _CreatePage extends StatefulWidget {
  const _CreatePage({
    required this.accounts,
    required this.kind,
    required this.ownedClubs,
  });
  final AccountService accounts;
  final String kind;
  final List<Map<String, dynamic>> ownedClubs;
  @override
  State<_CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<_CreatePage> {
  final form = GlobalKey<FormState>();
  final scoring = CompetitionRuleDraft();
  final name = TextEditingController(),
      description = TextEditingController(),
      city = TextEditingController();
  late final String? owner = widget.accounts.progressOwner;
  late String? clubId = widget.ownedClubs.firstOrNull?['id'] as String?;
  String sport = 'Бег', audience = 'open';
  DateTime? start, end;
  String? error;
  bool busy = false;
  bool get isClub => widget.kind == 'club';
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    city.dispose();
    scoring.dispose();
    super.dispose();
  }

  Future<void> _pick(bool first) async {
    final now = DateTime.now();
    final initial =
        (first ? start : end) ??
        (first
            ? now.add(const Duration(days: 1))
            : (start ?? now).add(const Duration(hours: 2)));
    final day = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (first) {
        start = value;
      } else {
        end = value;
      }
    });
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (widget.kind == 'competition' && scoring.paceError != null) {
      setState(() => error = scoring.paceError);
      return;
    }
    if (!isClub &&
        (start == null ||
            end == null ||
            !start!.isAfter(DateTime.now()) ||
            !end!.isAfter(start!))) {
      setState(
        () => error = 'Выбери начало в будущем и окончание после начала.',
      );
      return;
    }
    if (owner != widget.accounts.progressOwner) {
      setState(() => error = 'Аккаунт изменился. Открой форму заново.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.accounts.requestCommunity(
        action: {
          'action': isClub ? 'createClub' : 'createEvent',
          'name': name.text.trim(),
          'description': description.text.trim(),
          'city': city.text.trim(),
          'sport': sport,
          if (!isClub) ...{
            'kind': widget.kind,
            'clubId': clubId,
            'audience': widget.kind == 'event' ? 'club' : audience,
            'startsAt': start!.toUtc().toIso8601String(),
            'endsAt': end!.toUtc().toIso8601String(),
            if (widget.kind == 'competition') 'scoring': scoring.toJson(),
          },
        },
      );
      if (mounted) Navigator.pop(context, CommunityItem.fromJson(result));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AccountError
              ? e.message
              : 'Не удалось сохранить. Повтори попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        isClub
            ? 'Новый клуб'
            : widget.kind == 'competition'
            ? 'Новое соревнование'
            : 'Новое мероприятие',
      ),
    ),
    body: PaceBackground(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              isClub ? 'Собери свою команду' : 'Пригласи участников на старт',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              enabled: !busy,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введи название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: description,
              enabled: !busy,
              minLines: 3,
              maxLines: 8,
              maxLength: 1500,
              decoration: InputDecoration(
                labelText: isClub ? 'О клубе' : 'Описание и место встречи',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Добавь описание' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: city,
              enabled: !busy,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Город (необязательно)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sport,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Вид спорта'),
              items: [
                for (final s in _sports)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: busy ? null : (v) => setState(() => sport = v!),
            ),
            if (!isClub) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: clubId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'От клуба'),
                items: [
                  for (final club in widget.ownedClubs)
                    DropdownMenuItem(
                      value: club['id'] as String,
                      child: Text(
                        club['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => clubId = v),
              ),
              if (widget.kind == 'competition') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Кто участвует'),
                  items: const [
                    DropdownMenuItem(
                      value: 'open',
                      child: Text('Все участники с уровня 2'),
                    ),
                    DropdownMenuItem(
                      value: 'club',
                      child: Text('Участники клуба с уровня 5'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => audience = v!),
                ),
                const SizedBox(height: 20),
                CompetitionRulesForm(draft: scoring, enabled: !busy),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Мероприятие для участников клуба с уровня 5.',
                    style: TextStyle(color: muted),
                  ),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _pick(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(start == null ? 'Выбрать начало' : _date(start!)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _pick(false),
                icon: const Icon(Icons.event_available_outlined),
                label: Text(end == null ? 'Выбрать окончание' : _date(end!)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Время указано в часовом поясе твоего устройства.',
                style: TextStyle(color: muted),
              ),
            ],
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : _save,
              child: Text(
                busy
                    ? 'Сохраняем…'
                    : isClub
                    ? 'Создать клуб'
                    : 'Опубликовать',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
