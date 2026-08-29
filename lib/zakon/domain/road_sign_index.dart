import 'package:flutter/foundation.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';

/// Что правилник знает об одном дорожном знаке: файл изображения, название,
/// абзац-описание (на обоих языках) и адрес этого абзаца — из него собирается
/// ссылка /pravilnik?chapter=…&chlan=…&paragraph=….
class RoadSignInfo {
  const RoadSignInfo({
    required this.code,
    required this.asset,
    this.nameSr,
    this.nameRu,
    this.descriptionSr,
    this.descriptionRu,
    this.chapter,
    this.chlan,
    this.paragraph,
  });

  /// Код знака как в правилнике: «I-1», «II-43.2».
  final String code;

  /// Изображение знака — для официальных знаков тот же файл из assets/signs/,
  /// что показывают конспекты и иллюстрации.
  final String asset;

  /// Название из описания: „кривина налево” / «поворот налево».
  final String? nameSr;
  final String? nameRu;

  /// Полный абзац правилника, описывающий знак (он общий для знака и его
  /// вариантов: I-1 и I-1.1 описаны одной фразой).
  final String? descriptionSr;
  final String? descriptionRu;

  final String? chapter;
  final String? chlan;
  final String? paragraph;
}

/// Строка-подпись под знаками: только коды, выделенные жирным. Обычно код
/// один («**I-1**»), но бывают и слипшиеся(«**III-65III-65.1**»), и с лишним
/// пробелом внутри («**III -24.1**») — цена происхождения из docx.
final _captionRowRe = RegExp(r'^\*\*(?:[IVX]{1,3}\s*-\s*\d+(?:\.\d+)*\s*)+\*\*$');
final _codeRe = RegExp(r'[IVX]{1,3}\s*-\s*\d+(?:\.\d+)*');

/// Коды строки-подписи (без пробелов внутри кода) или пусто, если строка —
/// не подпись.
List<String> _captionCodes(String? sr) {
  final text = (sr ?? '').trim();
  if (!_captionRowRe.hasMatch(text)) return const [];
  return _codeRe
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'\s'), ''))
      .toList();
}

/// Собирает индекс «код знака → сведения» из строк правилника.
///
/// Структура документа регулярна: строка с картинками, за ней строки-подписи
/// с кодами (по одному на картинку, в том же порядке), дальше — абзац-описание
/// «1) знак „кривина налево” (I-1), …». Пары «картинка ↔ код» берутся только
/// при точном совпадении количества — так же собирает их и дедупликация в
/// tool/parse_pravilnik.py. Описание ищется вперёд в пределах окна: у групп
/// вроде II-43…II-43.4 один абзац стоит после нескольких блоков картинок.
Map<String, RoadSignInfo> buildRoadSignIndex(List<BezbParagraph> rows) {
  final index = <String, RoadSignInfo>{};
  for (var i = 0; i < rows.length; i++) {
    final images = rows[i].images;
    if (images.isEmpty) continue;
    final codes = <String>[];
    var j = i + 1;
    while (j < rows.length && codes.length < images.length) {
      final rowCodes = _captionCodes(rows[j].sr);
      if (rowCodes.isEmpty) break;
      codes.addAll(rowCodes);
      j++;
    }
    // Одна подпись на несколько картинок (фото + рисунок одной таблы, как у
    // IV-22) — код всё равно однозначен; прочие расхождения — не знаки.
    if (codes.length != images.length && !(codes.length == 1 && images.length > 1)) {
      continue;
    }
    for (var k = 0; k < codes.length; k++) {
      final code = codes[k];
      // В индексе только дорожные знаки (группы I–IV: опасность, наредбе,
      // обавештења, допунске табле): у разметки и семафоров (V и дальше)
      // другая структура описаний, и по ним никто не нажимает.
      if (!RegExp(r'^I{1,3}V?-').hasMatch(code)) continue;
      if (index.containsKey(code)) continue;
      final description = _findDescription(rows, j, code);
      index[code] = RoadSignInfo(
        code: code,
        asset: images[k].src,
        nameSr: _name(description?.sr, code, open: '„', close: '”'),
        nameRu: _name(description?.ru, code, open: '«', close: '»'),
        descriptionSr: description?.sr,
        descriptionRu: description?.ru,
        chapter: description?.chapter,
        chlan: description?.chlan,
        paragraph: description?.paragraph,
      );
    }
  }
  return index;
}

/// Код, за которым не продолжается номер: «III-65» не должен находиться
/// внутри «III-65.2».
RegExp _codeToken(String code) =>
    RegExp('${RegExp.escape(code)}(?![\\d.])');

