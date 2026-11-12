> Аудит12ноября: оригиналы v1 перенесены в docs/design/archive/onboarding-v1 как исторические референсы. В приложение входят только четыре v2 из assets/images/onboarding. Оригиналы сохранены без изменения пикселей.

# Иллюстрации стартовых карточек PACE

Актуальная версия — прозрачные v2 и фон средствами Flutter (10 ноября 2026), см. раздел в конце. Записи v1 ниже сохраняют историю исходных иллюстраций.

9 ноября 2026. Все четыре иллюстрации созданы встроенным image_gen (не CLI), 1024×1536 PNG, непрозрачный фон. Финальные файлы находятся в D:/Applications/PACE/Project/docs/design/archive/onboarding-v1/. Исходные персонажи не изменялись.

Главный экран — сгенерированная композиция телефона по рендеру текущего PaceHome с демонстрационной фикстурой, не данные аккаунта пользователя. Сообщество — иллюстративный концепт будущего раздела; функции клубов/ивентов этим изменением не реализованы. Иллюстрация +400 XP и 4→5 показывает идею развития, а не меняет формулу XP.

Референсы: assets/images/specializations/male/runner.png, male/skier.png, female/cyclist.png. Для телефона использован outputs/welcome/home-reference.png в папке чата и созданная иллюстрация сообщества как стилевой референс.

## home-v1.png

Сохранено: D:/Applications/PACE/Project/docs/design/archive/onboarding-v1/home-v1.png

```text
Use case: product-mockup / ads-marketing. Create ONE finished portrait 2:3 onboarding background illustration for PACE sports tracking app. Input image 1 is the actual current PACE main-screen capture and is the authoritative UI layout reference; input image 2 is the finished COMMUNITY phone illustration and defines the phone materials, lighting and overall art direction. Render a premium black-glass smartphone in a slightly turned upright three-quarter pose, screen frontal enough to read, on an almost black navy #080B10 backdrop with subtle lime #C7F36B rim light. On the screen faithfully reproduce image 1's PACE main screen: small spaced PACE wordmark, large heading 'Обзор', large circular lime progress arc with 'Уровень 4', '6 840 XP', secondary '2 160 XP до уровня 5', two summary values workouts and distance, 'Последняя тренировка', and the bottom translucent tab bar with a lime circular central plus button. Preserve the screenshot's hierarchy, colors and visual layout. The square empty glyphs visible in the input capture are test-rendering artifacts: replace them with proper crisp outline icons (profile person top right, flame for workouts, location arrow for distance, home/people/plus/chart/person across bottom); never reproduce square missing-glyph boxes. Keep all Cyrillic clean and readable. No invention of a new dashboard. Phone entirely contained in upper 72 percent of tall canvas with quiet top 8 percent for story controls, lower 28 percent fades smoothly into empty dark navy for separately rendered text. Same photoreal 3D device and understated lime lighting as image 2, no extra people, no exterior marketing text, no watermark, no border.
```

## specializations-v1.png

Сохранено: D:/Applications/PACE/Project/docs/design/archive/onboarding-v1/specializations-v1.png

```text
Use case: ads-marketing. Create ONE finished portrait 2:3 raster background illustration for a full-screen PACE sports app onboarding card, photoreal premium game-character key art. Use the three provided PNGs as strict character and uniform references: male runner, male Nordic cross-country skier with skis and poles, female road cyclist with bicycle. Exactly these three athletes, one woman and two men, all equally important, standing together as a team, natural confident poses, black technical clothing with muted acid-lime details, preserve faces, equipment and physical appearance of the supplied characters. No extra people. Dark almost black blue studio backdrop #080B10, subtle lime rim light and floor haze, tasteful polished realistic lighting, no cartoon style. Group comfortably contained across upper 65 percent of the tall composition; heads below top 10 percent, full sports equipment visible as possible, lower 35 percent smoothly fades to empty dark navy for separately rendered text. NO titles, captions, buttons, interface, logos or watermarks. Consistent professional sports-product art.
```

## experience-v1.png

Сохранено: D:/Applications/PACE/Project/docs/design/archive/onboarding-v1/experience-v1.png

