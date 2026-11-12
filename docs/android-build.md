# Android: сборка на Windows с проектом и Pub-кэшем на разных дисках

10 ноября 2026 сборка остановилась на :package_info_plus:compileDebugKotlin и :shared_preferences_android:compileDebugKotlin. Диагностика: Could not close incremental caches; this and base files have different roots. Исходники плагинов в Pub-кэше на C:, проект android на D:.

## Исправление

В android/gradle.properties добавлено kotlin.incremental=false с поясняющим комментарием. Это отключает инкрементальную компиляцию Kotlin/JVM, проблемный кэш которой пытался вычислить относительные пути между разными дисками Windows. Версии Flutter, Gradle, Kotlin и зависимостей не менялись. Dart-код, данные профиля, тренировки и сервер не затрагиваются.

Настройка официально поддерживается Kotlin: https://kotlinlang.org/docs/gradle-compilation-and-caches.html#incremental-compilation . Повторная компиляция изменившегося Kotlin-кода может занимать больше времени. Это не отключает Flutter hot reload; Gradle по-прежнему может пропускать неизменённые задачи.

Перед проверкой остановлен старый Gradle daemon. Для очистки повреждённых выходных файлов выбраны только задачи :package_info_plus:clean и :shared_preferences_android:clean; весь пользовательский Pub/Gradle-кэш не удалялся. Затем выполнена :app:assembleDebug. Если такая ошибка возникнет снова после возврата инкрементального режима, сначала проверьте размещение проекта и Pub-кэша на одном диске.

## Проверка

Проверочная среда: Windows, Flutter 3.47.9; AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1; Java из установленного Android Studio (JBR 25.0.4). Две попытки из ограниченной среды остановились до Kotlin-задач из-за недоступности каталога Gradle-плагина Flutter; итоговая проверка выполнена вне ограниченной среды. Это отдельное ограничение запуска помощника, не исходная ошибка пользователя.

Итог: BUILD SUCCESSFUL in 5m 48s, ANDROID_BUILD_EXIT=0. Обе проблемные задачи compileDebugKotlin выполнены успешно. Собран debug APK: build/app/outputs/flutter-apk/app-debug.apk (также outputs/apk/debug), 175281909 байт. Проверено содержимое ZIP: AndroidManifest.xml, DEX, flutter_assets и lib/x86_64/libflutter.so для Android-эмулятора присутствуют; SHA-256 обеих копий совпадает: 85ddcb76da9f3458d2e6307ea95f5c96095c2b39ae9c239d7476a28240a351ee. Это подтверждённая native Android debug-сборка; установка и запуск на устройстве/эмуляторе не выполнялись.

Gradle автоматически установил недостающий CMake 3.22.1 в Android SDK с уже принятой лицензией. Создаваемый Kotlin каталог android/.kotlin/ добавлен в android/.gitignore, чтобы локальные журналы и сессии компилятора не попадали в Git. Предупреждения об устаревших флагах Flutter/AGP и XML SDK остаются; они не остановили сборку. Миграция на новые DSL/встроенный Kotlin этим исправлением не выполнялась.

Для повторного запуска из корня проекта: flutter run. Полный повтор Dart-тестов не выполнялся: Dart-код не менялся, исправление проверено Android-сборкой. git diff --check прошёл. Исправление включено в сохраняемый этап вместе с обновлёнными стартовыми карточками; этот APK собран до изменения карточек.


## Ошибка терминала Android Studio — 12 ноября 2026

Пользователь прислал стек Attempt to take read lock was prevented / Dispatchers.UI. Цепочка TerminalCommandCompletionTypingListener → syncEditorCaretWithModel → ClangPPMatchingHighlighter относится к встроенному терминалу/подсветке IntelliJ Platform, а не к Flutter-коду приложения или компиляции Gradle. В установленном product-info.json указана AndroidStudio2026.2.2, build AI-262.10968.63.2622.16840690. Точного подтверждённого upstream-тикета для этого стека не найдено; диагностика основана на самом стеке. Признаков ошибки путей после переноса в этом сообщении нет, но одна трассировка не доказывает отсутствие любых других проблем.

Предложен обратимый обход: Settings (Ctrl+Alt+S) → Tools → Terminal → Terminal engine → Classic, Apply/OK, затем закрыть старые вкладки терминала и открыть новую. При необходимости перезапустить IDE. Наличие Classic и способ переключения подтверждены официальной документацией https://www.jetbrains.com/help/idea/settings-tools-terminal.html . Настройка ещё не применялась помощником, исчезновение ошибки не проверено. Предложения про Dispatchers.UI/EDT в исключении предназначены разработчикам IDE/плагинов, не требуют изменений кода PACE.
