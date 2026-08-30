# CI/CD: сборка и публикация

Единственный пайплайн — [`.github/workflows/build-and-deploy.yml`](../.github/workflows/build-and-deploy.yml).
Он собирает все три площадки; отдельного `deploy-web.yml` больше нет, его джобы
переехали сюда как `build-web` / `deploy-web`.

| Джоба | Что делает | Когда запускается |
|---|---|---|
| `preflight` | считает версию, проверяет наличие секретов | всегда |
| `checks` | `flutter analyze`, `flutter test`, `cargo test` в `web_server`, проверка патчера подписи iOS | всегда (в т.ч. на PR) |
| `build-android` | подписанные APK + AAB → артефакты; загрузка в Google Play (внутренний трек) | push в `main`, ручной запуск |
| `build-ios` | подписанный IPA → артефакт, валидация в App Store Connect, заливка в TestFlight | push в `main`, ручной запуск |
| `distribute-testflight` | ждёт обработки сборки в App Store Connect и добавляет её во внутреннюю группу TestFlight | вместе с заливкой в TestFlight |
| `build-web` | `flutter build web --wasm` → Docker-образ Rust-сервера → GHCR | push в `main`, ручной запуск |
| `deploy-web` | раскатка образа на OVH VPS → https://saobracaj.gleb.at | push в `main`, ручной запуск с `deploy_web` |

На pull request выполняется только `checks` — сборки под магазины стоят минут
раннера (особенно macOS) и ничего не публикуют.

**Джоба со ненастроенными секретами не падает, а пропускается.** `preflight`
проверяет, какие креды заданы, и выставляет флаги; `build-ios` со ненастроенной
подписью просто не запустится, и пайплайн останется зелёным. Как только секрет
добавлен — джоба оживает сама, менять YAML не нужно.

## Версия сборки

Имя версии (`1.0.0`) берётся из `pubspec.yaml` и меняется только руками. Номер
сборки — `github.run_number + 100`, он передаётся в `flutter build` через
`--build-number`; в репозиторий ничего не коммитится.

⚠️ **Перед релизом поднимайте имя версии в `pubspec.yaml`.** Как только версия
одобрена в App Store, её «поезд» закрывается, и Apple отклоняет любые новые
сборки с этим именем (ошибка 90186), каким бы большим ни был номер сборки.

## Ручной запуск

Actions → **Build & Deploy** → Run workflow. Галочки:

| Вход | По умолчанию | Смысл |
|---|---|---|
| `build_android` / `build_ios` / `build_web` | ✅ | что собирать |
| `deploy_ios` | ❌ | залить IPA в TestFlight |
| `deploy_android` | ❌ | залить AAB в Google Play (нужен ещё и `PLAY_UPLOAD_ENABLED`) |
| `deploy_web` | ❌ | раскатать веб на VPS |

При push в `main` заливка в TestFlight и в Google Play (внутренний трек)
происходит автоматически; раскатка прод-веба — тоже только при push в `main`.
Push в `develop` мобильные сборки не запускает — с develop автоматически
катится только dev-веб (отдельный `deploy-dev-web.yml`). Заливку в Google Play
можно экстренно выключить, сбросив переменную `PLAY_UPLOAD_ENABLED` (см. ниже).

---

## Секреты и переменные

Настраиваются в **Settings → Secrets and variables → Actions** репозитория
`Saobracaj/app` (или на уровне организации).

### Android — уже настроено ✅

Старый релизный ключ утерян, поэтому **создан новый ключ загрузки** (PKCS12, RSA
4096, срок 30 лет, alias `saobracaj`). Секреты уже залиты в репозиторий.

