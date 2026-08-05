# saobracaj_web — сервер веб-версии (saobracaj.gleb.at)

Маленький сервер на Rust (axum), который раздаёт сборку `flutter build web`.
Обычного статического сервера здесь не хватает по трём причинам:

1. **Диплинки.** `https://saobracaj.gleb.at/invite/ABC-DEF-GHI` — не файл на
   диске. Любой неизвестный путь отдаёт `index.html` с кодом 200, иначе
   приглашение открывалось бы 404-й страницей.
2. **Превью ссылок.** Мессенджеры и соцсети не запускают Flutter — они читают
   `<head>`. Сервер подставляет в `index.html` заголовок, описание и Open
   Graph-теги той страницы, которую попросили: для `/question/:id` — текст
   самого вопроса и его картинку (берутся из `assets/assets/allQuestions*.json`
   в самой же сборке, дублировать ничего не надо), для `/invite/:token` —
   нейтральную карточку без кода приглашения.
3. **Проверка ссылок платформами.** `/.well-known/assetlinks.json` (Android App
   Links) и `/.well-known/apple-app-site-association` (iOS Universal Links)
   вшиты в бинарник и отдаются с `Content-Type: application/json` — Apple файл
   без расширения, статический сервер угадал бы тип неверно.

Плюс мелочи, на которых веб-сборка спотыкается: `application/wasm` для
`.wasm`, `no-cache` для точек входа (`index.html`, `flutter_bootstrap.js`,
`flutter_service_worker.js`, `version.json`, `manifest.json`) и часовой кэш для
остального, gzip/brotli, `nosniff`, аккуратная 404 для запроса
несуществующего ассета (иначе HTML попал бы в кэш service worker под именем
картинки).

## Переменные окружения

| Переменная | По умолчанию | Зачем |
|---|---|---|
| `WEB_ROOT` | `/srv/web` | каталог со сборкой (`build/web`) |
| `HOST` / `PORT` | `0.0.0.0` / `8080` | адрес прослушивания |
| `PUBLIC_ORIGIN` | `https://saobracaj.gleb.at` | origin для `og:url` и `canonical` |
| `CROSS_ORIGIN_ISOLATION` | `off` | `off` / `credentialless` / `require-corp` |
| `RUST_LOG` | `info` | уровень логов |

### Про `CROSS_ORIGIN_ISOLATION`

Изоляция (`COOP: same-origin` + `COEP`) включает `SharedArrayBuffer`: это
многопоточный рендерер Skia и самый быстрый OPFS-режим drift. Она же ломает
попап входа через Firebase (его убивает именно `COOP: same-origin`) и любые
сторонние ресурсы без CORP/CORS-заголовков. Поэтому по умолчанию **выключена**:
drift сам откатывается на более медленный, но рабочий режим хранения, а
соц-логин продолжает работать. Включать — осознанно и с проверкой входа
Google/Apple в вебе.

## Локальный запуск

```bash
cd app
flutter build web --wasm --release          # можно и обычный flutter build web
cd web_server
WEB_ROOT=../build/web PORT=8080 cargo run

open http://127.0.0.1:8080
curl -s http://127.0.0.1:8080/question/7935 -H 'Accept-Language: ru' | grep og:
```

Тесты: `cargo test` (25 тестов — маршрутизация, заголовки, подстановка мета-тегов,
разбор файлов вопросов, содержимое `.well-known`).

## Как это собирается и деплоится

`app/Dockerfile` собирает этот крейт и кладёт рядом уже готовый `build/web` —
Flutter внутри образа не запускается (это +2 ГБ и минуты на каждый деплой).
Пайплайн `.github/workflows/deploy-web.yml` при пуше в `main`:

1. `flutter analyze`, `flutter test`, `cargo test`;
2. `flutter build web --wasm --release`;
3. сборка образа `ghcr.io/saobracaj/saobracaj_web` и пуш в GHCR;
4. по SSH на OVH VPS: `WEB_IMAGE=<тег>` в `~/app/.env`, `docker compose pull web`,
   `docker compose up -d web`.

Сервис `web`, TLS и nginx описаны в `saobracaj_backend/deploy` (там же
инструкция по DNS и сертификату) — веб живёт на той же машине, что и API.
