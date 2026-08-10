# Куда подключается готовый виджет

Виджет сам по себе нигде не виден: его показывает markdown-маркер
`![альт](anim/<slug>)`. Разбирают маркер два рендерера:

- `lib/konspekt/presentation/konspekt_markdown.dart` — тексты конспектов;
- `lib/test/quest/presentation/quest_markdown.dart` — вопросы и
  комментарии-объяснения.

Оба на `anim/<slug>` зовут `getAnimation(slug)` из
`lib/test/animations/animations_map.dart`. Незарегистрированный слаг даёт на
экране текст «Animation not found» — молча, без падения.

## 1. Регистрация

```dart
// lib/test/animations/animations_map.dart
final _animations = {
  …,
  'kruzni-tok': KruzniTok(),
};
```

Ключ — слаг из задачи, **через дефис**, буква в букву. Имя файла — тот же
слаг в snake_case.

## 2. Конспект (`konspekt_content/<категория>.json`)

В тексте конспекта на месте будущей картинки стоит плейсхолдер
`![…](illustration:<slug>)`, и в приложении вместо него видна серая плашка.
Заменяем:

1. Найти маркер **внутри `blocks[].content.ru`** (не в `content` секции —
   он генерируется) и заменить на `![альт](anim/<slug>)`. Альт берётся из
   поля «ALT в тексте» задачи.
2. Удалить запись `<slug>` из `illustrations[]` этой секции — это было ТЗ
   для художника, оно больше не нужно.
3. Из каталога `app/`:

   ```bash
   python3 .claude/skills/category-konspekt/scripts/konspekt_cli.py sync-blocks konspekt_content/32.json
   python3 .claude/skills/category-konspekt/scripts/konspekt_cli.py validate   konspekt_content/32.json
   python3 .claude/skills/category-konspekt/scripts/konspekt_cli.py publish    konspekt_content/32.json
   ```

   `publish` обязателен: конспекты в приложении читаются из БД бэкенда, а не
   из ассетов. Публикация требует доступа к прод-БД (см. скилл
   `category-konspekt`); если доступа нет — так и напиши в отчёте, изменения
   в JSON всё равно едут в PR.

## 3. Комментарий-объяснение к вопросу

Тексты комментариев живут **в БД бэкенда** (`question_comments`), не в
репозитории. Маркер `![альт](anim/<slug>)` вставляется в текст комментария:

- через скилл `.claude/skills/question-law-comments` (там же доступ к
  GraphQL API), или
- руками в панели `https://saobracaj-panel.gleb.at/questions/<id>`.

Это отдельное действие от коммита: **ассет едет в приложение, текст
комментария — в базу**. В одном вопросе картинка объяснения не заменяет
картинку условия — она добавляется к разбору.

Один виджет обычно вставляется сразу в несколько вопросов (список — в
задаче) и заодно в смежную секцию конспекта. Рисуем один раз.

## 4. Проверка связей

```bash
python3 .claude/skills/illustration-widget/tools/check_illustrations.py
```

Показывает: маркеры `anim/…` без регистрации, зарегистрированные и
неиспользованные слаги, оставшиеся плейсхолдеры `illustration:…` по
конспектам (это и есть очередь работы). Комментарии из БД скрипт не видит —
их проверять в панели.
