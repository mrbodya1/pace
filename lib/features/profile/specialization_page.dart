import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../data/storage/profile_storage_service.dart';
import '../../models/specialization.dart';
import '../../widgets/glass_lens.dart';
import '../../widgets/glass_widgets.dart';

class SpecializationPage extends StatefulWidget {
  const SpecializationPage({super.key, this.storage});
  final ProfileStorageService? storage;

  @override
  State<SpecializationPage> createState() => _SpecializationPageState();
}

class _SpecializationPageState extends State<SpecializationPage> {
  late final storage = widget.storage ?? ProfileStorageService();
  PageController? controller;
  ScrollController? carousel;
  Specialization selected = Specialization.trailrunner;
  Specialization? saved;
  bool loading = true, failed = false, saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final profile = await storage.load();
      if (!mounted) return;
      saved = Specialization.fromId(profile['specializationId']);
      selected = saved ?? Specialization.trailrunner;
      controller?.dispose();
      controller = PageController(initialPage: selected.index);
      carousel?.dispose();
      carousel = ScrollController(
        initialScrollOffset:
            (selected.index * 156.0 -
                    (MediaQuery.sizeOf(context).width - 44 - 146) / 2)
                .clamp(0.0, double.infinity),
      );
      setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    carousel?.dispose();
    super.dispose();
  }

  void _select(Specialization value) {
    if (saving) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller!.jumpToPage(value.index);
      return;
    }
    controller!.animateToPage(
      value.index,
      duration: glassMotionDuration(context),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _showAll() async {
    final value = await showModalBottomSheet<Specialization>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'Все специализации',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              for (final item in Specialization.values)
                ListTile(
                  leading: Icon(
                    item.icon,
                    color: item == selected ? lime : muted,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.bonus),
                  trailing: item == selected
                      ? const Icon(Icons.check_rounded, color: lime)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) _select(value);
  }

  void _pageChanged(int index) {
    setState(() => selected = Specialization.values[index]);
    if (carousel?.hasClients ?? false) {
      final position = carousel!.position;
      final offset = (index * 156.0 - (position.viewportDimension - 146) / 2)
          .clamp(0.0, position.maxScrollExtent);
      carousel!.animateTo(
        offset,
        duration: glassMotionDuration(context),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _save() async {
    if (saving || loading || failed || selected == saved) return;
    setState(() => saving = true);
    try {
      final profile = await storage.selectSpecialization(selected);
      if (mounted) Navigator.pop(context, profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить специализацию. Попробуй снова.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Специализация')),
        body: PaceBackground(
          child: SafeArea(
            top: false,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Не удалось загрузить специализацию'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(22, 12, 22, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Твой спортсмен',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Выбери свою сильную сторону',
                                    style: TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 280,
                              child: PageView.builder(
                                key: const ValueKey('specialization-heroes'),
                                controller: controller,
                                physics: saving
                                    ? const NeverScrollableScrollPhysics()
                                    : null,
                                itemCount: Specialization.values.length,
                                onPageChanged: _pageChanged,
                                itemBuilder: (context, index) =>
                                    ExcludeSemantics(
                                      child: Image.asset(
                                        Specialization.values[index].image,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    selected.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selected.subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: MediaQuery.textScalerOf(context)
                                  .scale(116)
                                  .clamp(116, 200),
                              child: ListView.separated(
                                key: const ValueKey('specialization-carousel'),
                                controller: carousel,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                itemCount: Specialization.values.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = Specialization.values[index];
                                  final active = item == selected;
                                  return Semantics(
                                    selected: active,
                                    button: true,
                                    label: item.title,
                                    child: AnimatedContainer(
                                      duration: glassMotionDuration(context),
                                      width: 146,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? const Color(0x303D4A27)
                                            : const Color(0xA6202433),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: active
                                              ? lime
                                              : const Color(0x506F748E),
                                          width: active ? 2 : 1,
                                        ),
                                      ),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: InkWell(
                                          key: ValueKey(
                                            'specialization-${item.name}',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          onTap: saving
                                              ? null
                                              : () => _select(item),
                                          child: ExcludeSemantics(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.asset(
                                                    item.image,
                                                    fit: BoxFit.cover,
                                                    alignment: const Alignment(
                                                      0,
                                                      -0.7,
                                                    ),
                                                  ),
                                                  const DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.transparent,
                                                          Color(0xF0080B10),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            item.icon,
                                                            color: active
                                                                ? lime
                                                                : Colors.white,
                                                            size: 22,
                                                          ),
                                                          Text(
                                                            item.title,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: active
                                                                  ? FontWeight
                                                                        .w600
                                                                  : FontWeight
                                                                        .w400,
                                                            ),
                                                          ),
                                                          if (item == saved)
                                                            const Text(
                                                              'Текущая',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: muted,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                16,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: saving ? null : _showAll,
                                icon: const Icon(
                                  Icons.grid_view_rounded,
                                  size: 20,
                                ),
                                label: const Text('Все 7 специализаций'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: GlassPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Бонус специализации',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      selected.bonus,
                                      style: const TextStyle(
                                        color: lime,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      selected.explanation,
                                      style: const TextStyle(color: muted),
                                    ),
                                    const Divider(height: 28),
                                    const Text(
                                      'Четыре составляющие XP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Wrap(
                                      spacing: 14,
                                      runSpacing: 8,
                                      children: [
                                        Text('Дистанция'),
                                        Text('Темп'),
                                        Text('Длительность'),
                                        Text('Подъём'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Бонус применяется к сумме базовых очков.',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Новая система XP готовится к запуску. Сейчас сохраняется выбор специализации.',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const ValueKey('save-specialization'),
                                onPressed: saving || selected == saved
                                    ? null
                                    : _save,
                                child: Text(
                                  saving
                                      ? 'Сохраняем…'
                                      : selected == saved
                                      ? 'Специализация выбрана'
                                      : 'Выбрать: ${selected.title}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Сейчас можно менять в любой момент',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
