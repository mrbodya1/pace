# HTTPS-доступ PACE через Tailscale Funnel

Статус 12 ноября 2026: публичный HTTPS включён и проверен через настоящий публичный relay. Пользователь отдельно разрешил публикацию API и подтвердил включение Funnel в своём аккаунте Tailscale. Прежний план Tuna заменён выбранным пользователем Tailscale Funnel.

## Схема

Телефон/эмулятор без Tailscale → публичный HTTPS bodya1-pc.tail3c1c24.ts.net (включён) → Tailscale Funnel на домашнем Windows → Caddy 127.0.0.1:8091 → существующий PocketBase 127.0.0.1:8090. Router/Windows Firewall/Docker/VPN не менялись.

## Разрешённые API

- GET /api/health.
- POST /api/collections/pace_users/records — регистрация, до 64 KiB.
- POST /api/collections/pace_users/auth-with-password и auth-refresh — вход/обновление сессии, до 64 KiB.
- PATCH /api/collections/pace_users/records/<15 lowercase alphanumeric ID> — свой профиль, до 64 KiB, права проверяет PocketBase.
- GET/PUT /api/pace/progress — свой прогресс, до 32 MiB, права/ревизии проверяет hook.
- OPTIONS на тех же маршрутах — CORS; произвольные query-параметры, нестандартные формы пути и другие методы запрещены.

Всё остальное возвращает 404 до PocketBase: панель /_/, установка, superusers, коллекции/настройки/backup API, batch и files. Локальная админка остаётся http://127.0.0.1:8090/_/. Caddy admin API отключён, слушатель только loopback. Журналирование тел запросов/Authorization и access log Caddy не включались.

## IP и ограничения

В официальных исходниках установленного Tailscale v1.104.5, ipn/ipnlocal/serve.go, addProxyForwardedHeaders перезаписывает X-Forwarded-For фактическим SrcAddr. Caddy доверяет только loopback-посреднику, разбирает цепочку справа налево и перезаписывает X-Real-IP/XFF каноническим client_ip. Forwarded и недостоверные аналоги удаляются. PocketBase миграцией 1794441600_gateway_trusted_proxy.js настроен доверять только X-Real-IP. Локальные процессы на самом сервере входят в доверенную границу; удалённого доступа к 8090/8091 нет. Публичная защита от поддельного XFF/X-Real-IP проверена через relay: при смене ложных IP четыре запроса за 2,04 секунды дали [400,400,429,429], то есть фактический IP не подменялся.

Существующие rate limits PocketBase сохранены: auth 2 запроса/3 сек на IP, создание 20/5 сек, общий API 300/10 сек; excludedIPs пуст. Два независимых синтетических IP через loopback дали [400,400,429] каждый, без создания аккаунтов.

## Размещение и запуск

- Проверенный официальный Caddy 2.11.9: D:/Applications/HomeServer/Caddy/bin/caddy.exe. Опубликованный checksum-файл использует SHA-512; архив сверён именно по нему.
- Конфиг и скрипты: server/gateway.
- Задачи PACE-PocketBase и PACE-API-Gateway: Limited, текущий пользователь, после входа в Windows, без пароля, с перезапуском при сбое. Существующие задачи не заменялись.
- Логи закрыты в D:/Applications/PACE/Runtime/Logs. При перезагрузке до входа пользователя запуск не гарантируется; полный reboot не выполнялся.
- Свежая закрытая копия pb_data до миграции: D:/Applications/Backups/HTTPS-2026-11-12/PocketBase-before-proxy; 3 файла/1040855 байт сверены SHA-256, оба SQLite quick_check ok. Прежняя конфигурация Serve сохранена рядом.

## Клиент

Запуск: ./run-remote.ps1 (выбрать запущенный Android-эмулятор) или ./run-web-remote.ps1. Обычный run-web.ps1 оставлен для локальной разработки. Android debug APK с публичным URL собран успешно (код 0): build/app/outputs/flutter-apk/app-debug.apk.

