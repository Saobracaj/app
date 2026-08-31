# Аналитика: PostHog

Все продуктовые события приложение шлёт в **PostHog Cloud EU**
(https://eu.posthog.com, проект 258743). Google Analytics и собственный журнал
на бэкенде убраны — приёмник один.

## Как устроено

- Код: `lib/core/analytics/` — `AnalyticsService` (методы-события, глобал
  `analytics`) и `AnalyticsEventSink` (очередь и отправка).
- Официальный SDK `posthog_flutter` не используется **сознательно**: прод-веб
  собирается в wasm, где JS-обвязка плагина не работает. Вместо него — тот же
  публичный HTTP-API `/batch/`, которым пишет и сам SDK: пачки раз в 20 секунд,
  по накоплению 25 событий и при уходе приложения в фон; обрыв связи ничего не
  теряет (пачка возвращается в очередь, потолок 500 событий), повторная
  отправка не задваивает (клиентский `uuid`, PostHog дедуплицирует).
- **Личности.** Гость идентифицируется установкой (`$device_id` — тот же
  идентификатор, что в заголовке `X-Device-Id`). При входе уходит `$identify` с
  `$anon_distinct_id`: гостевая история установки склеивается с аккаунтом, у
  персоны появляются `email` и наш `user id` (distinct id). После выхода
  события снова идут от установки.
- **Контекст на каждом событии:** `$os` (web/android/ios), `$os_version` (кроме
  веба), `$app_version`, `locale` (язык интерфейса), `russian_content` (включён
  ли русскоязычный контент локальным тумблером), `$session_id` (один запуск
  приложения), `$screen_name` (человекочитаемое имя экрана) и `route` (шаблон
  маршрута, например `/question/:id`).
- **Экраны:** каждое переключение маршрута — стандартное событие `$screen`.
  Имена — в `lib/core/analytics/screen_name.dart` (`analyticsScreenTitle`);
  сырые адреса с номерами вопросов туда не попадают.
- **Приватность:** написанное пользователем в события не попадает — у поиска
  только длина запроса и число результатов, у сообщений только вид чата, у
  промокода только валиден/нет.

## Словарь событий

| Событие | Когда | Свойства |
| --- | --- | --- |
| `$screen` | смена экрана | `$screen_name`, `route` |
| `$identify` | вход в аккаунт | `$set.email` |
| `login` / `sign_up` | вход / регистрация | `method` (`password`/`firebase`) |
| `category_opened` | выбор подкатегории в списке категорий | `subcategory`, `question_count` |
| `question_list_opened` | открытие своего списка вопросов | `question_count` |
| `test_started` | начало прогона вопросов | `question_count`, `subcategory` |
| `question_viewed` | показ вопроса (и каждое перелистывание) | `question_id` |
| `question_answered` | ответ на вопрос | `question_id`, `correct`, `seconds_since_shown` |
| `question_tabs_viewed` | домотал до вкладок под вопросом (телефон) | `question_id` |
| `question_tab_opened` | переключение вкладки под вопросом | `tab`, `question_id` |
| `test_finished` | завершение прогона | `question_count`, `right_answers`, `score`, `possible_score`, `subcategory`, `duration_seconds` |
| `simulation_started` | старт симуляции экзамена | — |
| `simulation_finished` | финиш симуляции (рукой или таймером) | `duration_seconds`, `points`, `mistakes` |
| `definition_opened` | тап по определению в тексте вопроса | `term` |
| `translation_toggled` | чип «РУ» на вопросе | `enabled` |
| `konspekt_opened` | открытие конспекта | `category` |
| `zakon_opened` | открытие закона (или правилника) по ссылке | `chlan`, `paragraph`, `chapter`, `document` (`zakon`/`pravilnik`) |
| `question_shared` | копирование ссылки на вопрос | `question_id` |
| `question_list_shared` | первый шаринг списка | `question_count` |
| `shared_list_opened` | открытие чужой ссылки на список | `outcome`, `question_count`, `viewer_is_owner` |
| `shared_list_imported` | импорт чужого списка | `question_count` |
| `group_created` / `group_joined` | создание группы / вступление | — |
| `chat_message_sent` | сообщение в чате (в т.ч. комментарий к вопросу) | `kind` (`support`/`question`/`group`/`thread`/`chat`) |
| `ask_ai_question` | вопрос AI в живом чате | `scope`, `scope_id` |
| `question_search` | поиск по вопросам | `query_length`, `results` |
| `checkout_step` | шаг покупки | `step` (`purchase_started`/`purchase_completed`/`purchase_cancelled`/`purchase_failed`/`purchases_restored`), `sku` |
| `russian_addon_toggled` | галочка русского контента на тарифах | `enabled` (+ персона `russian_addon_chosen`) |

«Сколько прошло с регистрации» отдельным свойством не едет: у персоны в
PostHog есть дата первого события и `$set`-время, разница считается прямо в
инсайтах.

## Новое событие

Метод в `AnalyticsService` + вызов из Bloc'а (сервис fail-soft: без приёмника
вызовы молча глотаются, виджет-тесты ничего не настраивают). Имена —
`snake_case`, значения свойств — низкокардинальные; ничего написанного
пользователем.