| Секрет | Что это |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore `saobracaj-upload.jks` в base64 |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_PASSWORD` | пароль ключа (совпадает с паролем хранилища) |
| `ANDROID_KEY_ALIAS` | `saobracaj` |

🔐 **Оригинал ключа и паролей лежит вне git**, в
`~/Documents/2026/saobracaj/private_documents/android-release-key/`
(`saobracaj-upload.jks`, `key.properties`, `saobracaj-upload.jks.base64`).
**Сделайте резервную копию в менеджер паролей — потеря этого ключа повторит
текущую проблему.**

Отпечатки нового ключа:

```
SHA1:   CC:3D:3F:A8:CE:65:B0:13:24:E8:D7:C7:EE:EF:DD:38:A4:0A:A6:8F
SHA256: 13:D8:5D:68:33:39:A8:3D:6E:D3:28:6D:E2:5B:58:A3:C4:D3:E5:6F:2E:6F:5C:AB:CE:AB:F6:CF:4C:A6:DE:2A
```

⚠️ **Google Sign-In.** Вход через Google на Android привязан к отпечатку
подписи. APK из этого пайплайна подписан ключом выше, поэтому его SHA-1 нужно
добавить в Firebase Console → Project settings → приложение `at.gleb.saobracaj`
→ «Add fingerprint» (и перекачать `google-services.json`, если он изменится),
иначе в таких сборках Google-логин будет падать. Для сборок **из Google Play**
важен отпечаток ключа Play App Signing — его надо взять в Play Console
(*App signing*) и добавить туда же.

Локально `android/key.properties` отсутствует, и release-сборка подписывается
debug-ключом (Gradle пишет предупреждение) — так `flutter run --release`
продолжает работать на любой машине. Файл и `*.jks` в `.gitignore`.

### Google Play — включено ✅

Заливка работает (`r0adkll/upload-google-play`, трек `internal`): исторический
upload-ключ найден и возвращён в бой 2026-08-22, `PLAY_UPLOAD_ENABLED` = `true`,
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` залит. Ниже — шаги, которые понадобятся
заново, если ключ или сервисный аккаунт придётся пересоздавать:

1. **Сбросить ключ загрузки в Google Play.** Play Console → нужное приложение →
   *Test and release → Setup → App signing* → «Request upload key reset».
   Приложить сертификат нового ключа:
   ```bash
   # пароль — storePassword из key.properties (спросит интерактивно)
   keytool -exportcert -rfc -keystore saobracaj-upload.jks -alias saobracaj \
           -file upload_certificate.pem
   ```
   Гугл обрабатывает заявку до 1–2 рабочих дней.
   *Если приложение ещё ни разу не публиковалось — сброс не нужен, новый ключ
   просто станет ключом загрузки при первой заливке.*