```text
Use case: ads-marketing / infographic. Create ONE premium polished 2:3 portrait PACE app onboarding illustration. Almost black navy #080B10 backdrop, subtle acid lime #C7F36B glow, graphite glass and brushed dark metal materials, photoreal 3D UI product visualization, clean and disciplined rather than fantasy game. Main subject in upper-middle 60 percent: a large luminous lime circular XP progress ring tilted only very slightly, clean legible exact text '+400 XP' centered inside, clear small label 'ОПЫТ'. Below the ring two elegant level chips connected with a forward arrow: '4' on the left dim graphite, '5' on the right brighter lime, small heading 'НОВЫЙ УРОВЕНЬ'. Make the 4-to-5 transition immediately clear. A few very restrained light particles imply a newly completed workout, no sports people, no phone, no trophies or invented statistics. Keep top 10 percent quiet for app controls, bottom 35 percent mostly empty dark navy fading out for separately overlaid headline and description. Exact text limited to '+400 XP', 'ОПЫТ', '4', '5', 'НОВЫЙ УРОВЕНЬ'. Crisp typography, understated premium sports UI, not cartoon, no border or watermark.
```

## community-v1.png

Сохранено: D:/Applications/PACE/Project/docs/design/archive/onboarding-v1/community-v1.png

```text
Use case: ui-mockup / ads-marketing. Create ONE high-quality portrait 2:3 onboarding background illustration for PACE, a sports tracking app. Show an elegant dark glass smartphone floating upright in slight three-quarter view, containing a beautifully typeset Russian COMMUNITY screen. Brand palette almost black navy #080B10, graphite panels #191C29, lime #C7F36B, white and muted grey type. Screen title 'Сообщество'. Three clearly differentiated sections or cards: 'Клубы' with a small group of runners and label 'Беговой клуб'; 'События' with a small trail landscape image and label 'Совместная тренировка'; 'Сообщества' with small sports avatars and label 'Люди твоего спорта'. Bottom navigation five simple clean icons including lime active people icon. Photorealistic 3D phone product render, editorial sports photography only inside the screen thumbnails, no people outside phone. Phone fills upper 65 percent of canvas, all section headings readable and comfortably inside screen, screen frontal enough to read; no oversized phone crop. Subtle lime rim glow behind phone, dark background smoothly fading to empty navy in bottom 35 percent for headline overlay. Keep top 10 percent quiet for app controls. No additional marketing headline, no footer, no watermarks, no illegible pseudo-text, no claims of live metrics.
```


## Прозрачные иллюстрации v2 — 10 ноября 2026

По просьбе пользователя фон отделён от объектов. Все четыре текущие иллюстрации подготовлены встроенным image_gen в режиме редактирования/background-extraction, transparent_background=true, не CLI/API. Применён навык imagegen. Объекты проверены в итоговом Flutter-рендере на тёмном фоне; дополнительно тест декодирует реальные пиксели PNG и проверяет прозрачные углы/фон и наличие видимого объекта.

Сохранённые файлы (RGBA PNG):

| Файл в D:/Applications/PACE/Project/assets/images/onboarding/ | Размер |
| --- | --- |
| home-v2.png | 1024×1536 |
| specializations-v2.png | 1312×1199 |
| experience-v2.png | 1099×1431 |
| community-v2.png | 1024×1536 |

Исходные v1 не перезаписаны. В pubspec.yaml теперь перечислены только четыре v2 вместо всего каталога onboarding: старые исходники остаются в репозитории, но не дублируются в пакете приложения. Персонажи/телефоны/кольцо XP остаются предметными иллюстрациями; вокруг них прозрачность, свет на самих объектах сохранён.

WelcomeStories рисует общий фон кодом: тёмный LinearGradient и мягкий лаймовый RadialGradient на весь экран. Иллюстрация теперь принадлежит содержимому страницы PageView вместе с текстом. На узких экранах она стоит над текстом; при ширине от 760 — справа от текста. BoxFit.contain сохраняет целые устройства, головы, лыжи/колёса и переход 4→5. Убрано прежнее наложение заголовков на экран телефона/уровни и затемнение иллюстраций полноэкранными масками. При нехватке высоты/увеличенном шрифте содержимое прокручивается; кнопки и прогресс остаются доступны. Тексты, порядок четырёх карточек, пропуск, завершение и вход не менялись. Сообщество остаётся концептом будущих функций, +400 и 4→5 — иллюстрация, не обещание награды.

