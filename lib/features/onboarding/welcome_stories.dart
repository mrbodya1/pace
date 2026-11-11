import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';

class WelcomeStories extends StatefulWidget {
  const WelcomeStories({super.key, required this.onComplete});
  final Future<void> Function() onComplete;
  @override
  State<WelcomeStories> createState() => _WelcomeStoriesState();
}

class _WelcomeStoriesState extends State<WelcomeStories> {
  final controller = PageController();
  int page = 0;
  bool busy = false;
  static const stories = [
    _WelcomeStory(
      'assets/images/onboarding/home-v2.png',
      'Твои тренировки. Твой прогресс.',
      'Записывай маршруты, сохраняй тренировки и следи за результатами. Вся история твоего движения — в PACE.',
      'ТРЕНИРОВКИ',
      'ЗАПИСЬ  /  ИСТОРИЯ  /  РЕЗУЛЬТАТЫ',
    ),
    _WelcomeStory(
      'assets/images/onboarding/specializations-v2.png',
      'Твой спорт имеет значение',
      'Выбери специализацию под любимый вид спорта. Она определяет бонусы к опыту и делает твой путь развития особенным.',
      'СПЕЦИАЛИЗАЦИЯ',
      'БЕГ  /  ЛЫЖИ  /  ВЕЛОСИПЕД',
    ),
    _WelcomeStory(
      'assets/images/onboarding/experience-v2.png',
      'Каждая тренировка — вклад в развитие',
      'Получай опыт, повышай уровень и открывай достижения. Превращай регулярные тренировки в последовательность личных целей.',
      'РАЗВИТИЕ',
      'ОПЫТ  /  УРОВНИ  /  ДОСТИЖЕНИЯ',
    ),
    _WelcomeStory(
      'assets/images/onboarding/community-v2.png',
      'Двигаться интереснее вместе',
      'Находи сообщество по интересам, вступай в клубы и участвуй в событиях. Ставьте общие цели и поддерживайте друг друга на пути к ним.',
      'СООБЩЕСТВО',
      'КЛУБЫ  /  СОБЫТИЯ  /  ОБЩИЕ ЦЕЛИ',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось продолжить. Попробуй снова.'),
          ),
        );
      }
    }
  }

  void _next() {
    if (page == stories.length - 1) {
      _finish();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(page + 1);
    } else {
      controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => _StoryBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: LayoutBuilder(
              builder: (context, viewport) {
                final wide = viewport.maxWidth >= 760;
                final inset = wide ? 48.0 : 24.0;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 18, inset, 0),
                      child: Row(
                        children: [
                          for (var i = 0; i < stories.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Semantics(
                                  label:
                                      'История ${i + 1} из ${stories.length}',
                                  selected: i == page,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: i <= page ? lime : Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: inset,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 20,
                          children: [
                            const Text(
                              'PACE',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            TextButton(
                              onPressed: busy ? null : _finish,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              child: const Text('Пропустить'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('welcome-stories'),
                        controller: controller,
                        physics: busy
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (value) => setState(() => page = value),
                        itemCount: stories.length,
                        itemBuilder: (context, index) => LayoutBuilder(
                          builder: (context, space) {
                            final story = stories[index];
                            final artHeight = wide
                                ? (space.maxHeight - 24).clamp(300.0, 680.0)
                                : (space.maxHeight * .50).clamp(180.0, 360.0);
                            final art = SizedBox(
                              height: artHeight,
                              child: _StoryArtwork(image: story.image),
                            );
                            final copy = _StoryCopy(
                              story: story,
                              titleSize: wide
                                  ? 54
                                  : viewport.maxWidth < 360
                                  ? 28
                                  : 34,
                            );
                            return SingleChildScrollView(
                              key: PageStorageKey('welcome-copy-$index'),
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                12,
                                inset,
                                12,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: (space.maxHeight - 24).clamp(
                                    0,
                                    double.infinity,
                                  ),
                                ),
                                child: wide
                                    ? IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            Expanded(flex: 5, child: copy),
                                            const SizedBox(width: 36),
                                            Expanded(flex: 6, child: art),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          art,
                                          const SizedBox(height: 20),
                                          copy,
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 14, inset, 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: wide ? 360 : double.infinity,
                          child: Column(
                            children: [
                              FilledButton(
                                onPressed: busy ? null : _next,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: lime,
                                  foregroundColor: const Color(0xFF101207),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          busy
                                              ? 'Подождите…'
                                              : page == stories.length - 1
                                              ? 'Начать'
                                              : 'Дальше',
                                          style: const TextStyle(
                                            color: Color(0xFF101207),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!busy) ...[
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${page + 1} / ${stories.length}',
                                style: const TextStyle(
                                  color: Color(0xFF989AAA),
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _StoryCopy extends StatelessWidget {
  const _StoryCopy({required this.story, required this.titleSize});
  final _WelcomeStory story;
  final double titleSize;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(width: 24, height: 2, color: lime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              story.eyebrow,
              style: const TextStyle(
                color: lime,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        story.title,
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w700,
          height: 1.08,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        story.description,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFFD0D2DF),
          height: 1.5,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        story.topics,
        style: const TextStyle(
          color: Color(0xFF999DAD),
          fontSize: 11,
          height: 1.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

/// One continuous background, independent of illustration dimensions and alpha.
class _StoryBackground extends StatelessWidget {
  const _StoryBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('welcome-background'),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B1220), Color(0xFF080B13), Color(0xFF100F21)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.7, -.45),
                radius: 1.1,
                colors: [Color(0x1FCBF76D), Color(0x00080B13)],
                stops: [0, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

/// Transparent foregrounds are fitted without cropping athletes or devices.
class _StoryArtwork extends StatelessWidget {
  const _StoryArtwork({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Image.asset(
      image,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.high,
    ),
  );
}

class _WelcomeStory {
  const _WelcomeStory(
    this.image,
    this.title,
    this.description,
    this.eyebrow,
    this.topics,
  );
  final String image, title, description, eyebrow, topics;
}