/// Абзац-описание знака [code]: первая из ближайших строк (кроме подписей),
/// которая упоминает сам код — обычно пункт перечня «18) знак…», но бывает и
/// «Знак „туристичка информациона табла” (III-75)…» без номера. Окно
/// небольшое — описание стоит сразу за блоками «картинки + подписи».
final _itemRe = RegExp(r'^\d+\)\s');

BezbParagraph? _findDescription(List<BezbParagraph> rows, int from, String code) {
  final token = _codeToken(code);
  BezbParagraph? firstItem;
  for (var j = from; j < rows.length && j < from + 15; j++) {
    final sr = (rows[j].sr ?? '').trim();
    if (sr.isEmpty || _captionCodes(sr).isNotEmpty) continue;
    if (token.hasMatch(sr)) return rows[j];
    if (_itemRe.hasMatch(sr)) firstItem ??= rows[j];
  }
  // Код рядом не упомянут вовсе (в docx бывают опечатки вроде «lV-8.2» со
  // строчной L) — берём ближайший пункт перечня: он и есть описание блока.
  return firstItem;
}

/// Название знака из описания: текст в кавычках, за которым в скобках
/// перечислен [code] — «знак „кривина налево” (I-1)», «знакови „обавезан
/// смер” (II-43), (II-43.1) и (II-43.2)». Кавычки в сербском и русском
/// тексте разные — [open]/[close].
String? _name(String? description, String code, {required String open, required String close}) {
  if (description == null) return null;
  final token = _codeToken(code);
  final quoted = RegExp(
    // название в кавычках + цепочка скобок с кодами после него
    '$open([^$close]+)$close\\s*((?:\\([^)]*\\)[,\\s]*(?:и\\s*)?)+)',
  );
  for (final m in quoted.allMatches(description)) {
    if (token.hasMatch(m.group(2)!)) return m.group(1);
  }
  return null;
}

/// Индекс знаков правилника, собираемый один раз по первому обращению.
class RoadSignIndex {
  static Future<Map<String, RoadSignInfo>>? _index;

  /// Сведения о знаке [code] (регистр не важен: маркеры конспектов пишут
  /// «ii-2») или null, если правилник такого знака не описывает.
  static Future<RoadSignInfo?> find(String code) async {
    _index ??= pravilnikDataSource.paragraphs.then(buildRoadSignIndex);
    return lookupRoadSign(await _index!, code);
  }

  /// Сброс кэша для тестов: Future, рождённый в фейковой зоне одного
  /// widget-теста, в зоне следующего уже не дождаться.
  @visibleForTesting
  static void reset() {
    _index = null;
  }
}

/// Поиск с фолбэком: имена файлов в assets/signs/ бывают шире кодов
/// правилника.
///
/// - «ii-30-40» — вариант знака с другим числом: описание берётся у базового
///   II-30 (сначала пробуем «II-30.40» — вариант через точку);
/// - «ii-30-blank», «i-35-t2» — самодельные суффиксы файлов: тоже к базовому;
/// - «iii-11-2017» — знак из правилника 2017 года: его нумерация с этим
///   документом не совпадает, подставлять описание III-11 было бы враньём —
///   такой знак остаётся без описания.
///
/// Вынесен отдельно, чтобы тесты гоняли ровно боевое правило на индексе,
/// собранном из файла.
RoadSignInfo? lookupRoadSign(Map<String, RoadSignInfo> index, String code) {
  final upper = code.toUpperCase();
  final exact = index[upper];
  if (exact != null) return exact;
  if (upper.endsWith('-2017')) return null;
  final numeric = RegExp(r'^(.+)-(\d+)$').firstMatch(upper);
  final dotVariant = RegExp(r'^(.+)\.\d+$').firstMatch(upper);
  final letters = RegExp(r'^(.+\d)[A-Z]+$').firstMatch(upper);
  final suffixed = RegExp(r'^(.+)-[A-Z0-9]+$').firstMatch(upper);
  final candidates = <String?>[
    // «II-30-40» → вариант через точку «II-30.40»
    if (numeric != null) '${numeric.group(1)}.${numeric.group(2)}',
    // «I-29.2», «III-68.1» → базовый знак семейства
    dotVariant?.group(1),
    // «I-36C» → «I-36»
    letters?.group(1),
    // «II-30-BLANK», «I-35-T2» → базовый знак
    suffixed?.group(1),
  ];
  for (final candidate in candidates) {
    final hit = index[candidate];
    if (hit != null) return hit;
  }
  return null;
}