2. **Создать сервисный аккаунт** для API: Play Console → *Users and permissions*
   → пригласить сервисный аккаунт из Google Cloud (роль «Release manager» либо
   права `Release to testing tracks`); в Google Cloud Console → IAM & Admin →
   Service Accounts → Keys → Add key → JSON. Содержимое JSON целиком положить в
   секрет `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
3. **Включить тумблер:** переменная (не секрет!) `PLAY_UPLOAD_ENABLED` = `true`.
   Это аварийный выключатель: любое другое значение оставляет AAB и APK просто
   артефактами сборки — их можно скачать со страницы запуска и залить руками.

### iOS — уже настроено ✅

Все шесть секретов залиты в `Saobracaj/app` 2026-08-07. Сертификат
**Apple Distribution (Gleb Klimov, BHH5379JU2)** и профиль
**Saobracaj App Store** истекают **2027-08-07** — тогда пройти шаги 1–2 заново
и обновить три секрета `APPLE_*`. Ключ API: Key ID `2L62KV83FX`, роль
App Manager. Оригиналы (p12, пароль, профиль, `AuthKey_*.p8`) лежат вне git в
`~/Documents/2026/saobracaj/private_documents/apple-distribution/` — **сделайте
резервную копию в менеджер паролей**. Запись приложения в App Store Connect
уже существует (Apple ID `6744607772`), причём версия **1.0 уже одобрена**
(«Ready for Distribution») — перед первой заливкой в TestFlight поднимите имя
версии в `pubspec.yaml`, иначе валидация упадёт с ошибкой 90186.

Bundle ID приложения — `at.gleb.saobracaj.saobracaj`, Team ID — `BHH5379JU2`
(уже прописаны в workflow как `IOS_BUNDLE_ID` / `APPLE_TEAM_ID`). Ниже — что
именно заведено и где это брать при перевыпуске.

| Секрет | Что это | Где взять |
|---|---|---|
| `APPLE_CERTIFICATE_BASE64` | сертификат **Apple Distribution** вместе с приватным ключом, экспортированный в `.p12` и закодированный base64 | см. шаг 1 |
| `APPLE_CERTIFICATE_PASSWORD` | пароль, заданный при экспорте `.p12` | придумывается на шаге 1 |
| `APPLE_PROVISIONING_PROFILE_BASE64` | provisioning profile типа **App Store** в base64 | см. шаг 2 |
| `KEYCHAIN_PASSWORD` | необязательный; пароль временной связки ключей на раннере. Если не задать, генерируется случайный | — |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID ключа App Store Connect API (10 символов) | см. шаг 3 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID), общий для всей команды | см. шаг 3 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | содержимое файла `AuthKey_XXXXXXXXXX.p8` целиком, вместе со строками `-----BEGIN PRIVATE KEY-----` | см. шаг 3 |

Без первых двух групп секретов джоба `build-ios` пропускается; без ключа API
собирается IPA-артефакт, но валидации и заливки в TestFlight не будет.

#### Шаг 1. Сертификат Apple Distribution → `.p12`

Проще всего через Xcode на Mac:

1. Xcode → Settings → Accounts → выбрать Apple ID и команду (Team ID `BHH5379JU2`)
   → **Manage Certificates…** → «+» → **Apple Distribution**.
2. Открыть **Keychain Access** → «My Certificates» → найти
   `Apple Distribution: … (BHH5379JU2)` → правой кнопкой → **Export…** →
   формат «Personal Information Exchange (.p12)» → задать пароль (это
   `APPLE_CERTIFICATE_PASSWORD`).
   ⚠️ Экспортировать нужно именно строку сертификата **с раскрытым приватным
   ключом** внутри, иначе на раннере подпись не заработает.
3. Закодировать:
   ```bash
   base64 -i Certificates.p12 | pbcopy   # → APPLE_CERTIFICATE_BASE64
   ```

Альтернатива без Xcode: https://developer.apple.com/account → Certificates,
Identifiers & Profiles → Certificates → «+» → *Apple Distribution* → загрузить
CSR из Keychain Access (*Keychain Access → Certificate Assistant → Request a
Certificate From a Certificate Authority*) → скачать `.cer`, открыть двойным
кликом (попадёт в связку) и дальше экспортировать `.p12` как в пункте 2.

#### Шаг 2. Provisioning profile (App Store)

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
   → **Identifiers** — убедиться, что App ID `at.gleb.saobracaj.saobracaj`
   существует и в нём включены нужные capabilities. Их ровно три, по числу
   ключей в `ios/Runner/Runner.entitlements`: **Push Notifications**
   (`aps-environment`), **Sign in with Apple** (`com.apple.developer.applesignin`)
   и **Associated Domains** (`com.apple.developer.associated-domains` —
   Universal Links на `saobracaj.gleb.at`). Подпись в CI ручная, поэтому
   профиль, в котором не хватает хотя бы одного из них, роняет сборку с
   «Provisioning profile doesn't include the … entitlement».
2. **Profiles** → «+» → **App Store Connect** (раздел *Distribution*) → выбрать
   этот App ID → выбрать сертификат из шага 1 → задать имя (например
   `Saobracaj App Store`) → Generate → Download.
3. Закодировать:
   ```bash
   base64 -i Saobracaj_App_Store.mobileprovision | pbcopy   # → APPLE_PROVISIONING_PROFILE_BASE64
   ```

Имя профиля из workflow брать не нужно: оно читается из самого профиля и
подставляется в `ExportOptions.plist` автоматически. Профиль с привязанными
устройствами (development / ad-hoc) пайплайн отвергает с понятной ошибкой.

#### Шаг 3. Ключ App Store Connect API

1. https://appstoreconnect.apple.com → **Users and Access** → вкладка
   **Integrations** (ранее «Keys») → **App Store Connect API** → «+».
2. Имя — например `GitHub Actions`, роль — **App Manager** (минимум, которого
   хватает для заливки в TestFlight).
3. Скачать `AuthKey_XXXXXXXXXX.p8` — **он выдаётся ровно один раз**.
4. Со страницы списка скопировать **Key ID** (в имени файла) и **Issuer ID**
   (сверху над таблицей).
5. ```bash
   cat AuthKey_XXXXXXXXXX.p8 | pbcopy   # → APP_STORE_CONNECT_API_KEY_CONTENT
   ```

#### Шаг 4. Приложение в App Store Connect

Заливка попадёт в TestFlight, только если запись приложения уже создана:
App Store Connect → **Apps** → «+» → New App, платформа iOS, Bundle ID
`at.gleb.saobracaj.saobracaj`, SKU — любой.

#### Шаг 5. Внутренняя группа TestFlight

Сама по себе заливка (`altool --upload-app`) делает сборку невидимой для
тестировщиков: пока сборка не добавлена хотя бы в одну группу, её нет в
приложении TestFlight. Поэтому после заливки джоба `distribute-testflight`
дожидается конца обработки сборки (обычно 5–15 минут) и через App Store
Connect API добавляет её во внутреннюю группу **Internal manual**
(`ios/ci/assign_testflight_group.py`; имя группы задаётся переменной
`TESTFLIGHT_GROUP_NAME` в workflow).

Группа создана 2026-08-08 (TestFlight → Internal Testing) именно с **ручной**
раздачей. Старая группа «Saobracai internal» для CI непригодна: она создана с
галочкой «Enable automatic distribution», которая принимает только загрузки из
Xcode, запрещает ручное/API-добавление сборок и **не может быть изменена после
создания группы**. Beta App Review для внутренних групп не нужен — сборка
становится доступна тестировщикам сразу после добавления в группу.

#### Шаг 6. APNs Auth Key для пушей

К пайплайну ключ отношения не имеет — он живёт в Firebase, — но без него FCM
физически не может доставить пуш на iOS, каким бы верным ни был профиль.

Заведён 2026-08-09: Apple Developer → **Keys** → «+» → *Apple Push
Notifications service (APNs)*, конфигурация **Sandbox & Production**, Team
Scoped (All Topics). Имя «Saobracaj APNs», **Key ID `3QD434X5KG`**, файл
`AuthKey_3QD434X5KG.p8` выдаётся ровно один раз и лежит вне git в
`~/Documents/2026/saobracaj/private_documents/apple-distribution/`.

Тот же файл залит в Firebase Console → Project settings → **Cloud Messaging**
→ *Apple app configuration* → APNs Authentication Key, в **обе** строки —
development и production (Key ID `3QD434X5KG`, Team ID `BHH5379JU2`); ключ
собран под оба окружения, поэтому одинаково годится и для debug-сборок
(sandbox), и для TestFlight/App Store (production).

### Веб — уже работает ✅

Переменные `VPS_HOST`, `VPS_USER`, `VPS_SSH_PASSWORD` заданы на уровне
организации; деплой описан в `saobracaj_backend/deploy` (сервис `web` в
`~/app/docker-compose.yml` на VPS).

Секрет `FCM_VAPID_KEY` — публичный ключ Web Push (Firebase Console → Project
settings → **Cloud Messaging** → *Web configuration* → Web Push certificates →
«Generate key pair», скопировать строку «Key pair»). Ключ сгенерирован и залит
2026-08-09. Он уходит в сборку как `--dart-define=FCM_VAPID_KEY=…`; без него
веб-сборка **осознанно не регистрирует** push-токен (`PushTokenService`,
`lib/notifications/data/`) — `getToken()` на вебе без ключа может только
бросить исключение. Сервис-воркер `web/firebase-messaging-sw.js` уже в
репозитории. Пуши на Android и iOS от этого секрета не зависят.

---

## Подпись iOS в CI

Xcode-проект в репозитории использует автоматическую подпись — это удобно
локально, но невозможно на раннере без залогиненного Apple ID. Скрипт
[`ios/ci/set_manual_signing.py`](../ios/ci/set_manual_signing.py) переключает
**только Release-конфигурацию таргета Runner** на ручную подпись прямо в
рабочей копии CI; репозиторий не меняется. Джоба `checks` гоняет его в режиме
`--check`, так что переименование bundle ID или перегенерация проекта не
превратят патч в тихий no-op.

## Флейвор

Все сборки идут с `--target lib/main_prod.dart`. Без этого приложение поднимается
в debug-флейворе и стучится в `http://localhost:8080` (см. `lib/flavor.dart`) —
у прежнего веб-пайплайна был именно этот дефект.
