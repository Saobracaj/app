import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';

/// Строка документа, как её показывает экран: строки-подписи («**II-43**»)
/// склеены со строкой картинок над ними, чтобы код стоял прямо под своим
/// знаком, а не столбцом ниже. Пары «картинка ↔ код» здесь те же, что и в
/// индексе знаков ([signCaptionsAt]) — сопоставление одно на всё приложение.
class ZakonDisplayRow {
  const ZakonDisplayRow({
    required this.row,
    this.signCodes = const [],
    this.mergedCaptions = const [],
  });

  final BezbParagraph row;

  /// Коды под картинками [row.images]: по одному на картинку в том же
  /// порядке, либо один общий на весь ряд (фото + рисунок одной таблы).
  /// Пусто — подписей у строки нет, ряд показывается без кодов.
  final List<String> signCodes;

  /// Склеенные строки-подписи: их адреса (`paragraph`) нужны, чтобы ссылка на
  /// подпись по-прежнему находила своё место в документе.
  final List<BezbParagraph> mergedCaptions;
}

/// Собирает строки экрана из строк документа. У закона (без картинок) выходит
/// один к одному; у правилника блоки «картинки + подписи» становятся одной
/// строкой-таблицей.
List<ZakonDisplayRow> buildZakonDisplayRows(List<BezbParagraph> rows) {
  final out = <ZakonDisplayRow>[];
  for (var i = 0; i < rows.length; i++) {
    final captions = signCaptionsAt(rows, i);
    // Подпись со своей картинкой (сетки допунских табли, где docx смешал
    // строки) склеивать нельзя — её картинка пропала бы с экрана.
    if (captions == null ||
        captions.captionRows.any((r) => r.images.isNotEmpty)) {
      out.add(ZakonDisplayRow(row: rows[i]));
      continue;
    }
    out.add(ZakonDisplayRow(
      row: rows[i],
      signCodes: captions.codes,
      mergedCaptions: captions.captionRows,
    ));
    i += captions.captionRows.length;
  }
  return out;
}
