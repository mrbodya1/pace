import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../widgets/glass_widgets.dart';

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
      'assets/images/onboarding/home-v1.png',
      'Твои тренировки. Твой прогресс.',
      'Записывай маршруты, сохраняй тренировки и следи за результатами. Вся история твоего движения — в PACE.',
      'ТРЕНИРОВКИ',
      'ЗАПИСЬ  /  ИСТОРИЯ  /  РЕЗУЛЬТАТЫ',
    ),
    _WelcomeStory(
      'assets/images/onboarding/specializations-v1.png',
      'Твой спорт имеет значение',
      'Выбери специализацию под любимый вид спорта. Она определяет бонусы к опыту и делает твой путь развития особенным.',
      'СПЕЦИАЛИЗАЦИЯ',
      'БЕГ  /  ЛЫЖИ  /  ВЕЛОСИПЕД',
    ),
    _WelcomeStory(
      'assets/images/onboarding/experience-v1.png',
      'Каждая тренировка — вклад в развитие',
      'Получай опыт, повышай уровень и открывай достижения. Превращай регулярные тренировки в последовательность личных целей.',
      'РАЗВИТИЕ',
      'ОПЫТ  /  УРОВНИ  /  ДОСТИЖЕНИЯ',
    ),
    _WelcomeStory(
      'assets/images/onboarding/community-v1.png',
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      final wide = viewport.maxWidth >= 760;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350);
      return PaceBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: duration,
                  child: _StoryArtwork(
                    key: ValueKey(page),
                    image: stories[page].image,
                  ),
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x55050510),
                        Color(0x00050510),
                        Color(0xD9050510),
                        Color(0xFF050510),
                      ],
                      stops: [0, .32, .72, 1],
                    ),
                  ),
                ),
              ),
              if (wide)
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xF5050510),
                          Color(0xB0050510),
                          Color(0x00050510),
                        ],
                        stops: [0, .42, .78],
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 48 : 24,
                            18,
                            wide ? 48 : 24,
                            0,
                          ),
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
                                          color: i <= page
                                              ? lime
                                              : Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                            horizontal: wide ? 48 : 24,
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
                            onPageChanged: (value) =>
                                setState(() => page = value),
                            itemCount: stories.length,
                            itemBuilder: (context, index) {
                              final story = stories[index];
                              return LayoutBuilder(
                                builder: (context, space) =>
                                    SingleChildScrollView(
                                      padding: EdgeInsets.fromLTRB(
                                        wide ? 52 : 28,
                                        24,
                                        wide ? 52 : 28,
                                        12,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: (space.maxHeight - 36)
                                              .clamp(0, double.infinity),
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: SizedBox(
                                            width: wide
                                                ? space.maxWidth * .46
                                                : double.infinity,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 2,
                                                      color: lime,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        story.eyebrow,
                                                        style: const TextStyle(
                                                          color: lime,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 2.2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 14),
                                                Text(
                                                  story.title,
                                                  style: TextStyle(
                                                    fontSize: wide
                                                        ? 62
                                                        : viewport.maxWidth <
                                                              360
                                                        ? 36
                                                        : 38,
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.04,
                                                    letterSpacing: -1.3,
                                                    shadows: const [
                                                      Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 24,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                                Text(
                                                  story.description,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFFD0D2DF),
                                                    height: 1.5,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 10,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                Container(
                                                  height: 1,
                                                  width: 48,
                                                  color: Colors.white24,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  story.topics,
                                                  style: const TextStyle(
                                                    color: Color(0xFF999DAD),
                                                    fontSize: 10,
                                                    height: 1.5,
                                                    letterSpacing: 1.4,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
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
                          padding: EdgeInsets.fromLTRB(
                            wide ? 52 : 28,
                            14,
                            wide ? 52 : 28,
                            24,
                          ),
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
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              busy
                                                  ? 'Подождите…'
                                                  : page == stories.length - 1
                                                  ? 'Начать'
                                                  : 'Дальше',
                                              style: const TextStyle(
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
                                  const SizedBox(height: 12),
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
                    ),
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

/// Thematic illustrations prepared for the four approved onboarding messages.
class _StoryArtwork extends StatelessWidget {
  const _StoryArtwork({super.key, required this.image});
  final String image;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, space) {
      final wide = space.maxWidth >= 760;
      final compact =
          image.contains('experience') || image.contains('community');
      final height =
          space.maxHeight *
          (wide
              ? 1.03
              : compact
              ? .54
              : .64);
      final width = height * 2 / 3;
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: wide ? 0 : space.maxHeight * .055,
            right: wide ? space.maxWidth * .025 : (space.maxWidth - width) / 2,
            width: width,
            height: height,
            child: Image.asset(
              image,
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      );
    },
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
