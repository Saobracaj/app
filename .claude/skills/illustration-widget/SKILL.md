---
name: illustration-widget
description: Use when asked to draw an illustration, scheme, infographic or animation for the Saobraćaj app (a task or subtask like «ИЛЛ · конспект 32 · znaci-policajca» or «АНИМ · комментарии · C4 — kruzni-tok»). Produces a Flutter widget drawn in code (CustomPainter / implicit animations) instead of a PNG, registers it in lib/test/animations/animations_map.dart, renders it to PNG previews so the result can be checked visually, and wires the ![alt](anim/<slug>) marker into a konspekt or a question comment.
---

# Illustration widget

Иллюстрации и анимации в приложении **не картинки, а виджеты**: они рисуются
кодом (`CustomPainter`, `AnimationController`), а в текст вставляются маркером
`![альт](anim/<slug>)`. Так они автоматически подстраиваются под тему
(светлая/тёмная), под ширину экрана и под язык интерфейса, ничего не весят в
ассетах и правятся в том же PR, что и текст.

Готовые примеры: `ThemedCompactDecisionTree` (статичная схема-дерево),
`Mimoilazenje`, `Obgon`, `BlockedRoadScene` (анимированные сцены) —
`app/lib/test/animations/`.

Скилл покрывает весь путь: нарисовать → посмотреть глазами → зарегистрировать →
вставить в текст → проверить.

## Что читать

- `reference/primitives.md` — что уже нарисовано и как этим пользоваться
  (дорога, машина, конус, треугольник, стрелки-выноски). **Сначала сюда:**
  большинство сцен собирается из готовых кусков.
- `reference/style-guide.md` — правила рисования: холст, цвета темы, текст и
  локализация, тайминги анимаций. Это самая важная часть.
- `reference/wiring.md` — куда вставить маркер: конспект (`konspekt_content` +
  publish) или комментарий-объяснение (БД бэкенда).

## Workflow

### 1. Разобрать ТЗ

В задаче есть `SLUG`, `ТИП` (иллюстрация/анимация), «ЧТО ДОЛЖНО БЫТЬ
ИЗОБРАЖЕНО» и «ГДЕ ИСПОЛЬЗУЕТСЯ». Слаг — это ключ в `animations_map.dart` и
в маркере, он **дословно** из задачи (через дефис: `kruzni-tok`), имя файла —
тот же слаг в snake_case (`kruzni_tok.dart`).

Открой пару вопросов из списка «ГДЕ ИСПОЛЬЗУЕТСЯ» (`assets/allQuestions.json`
через скилл `question-law-comments`, или панель), чтобы понять, какую именно
путаницу картинка должна снимать. Картинка объясняет **правило**, а не
пересказывает условие вопроса.

### 2. Посмотреть, что уже есть

```bash
grep -n "'" lib/test/animations/animations_map.dart      # какие слаги заняты
```

Если в ТЗ есть блок «УЖЕ ЕСТЬ В РЕПОЗИТОРИИ» или «СВЯЗЬ С ДРУГИМИ ПУНКТАМИ» —
смежная сцена уже нарисована: переиспользуй её геометрию и палитру, чтобы
дорога и машины выглядели одинаково во всём приложении. Не копируй файл
целиком — выноси общий кусок в отдельный виджет.

### 3. Нарисовать виджет

Файл `lib/test/animations/<slug_snake>.dart`, публичный класс с говорящим
именем (`KruzniTok`, а не `Widget1`). Правила — `reference/style-guide.md`,
коротко:

- фиксированный холст (`SizedBox(width: …, height: …)`) внутри `FittedBox` —
  так подписи не разъезжаются на узких экранах;
- цвета — из `Theme.of(context).colorScheme`; литеральные цвета только там,
  где цвет и есть содержание (асфальт, разметка, синий маячок);
- текст на холсте — через `TextPainter` со шрифтом `kAppFontFamily`;
  сербские термины не переводятся, русские подписи — через `LocaleKeys`;
- анимация: `AnimationController` + `SingleTickerProviderStateMixin`,
  обязательный `dispose()`, цикл 4–8 с с паузой в конце.

### 4. Посмотреть результат глазами (обязательно)

Тут скилл отличается от «написал и надеюсь». Харнесс рендерит виджет в PNG
прямо из `flutter test`, без запуска приложения:

```bash
# из каталога app/
SLUG=kruzni-tok \
  flutter test .claude/skills/illustration-widget/tools/render_preview_test.dart

# анимацию смотреть по кадрам:
SLUG=kruzni-tok FRAMES=0,1500,3000,4500 \
  flutter test .claude/skills/illustration-widget/tools/render_preview_test.dart
```

Файлы лягут в `build/illustration_preview/<slug>-<theme>[-<ms>ms].png` —
**открой каждый инструментом Read и посмотри**.

Тайминги: `THEMES=light` — около двух минут, обе темы — 10–15 (второй тест в
том же процессе почему-то заметно медленнее). Пока правишь геометрию, гоняй
одну тему; обе — один раз перед коммитом. Запускай в фоне
(`run_in_background`) и занимайся текстом задачи, пока считается.

Что проверяешь на картинке:

1. читаются ли подписи (не наезжают, не обрезаны, не мельче ~11 pt);
2. видно ли на тёмной теме то же, что на светлой (частая ошибка — чёрный
   текст на тёмном фоне из-за литерального `Colors.black`);
3. понятно ли правило без сопроводительного текста;
4. для анимации — читается ли каждый кадр как отдельная фаза.

Переменные: `FRAMES` (мс через запятую), `THEMES` (`light,dark`), `LOCALE`
(`ru|sr|en`), `WIDTH`/`HEIGHT` (размер поверхности, по умолчанию 390×844),
`OUT` (каталог).

### 5. Зарегистрировать

В `lib/test/animations/animations_map.dart` — ключ строго равен слагу из ТЗ:

```dart
'kruzni-tok': KruzniTok(),
```

### 6. Вставить маркер в текст

`reference/wiring.md`. Коротко: в конспекте заменить плейсхолдер
`![…](illustration:<slug>)` на `![альт](anim/<slug>)`, убрать запись из
`illustrations[]`, прогнать `sync-blocks` → `validate` → `publish`; в
комментарии-объяснении — вставить тот же маркер через скилл
`question-law-comments`.

### 7. Проверить

```bash
python3 .claude/skills/illustration-widget/tools/check_illustrations.py   # ссылки и слаги
flutter analyze
flutter test test/                                                       # если правил общие файлы
```

`check_illustrations.py` ловит главные грабли: маркер `anim/<slug>` без
регистрации в карте (в приложении вместо картинки будет текст «Animation not
found») и слаг, зарегистрированный, но нигде не использованный.

Если у виджета есть переводимые подписи — добавь их в
`assets/translations/*.json` (все три языка), прогони `./codegen.sh` и
проверь, что текст влезает в фигуры: образец такого теста —
`test/decision_tree_localization_test.dart`.

## Границы

- Никаких новых зависимостей, Lottie, GIF, SVG и PNG — только код.
- Не трогать `assets/md_img/` — папка для картинок, снятых извне; наши
  иллюстрации туда не кладутся.
- Фотореалистичность не нужна и не достигается: люди и техника рисуются
  пиктограммой (силуэт, простые формы), смысл несут подписи и стрелки.
  Если ТЗ требует именно фотографию — это не задача для этого скилла,
  вернись к оператору.
