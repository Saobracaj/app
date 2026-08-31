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

/// Подписи под строкой картинок [i]: строки-подписи ниже читаются, пока кодов
/// меньше, чем картинок. Пара «картинка ↔ код» принимается только при точном
/// совпадении количества (или один общий код на весь ряд — фото + рисунок
/// одной таблы, как у IV-22); иначе null — этим же правилом пользуется и
/// дедупликация в tool/parse_pravilnik.py.
class SignCaptions {
  const SignCaptions({required this.codes, required this.captionRows});

  /// Коды в порядке картинок строки (либо один общий на весь ряд).
  final List<String> codes;

  /// Прочитанные строки-подписи — стоят сразу за строкой с картинками.
  final List<BezbParagraph> captionRows;
}

SignCaptions? signCaptionsAt(List<BezbParagraph> rows, int i) {
  final images = rows[i].images;
  if (images.isEmpty) return null;
  final codes = <String>[];
  final captionRows = <BezbParagraph>[];
  var j = i + 1;
  while (j < rows.length && codes.length < images.length) {
    final rowCodes = _captionCodes(rows[j].sr);
    if (rowCodes.isEmpty) break;
    codes.addAll(rowCodes);
    captionRows.add(rows[j]);
    j++;
  }
  if (codes.length != images.length &&
      !(codes.length == 1 && images.length > 1)) {
    return null;
  }
  return SignCaptions(codes: codes, captionRows: captionRows);
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
    final captions = signCaptionsAt(rows, i);
    // Подписи есть только под официальными SVG (по знаку на код). Рисунок,
    // оставшийся картинкой самого документа, показывает весь ряд знаков
    // пункта сразу, вместе с впечатанными кодами — коды для него читаются из
    // абзаца-описания над рисунком, ровно как их читает tool/parse_pravilnik.py.
    final codes = captions?.codes ?? _describedCodes(rows, i);
    if (codes.isEmpty) continue;
    final j = i + 1 + (captions?.captionRows.length ?? 0);
    for (var k = 0; k < codes.length; k++) {
      final code = codes[k];
      // В индексе только дорожные знаки (группы I–IV: опасность, наредбе,
      // обавештења, допунске табле): у разметки и семафоров (V и дальше)
      // другая структура описаний, и по ним никто не нажимает.
      if (!RegExp(r'^I{1,3}V?-').hasMatch(code)) continue;
      if (index.containsKey(code)) continue;
      final description = _findDescription(rows, i, j, code);
      index[code] = RoadSignInfo(
        code: code,
        // У ряда без подписей картинка одна на все коды пункта.
        asset: images[k < images.length ? k : images.length - 1].src,
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

/// Коды знаков, нарисованных на строке картинок [i], по абзацу-описанию над
/// ней: пункт называет их в скобках («допунске табле (IV-10), (IV-11) и
/// (IV-12)»), повторные упоминания того же кода отбрасываются. Если скобок в
/// абзаце нет вовсе, годятся любые упоминания кодов.
List<String> _describedCodes(List<BezbParagraph> rows, int i) {
  var j = i - 1;
  while (j >= 0 && (rows[j].sr ?? '').trim().isEmpty) {
    j--;
  }
  if (j < 0) return const [];
  final sr = rows[j].sr!;
  final paren = RegExp(r'\(\s*([IVX]{1,3}-\d+(?:\.\d+)*)')
      .allMatches(sr)
      .map((m) => m.group(1)!);
  final all = RegExp(r'[IVX]{1,3}-\d+(?:\.\d+)*')
      .allMatches(sr)
      .map((m) => m.group(0)!);
  return {...(paren.isEmpty ? all : paren)}.toList();
}

/// Код, вокруг которого не продолжается номер: «III-65» не должен находиться
/// ни внутри «III-65.2», ни внутри «VIII-65» — слева не должно быть римской
/// цифры (без lookbehind: старые Safari его не разбирают).
RegExp _codeToken(String code) =>
    RegExp('(?:^|[^IVX])${RegExp.escape(code)}(?![\\d.])');

/// Код в формате определения — сразу за открывающей скобкой: описание каждого
/// знака упоминает его как «(I-1)» или «(II-43), (II-43.1) и (II-43.2)».
RegExp _codeParen(String code) =>
    RegExp('\\(\\s*${RegExp.escape(code)}(?![\\d.])');

/// Абзац-описание знака [code]: из ближайших строк (кроме подписей) сначала
/// берётся та, что упоминает код в формате определения «({код})», затем — с
/// кодом без скобок («допунска табла IV-1, која…»), затем пункт перечня.
///
/// Правилник ставит описание ПЕРЕД рисунком («1) знак „кривина налево” (I-1)
/// … ;» и следом ряд знаков), поэтому окно сначала просматривается вверх от
/// строки картинок [image] и лишь потом вниз от [after] — на случай, когда
/// один абзац описывает несколько идущих подряд рядов (II-43…II-43.4).
/// Окно небольшое: искать «(код)» по всему документу нельзя, упоминания в
/// правилах установки («знак I-19 (радови на путу) поставља се…») стоят за
/// сотни строк от знака.
final _itemRe = RegExp(r'^\d+\)\s');

BezbParagraph? _findDescription(
  List<BezbParagraph> rows,
  int image,
  int after,
  String code,
) {
  final paren = _codeParen(code);
  final token = _codeToken(code);
  BezbParagraph? tokenHit;
  BezbParagraph? firstItem;

  void scan(Iterable<int> indexes) {
    for (final j in indexes) {
      final sr = (rows[j].sr ?? '').trim();
      if (sr.isEmpty || _captionCodes(sr).isNotEmpty) continue;
      if (tokenHit == null && token.hasMatch(sr)) tokenHit = rows[j];
      if (_itemRe.hasMatch(sr)) firstItem ??= rows[j];
    }
  }

  BezbParagraph? parenHit(Iterable<int> indexes) {
    for (final j in indexes) {
      final sr = (rows[j].sr ?? '').trim();
      if (sr.isEmpty || _captionCodes(sr).isNotEmpty) continue;
      if (paren.hasMatch(sr)) return rows[j];
    }
    return null;
  }

  final up = [
    for (var j = image - 1; j >= 0 && j > image - 15; j--) j,
  ];
  final down = [
    for (var j = after; j < rows.length && j < after + 15; j++) j,
  ];
  final hit = parenHit(up) ?? parenHit(down);
  if (hit != null) return hit;
  scan(up);
  scan(down);
  // Код рядом не упомянут вовсе (в docx бывают опечатки вроде «lV-8.2» со
  // строчной L) — берём ближайший пункт перечня: он и есть описание блока.
  return tokenHit ?? firstItem;
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
  ///
  /// [documentCode] — точный код знака из подписи самого правилника (его
  /// передаёт экран документа, где пары «картинка ↔ код» известны): поиск по
  /// нему первичен, потому что имя файла может значить другой знак (нумерации
  /// 2010 и 2017 годов разошлись), а один файл — стоять в документе под
  /// несколькими кодами.
  static Future<RoadSignInfo?> find(String sign, {String? documentCode}) async {
    _index ??= pravilnikDataSource.paragraphs.then(buildRoadSignIndex);
    final data = await _index!;
    if (documentCode != null) {
      final exact = data.byCode[documentCode];
      if (exact != null) return exact;
    }
    return lookupRoadSign(data, sign);
  }

  /// Сброс кэша для тестов: Future, рождённый в фейковой зоне одного
  /// widget-теста, в зоне следующего уже не дождаться.
  @visibleForTesting
  static void reset() {
    _index = null;
  }
}

/// Файлы assets/signs/, названные по нумерации правилника 2010 года: рядом с
/// ними лежит файл «<код>-2017.svg» — тот же номер, но ДРУГОЙ знак. Документ
/// теперь 2017 года, поэтому его код такому файлу не подходит: описание было
/// бы от чужого знака (так «предзнак за обилазак» объяснялся бы «опасном
/// деоницом пута»). Годится только совпадение по самому файлу.
///
/// Список проверяет test/road_sign_index_test.dart: он же и выводится —
/// плоское имя файла попадает сюда ровно тогда, когда у него есть двойник
/// «-2017». Особняком «e75-srb»: ознака европског пута, номера в правилнике
/// 2017 года у неё нет вовсе.
const legacy2010Files = {
  'iii-8',
  'iii-25',
  'iii-85',
  'iii-85-1', // вариант того же знака 2010 года
  'iii-86',
  'iii-92',
  'e75-srb',
};

/// Файлы assets/signs/, чьё имя значит в этом документе ДРУГОЙ знак: имена
/// идут по нумерации Викисклада, а она местами разошлась с правилником 2017
/// года (файл iii-54.svg — «стање пролаза», а III-54 документа — WC). Искать
/// описание по коду из имени таким файлам нельзя: оно пришло бы от чужого
/// знака. Тем, что стоят в самом документе (под своим настоящим кодом),
/// описание всё равно находится по файлу — запрет касается только отката.
///
/// Список выведен из CODE_OVERRIDES и WRONG_SIGN в tool/parse_pravilnik.py:
/// это их коды, у которых есть одноимённый файл. Синхронность проверяет
/// test/road_sign_index_test.dart.
const misnumberedFiles = {
  'iii-4',
  'iii-12',
  'iii-13',
  'iii-21',
  'iii-22',
  'iii-54',
  'iii-55',
  'iii-57',
  'iii-69',
  'iii-69.1',
  'iii-71',
  'iii-76',
  'iii-79',
  'iii-83',
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
/// 3. **по коду** — на случай, когда знак показан картинкой самого документа
///    (официального SVG у него нет) и по файлу не сходится. Нумерация файлов
///    и документа теперь одна (правилник 2017 года), так что код годится
///    почти всем; запрещено для [legacy2010Files] и [misnumberedFiles] и там,
///    где у кода документа свой официальный файл: раз он другой, знаки разные.
///
/// Знаки с суффиксом «-2017» (образец 2017 года там, где базовое имя занято
/// знаком 2010-го) базового знака не ищут: «iii-25-2017» и «III-25» — разные
/// знаки.
RoadSignInfo? lookupRoadSign(RoadSignIndexData index, String sign) {
  final file = sign.toLowerCase();
  final exact = index.byAsset['assets/signs/$file.svg'];
  if (exact != null) return exact;
  for (final candidate in _fileCandidates(file).skip(1)) {
    final hit = index.byAsset['assets/signs/$candidate.svg'];
    if (hit != null) return hit;
  }
  if (file.endsWith('-2017')) return null;
  if (legacy2010Files.contains(file) || misnumberedFiles.contains(file)) {
    return null;
  }
  for (final candidate in _codeCandidates(file.toUpperCase())) {
    final hit = index.byCode[candidate];
    if (hit == null) continue;
    // У кода свой официальный файл, и он не наш (иначе сработал бы поиск по
    // файлу) — значит, это другой знак. Исключение — файл из семейства нашего
    // же знака: у «ii-30-blank» код II-30 показывает официальный «ii-30-40»,
    // и описание у них общее.
    if (hit.asset.startsWith('assets/signs/')) {
      final hitFile = hit.asset
          .substring('assets/signs/'.length)
          .replaceAll('.svg', '');
      final related = _fileCandidates(hitFile)
          .toSet()
          .intersection(_fileCandidates(file).toSet());
      if (related.isEmpty) continue;
    }
    return hit;
  }
  return null;
}

/// Имена файлов, чьё описание годится знаку [file]: он сам и базовые знаки
/// его семейства.
List<String> _fileCandidates(String file) {
  if (file.endsWith('-2017')) return [file];
  // Отрезается только суффикс варианта: базовое имя обязано остаться
  // номером знака («ii-30-40» → «ii-30»). Без этого «iii-25» разбиралось бы
  // на «iii», и любые два знака группы считались бы роднёй — описание
  // путоказа iii-12 приходило бы от «престанка забране претицања».
  final numeric = RegExp(r'^(.+-\d+)-(\d+)$').firstMatch(file);
  final letters = RegExp(r'^(.+\d)[a-z]+$').firstMatch(file);
  final suffixed = RegExp(r'^(.+-\d+)-[a-z0-9]+$').firstMatch(file);
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