API URL входит в ключ аккаунта/локального прогресса и привязку токена. Перед переходом с localhost отправить очередь старого клиента через Прогресс → Обновить. При новом HTTPS URL потребуется повторный вход; старое локальное пространство не удаляется и не переносится автоматически, серверные данные аккаунта остаются теми же. Если были неотправленные тренировки, вернуться к прежнему локальному запуску и синхронизировать их перед переключением.

## Проверки и откат

server/gateway/test_gateway.py: 41 проверка настоящего Caddy против отдельного фиктивного HTTP backend, не второго PocketBase: allowlist, закрытые маршруты и обходы URL, сохранность Authorization, canonical IP, 64 KiB/32 MiB лимиты и loopback-only. Live: health 200, закрытые API 404, progress без токена 401, CORS 204, пустая регистрация 400 без аккаунта, rate limits подтверждены.

server/gateway/make-private.ps1 отключает Funnel на 443 и возвращает частный Serve через тот же защищённый шлюз, не сбрасывая другие порты. Задачи PACE остаются, админка локальная. Миграция trustedProxy не удаляет данные; исходные настройки []/false и база сохранены в закрытых копиях. Базу из копии без согласования не подменять.

Источники: https://tailscale.com/docs/features/tailscale-funnel , https://raw.githubusercontent.com/tailscale/tailscale/v1.104.5/ipn/ipnlocal/serve.go , https://caddyserver.com/docs/caddyfile/directives/bind , https://caddyserver.com/docs/caddyfile/matchers .


## Фактическое публичное включение

Пользователь явно ответил «Да, включай публичный HTTPS API PACE» на конкретный адрес и состав открываемых маршрутов. CLI потребовал включить Funnel в tailnet через страницу Tailscale; пользователь выполнил это сам и сообщил «Включил Funnel». После этого команда завершилась кодом 0: Available on the internet, proxy http://127.0.0.1:8091, AllowFunnel hostname:443=true. Прежний частный 443→8090 заменён публичным 443→8091; остальные порты/сервисы не менялись.

Внешний web-fetch инструмент не смог открыть URL (общая ошибка недоступности), поэтому он не использовался как доказательство. Публичный DNS через dns.google вернул глобальные relay IPv4 176.58.90.63/46/145. curl --resolve на relay 176.58.90.63, с --noproxy '*' и обычной проверкой TLS, принудительно исключил частный MagicDNS-маршрут. Health вернул 200; /_/, settings, backups, collections, superusers, encoded health и query обходы — 404; progress без токена — 401. Это проверка через публичный relay с домашнего ПК, а не запуск на отдельном телефоне/эмуляторе. Результаты в D:/Applications/HomeServer/Caddy/public-verification.json.

Авто-review разрешил повторную команду публикации после отдельного согласия пользователя. Auth-заголовки/пароли реальных пользователей не читались, тестовых аккаунтов не создавали. Android debug APK с публичным URL собран и проверен; результат ниже.


## Готовый Android APK

Сборка `flutter build apk --debug --no-pub --dart-define=PACE_API_URL=https://bodya1-pc.tail3c1c24.ts.net` завершилась кодом 0. Повторная инкрементальная проверка после потери вывода первой сборки: 10,6 секунды, код 0. APK: D:/Applications/PACE/Project/build/app/outputs/flutter-apk/app-debug.apk; 197773089 байт; SHA-256 `25248f14d0caa30b4091d46cf2eb9901ceaa34c7627726a3b2fe6940b4adccfd`. В kernel_blob.bin подтверждён публичный HTTPS URL, присутствуют AndroidManifest, x86_64 Flutter и все четыре v2 PNG карточек. Установка и реальный вход/синхронизация на телефоне или эмуляторе этим этапом не проверялись. Обе задачи PACE Running, Funnel направлен только на 127.0.0.1:8091.

Документация, скрипты и шлюз опубликованы вместе с UI-этапом 12 ноября 2026 в коммите d40a87b; удалённая main подтверждена после push. Приватные база, копии, runtime и APK не публиковались.
