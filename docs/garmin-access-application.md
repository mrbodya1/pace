# Garmin — текст заявки PACE

Статус: пользователь отложил Business-заявку до готовности приложения. Черновики ниже сохранены на будущее; текущий этап — Personal API для собственного аккаунта, см. garmin-integration-plan.md.

Подготовлено12ноября2026. Черновик для пользователя; не отправлен, доступ/условия/интеграция не оформлялись. После четырёх новых скриншотов подтверждены фактические поля заявки; ответы по полям ниже.

## Основной текст на английском

PACE is an independently developed multisport training application built with Flutter and currently in active development. It helps recreational athletes record and review workouts, track their progress, and earn sport-specific achievements. Supported sports include running, trail running, walking, cycling, skiing, and swimming. Club and event features are planned for a later development stage.

We are requesting Starter Access to the Garmin Connect Developer Program, primarily the Activity API, to allow users to connect their Garmin accounts and import their recorded workouts into PACE with their consent.

The requested activity data includes sport type, timestamps, distance, duration, elevation, GPS tracks, and time-stamped heart rate measurements when recorded and available. We would use activity summaries and FIT files to display workout details and support progress tracking. A planned use case is automatic eligibility checks for specific sporting events that require recorded heart rate data.

The planned integration will use Garmin OAuth 2.0 authorization and a secure HTTPS backend. Users will not provide their Garmin passwords to PACE. We will implement access revocation and duplicate-activity handling, and request only the data needed for these features.

Please advise on the Starter Access application requirements, applicable commercial terms, and availability of detailed activity and heart rate data through the Activity API.

## Краткое описание, если поле небольшое

PACE is a multisport training app in active development. We request Garmin Activity API access to import user-authorized workouts, including GPS and recorded heart rate time series, for workout history, progress tracking, and planned club events. We plan OAuth 2.0 authorization and server-side processing over HTTPS.

## Поля и сведения

- Project/application name: PACE.
- Requested API: Activity API.
- Stage: In development / prototype (выбирать ближайший правдивый пункт).
- Project repository, если подходит поле URL: https://github.com/mrbodya1/pace . Не выдавать GitHub-репозиторий или API health за готовый продуктовый сайт либо политику конфиденциальности.
- Contact name/email/country/legal entity: пользователь указывает фактические сведения, не выводить их из имени компьютера или Git-автора.
- Company: не придумывать юрлицо; если форма требует зарегистрированную организацию и не предлагает подходящего типа, уточнить условия у Garmin.
- Privacy policy: готовая публичная политика пока не подтверждена. Если обязательна — сначала подготовить и опубликовать, не подставлять чужой документ или несуществующий URL.
- User count/launch date: указать реальные данные/план после согласования, не выдумывать.

Планируемые гарантии OAuth/отзыва/дедупликации обозначены как будущие, а не уже внедрённые. Фактическое сопоставление типов спорта Garmin с каталогом PACE нужно проверить по API.

## Где вводить

На первом скриншоте кнопка Request Now — начало заявки. Меню API на втором скриншоте только навигация по документации. Поля видны на новых скриншотах; Company Name ограничено100символами. Другие лимиты текста и варианты dropdown пока не видны.


## Ответы по фактическим полям формы

### Provide a brief overview of your application, the user experience and how the APIs will be used

PACE is an independently developed multisport fitness app, currently in active development. Users can record and review workouts, track progress, and earn sport-specific achievements. Club and sporting event features are planned.

We request the Activity API so users can connect Garmin through OAuth 2.0 and import their recorded activities with consent. We need activity summaries and FIT files containing sport type, time, distance, duration, elevation, GPS tracks, and time-stamped heart rate when available. These data will support workout history and progress tracking, with future eligibility checks for events requiring recorded heart rate. Import processing and duplicate-activity handling will run on our HTTPS backend.

### Describe the business model for the products or services using this API access

PACE is an early-stage, independently developed consumer fitness application. The business model is still being evaluated. Our initial focus is product development and testing with a small group of users. We are requesting API access to build and validate the Garmin integration before finalizing the commercial launch plan.

Примечание: конкретная подписка/реклама/платные клубы не утверждены пользователем, поэтому не выдумывались. До отправки пользователь должен подтвердить фактический план бизнеса и тестирования.

### Identify each contractor, hosting provider, technology vendor, or other third-party service that will process, analyze, or store Garmin device-sourced data

For the initial development and testing phase, the planned integration will use a self-hosted PACE backend on hardware operated by the developer. The backend uses PocketBase with SQLite for storage and Caddy as a local reverse proxy; these are self-hosted software components, not external hosting services.

Tailscale, Inc. provides public HTTPS connectivity through Tailscale Funnel for delivery to the self-hosted backend. No external cloud database is currently planned. Garmin-sourced data is not intended to be sent to third-party AI or analytics services. Any additional service involved in processing or storing Garmin data will be identified before it is introduced.

Примечание: это описание текущего плана, не утверждение о работающей Garmin-интеграции. Перед отправкой проверить, не планируются ли другие подрядчики/хостинг/аналитика. Не писать None/N/A: Tailscale используется в доставке. GitHub хранит исходники, а не Garmin-данные; ChatGPT/Codex не планируются как обработчик реальных Garmin-тренировок.

### Остальные поля

| Поле | Как заполнить |
| --- | --- |
| Company Name | Фактическое имя заявителя/организации; если допустим проект, PACE — Independent Developer. Не заявлять вымышленное юрлицо. |
| Company Website URL | Нужна настоящая публичная страница проекта. Готовый продуктовый URL пока не подтверждён; не подставлять API health. |
| Company Privacy Policy URL | Нужна настоящая публичная политика для PACE. Ещё не подготовлена/не опубликована. |
| Contact Name / Email / Address / City / Country / Region / Postal Code | Пользователь вводит реальные сведения самостоятельно. Не отправлять домашний адрес в чат и не сохранять его в Git. |
| Job Title | Independent Developer (если соответствует фактической роли). |
| Primary business service | Выбрать ближайший фактический вариант разработки ПО/приложения; точные опции пока не видны. |
| Industry | Выбрать ближайший фактический вариант Fitness / Sports; точные опции пока не видны. |
| APIs | Только Activity API на данном этапе. |
| Connected Garmin users within12months | Реалистичная оценка именно подключённых Garmin-аккаунтов, не общее число установок. Пользователь ещё не указал число, диапазон не выдумывать. |
| Previous contact with Garmin/distributor | No, только если фактически контакта не было. |
| Contact name if yes | Заполнять только при реальном предыдущем контакте; при No оставить пустым. |

Перед отправкой остаются реальные сайт/политика, личные сведения, оценка пользователей и уточнение dropdown. Форма не отправлялась, новые ключи/учётные записи и внешние публикации не создавались.
