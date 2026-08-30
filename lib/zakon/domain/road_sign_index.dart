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
RoadSignIndexData buildRoadSignIndex(List<BezbParagraph> rows) {
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
  final byAsset = <String, RoadSignInfo>{};
  for (final info in index.values) {
    // Первый код выигрывает: одна и та же табла IV-группы стоит в документе
    // несколько раз, а сетка допунских табли повторяет рисунок построчно.
    byAsset.putIfAbsent(info.asset, () => info);
  }
  return RoadSignIndexData(byCode: index, byAsset: byAsset);
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

/// Индекс правилника: сведения о знаке достаются и по коду документа, и по
/// файлу изображения. Файл — ключ надёжнее кода: имена в assets/signs/ идут
/// по нумерации правилника 2017 года, а этот документ 2010-го, и номера
/// местами разошлись (файл iii-68.svg — аутопут, а III-68 в документе — деца
/// на путу).
class RoadSignIndexData {
  const RoadSignIndexData({required this.byCode, required this.byAsset});

  final Map<String, RoadSignInfo> byCode;
  final Map<String, RoadSignInfo> byAsset;
}

/// Индекс знаков правилника, собираемый один раз по первому обращению.
class RoadSignIndex {
  static Future<RoadSignIndexData>? _index;

  /// Сведения о знаке [sign] — имя файла из assets/signs/ («ii-2», регистр не
  /// важен) — или null, если правилник такого знака не описывает.
  static Future<RoadSignInfo?> find(String sign) async {
    _index ??= pravilnikDataSource.paragraphs.then(buildRoadSignIndex);
    return lookupRoadSign(await _index!, sign);
  }

  /// Сброс кэша для тестов: Future, рождённый в фейковой зоне одного
  /// widget-теста, в зоне следующего уже не дождаться.
  @visibleForTesting
  static void reset() {
    _index = null;
  }
}

/// Знаки, у которых имя файла и код документа означают РАЗНЫЕ знаки: файлы
/// названы по правилнику 2017 года, а документ — 2010-го. Для них привязка по
/// коду запрещена (описание было бы от чужого знака — так «зона школе» на
/// экране объяснялась «престанком забране давања звучних знакова»); годится
/// только совпадение по файлу.
///
/// Список повторяет OFFICIAL_OVERRIDES из tool/parse_pravilnik.py, где по тем
/// же парам подменяются картинки самого документа; синхронность проверяет
/// test/road_sign_index_test.dart.
const renumberedIn2017 = {
  'III-7',
  'III-17',
  'III-18',
  'III-19',
  'III-26',
  'III-27',
  'III-28',
  'III-29',
  'III-29.1',
  'III-30',
  'III-32',
  'III-32.1',
  'III-68',
};

/// Знаки образца 2017 года и переномерованные файлы, для которых в правилнике
/// 2010 года есть тот же знак под другим номером: рисунок мог поменяться, но
/// значение и абзац-описание те же («деца на путу» — зелёная табла 2017 года,
/// в этом документе III-68).
///
/// Пары найдены сличением изображений (tool/audit_signs_gaps_test.dart) и
/// проверены по тексту описаний; всё, чему пары в документе нет, остаётся без
/// описания — врать описанием чужого знака нельзя.
const equivalentIn2010 = {
  'iii-11-2017': 'III-68', // деца на путу
  'iii-8-2017': 'III-7', // прелаз за пешаке ван нивоа
  'iii-14-40': 'III-27', // престанак ограничења брзине
  'iii-15-40': 'III-27.1', // престанак најмање дозвољене брзине
  'iii-67-70': 'III-60', // препоручена брзина
  'iii-68.1': 'III-20', // завршетак аутопута
  'e75-srb': 'III-18', // ознака европског пута
};

/// Сведения о знаке по имени файла в assets/signs/.
///
/// Порядок такой:
///
/// 1. **по файлу** — правилник показывает ровно этот файл (дедупликация в
///    tool/parse_pravilnik.py подставила официальные SVG в сам документ), так
///    что описание гарантированно от этого знака, каким бы номером он в
///    документе ни назывался;
/// 2. **по файлу базового знака** — «ii-30-40» (ограничение 40 км/ч),
///    «ii-30-blank», «i-36c», «iii-85-1»: это варианты одного знака, описание
///    у семейства общее;
/// 3. **по коду** — на случай, когда рисунок знака в документе остался
///    извлечённым из docx (официального SVG у него нет) и по файлу не
///    сходится. Запрещено для [renumberedIn2017] и там, где у кода документа
///    свой официальный файл: раз он другой, знаки разные.
///
/// Перед привязкой по коду срабатывает таблица [equivalentIn2010] — тот же
/// знак под другим номером. Знаки с суффиксом «-2017» (образец 2017 года,
/// которого в этом документе нет) базового знака не ищут: «iii-25-2017» и
/// «III-25» — разные знаки.
RoadSignInfo? lookupRoadSign(RoadSignIndexData index, String sign) {
  final file = sign.toLowerCase();
  final exact = index.byAsset['assets/signs/$file.svg'];
  if (exact != null) return exact;
  // Раньше поиска по семейству: «iii-68.1» (завршетак аутопута) не должен
  // достаться базовому «iii-68» — это сам аутопут.
  final equivalent = index.byCode[equivalentIn2010[file]];
  if (equivalent != null) return equivalent;
  for (final candidate in _fileCandidates(file).skip(1)) {
    final hit = index.byAsset['assets/signs/$candidate.svg'];
    if (hit != null) return hit;
  }
  if (file.endsWith('-2017')) return null;
  for (final candidate in _codeCandidates(file.toUpperCase())) {
    if (renumberedIn2017.contains(candidate)) continue;
    final hit = index.byCode[candidate];
    // У кода свой официальный файл, и он не наш (иначе сработал бы поиск по
    // файлу) — значит, это другой знак.
    if (hit == null || hit.asset.startsWith('assets/signs/')) continue;
    return hit;
  }
  return null;
}

/// Имена файлов, чьё описание годится знаку [file]: он сам и базовые знаки
/// его семейства.
List<String> _fileCandidates(String file) {
  if (file.endsWith('-2017')) return [file];
  final numeric = RegExp(r'^(.+)-(\d+)$').firstMatch(file);
  final letters = RegExp(r'^(.+\d)[a-z]+$').firstMatch(file);
  final suffixed = RegExp(r'^(.+)-[a-z0-9]+$').firstMatch(file);
  final dotVariant = RegExp(r'^(.+)\.\d+$').firstMatch(file);
  return [
    file,
    // «ii-30-40» → вариант через точку «ii-30.40», затем сам «ii-30»
    if (numeric != null) '${numeric.group(1)}.${numeric.group(2)}',
    if (numeric != null) numeric.group(1)!,
    // «i-36c» → «i-36»
    if (letters != null) letters.group(1)!,
    // «ii-30-blank», «i-35-t2», «iii-85-1» → базовый знак
    if (suffixed != null) suffixed.group(1)!,
    // «i-29.2» → «i-29»
    if (dotVariant != null) dotVariant.group(1)!,
  ];
}

/// Коды правилника, под которыми знак [code] мог быть описан.
List<String> _codeCandidates(String code) =>
    _fileCandidates(code.toLowerCase()).map((c) => c.toUpperCase()).toList();