Проверка: 8 PNG-снимков настоящего Flutter-рендера (4 страницы при 390×844 и 1200×800) просмотрены. Это не проверка на телефоне и не браузерная проверка. Тестовый снимок заранее загружает картинки через precacheImage: pumpAndSettle сам по себе не гарантирует завершения асинхронного декодирования asset перед захватом.

### Точные промпты v2

Для home-v2 (единственный референс/edit target: home-v1.png):

```text
Use case: background-extraction. Image 1 is the edit target: existing PACE onboarding phone illustration. Extract ONLY the entire smartphone as a clean isolated cutout on a genuinely transparent alpha background. Preserve the phone silhouette, angle, black metal/glass materials, exact screen UI, all Cyrillic text, icons and colors unchanged. Do not redesign or rewrite the screen. Remove the entire surrounding navy studio background, floor, reflections on floor, haze, exterior glow and excess empty lower canvas. Keep subtle lime rim lighting ON the device itself. Keep the phone fully visible, no cropped corners, with a small transparent margin on all sides, phone occupying most of the output height. No floor, no opaque rectangle, no baked checkerboard, no added text, no watermark. Output is a transparent PNG foreground asset for a responsive Flutter story, whose navy gradient and glow will be drawn in code.
```

Для остальных трёх: один соответствующий v1 — единственный edit target. Полный промпт состоит из общего начала, указанной ниже спецификации и общего окончания.

Общее начало:

```text
Use case: background-extraction. Image 1 is the sole edit target: an approved PACE onboarding illustration.
```

specializations-v2:

```text
Extract the complete group of EXACTLY THREE athletes: male Nordic skier with both skis and poles, male runner, female cyclist with complete bicycle. Preserve each face, pose, clothes, equipment and black/lime palette exactly. Remove ALL backdrop, floor and reflections between and below them, including transparent holes around poles, bicycle frame and wheels. Do not cut off heads, shoes, skis or wheels. Group tightly framed with small transparent margins, no large empty lower area.
```

experience-v2:

```text
Extract the whole existing graphic: lime metal XP ring, its original dark inset disc, exact '+400 XP' and 'ОПЫТ' lettering, 'НОВЫЙ УРОВЕНЬ', the original level chips 4 and 5 and connecting arrow. Preserve typography, spacing, colors, shapes and materials. Keep the dark disc INSIDE the ring because it is part of the object; remove the full backdrop outside the artwork. Letters below the ring must remain crisp separated foreground elements, with true transparency in the gaps. Tightly frame all artwork with small transparent margins.
```

community-v2:

```text
Extract ONLY the entire smartphone. Preserve exact phone angle, silhouette, screen layout, photos, icons and all existing Cyrillic text unchanged. Remove ALL exterior navy background, floor, reflections and outside glow. Keep the whole phone, no cropped corners, tightly framed with small transparent margins.
```

Общее окончание:

```text
Produce a genuinely transparent alpha PNG foreground cutout to composite over a Flutter-coded navy gradient. No opaque or semi-opaque background plane, no checkerboard painted into pixels, no studio haze, no background lighting, no floor shadow, no exterior marketing text or watermark. Keep soft antialiased edges and lime rim lighting only ON the objects. This is extraction, not a redesign. The app will add any atmospheric glow separately in code.
```

Новый onboarding_visual_test.dart проверяет альфа-канал всех четырёх файлов, полноэкранный фон, перелистывание/завершение при 390×844, 1200×800 и 320×640 с двойным шрифтом. Финальные 10 тестов (4 новых + 6 startup_flow_test) прошли с кодом 0, в том числе без preview-переменной и системного шрифта. git diff --check чистый. Анализ двух затронутых Dart-файлов вне ограниченной среды завершился без диагностик, код 0; подробности запуска в PACE-CONTEXT.md. Android APK с этой версией карточек пока не пересобирался; предыдущая успешная native-сборка относится к этапу исправления Kotlin.
