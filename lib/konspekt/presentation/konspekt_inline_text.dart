import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Однострочный текст конспекта (заголовок секции, название словаря), в котором
/// автор пользуется той же инлайновой разметкой, что и в теле: сербские термины
/// выделены `*курсивом*`, важное — `**жирным**`.
///
/// Обычный [Text] показывал бы звёздочки как есть, поэтому строка проходит
/// через тот же markdown-движок, что и содержимое конспекта, но без блочных
/// отступов — визуально это по-прежнему один заголовок в стиле [style]
/// (выделение накладывается поверх него и размер шрифта не меняет).
class KonspektInlineText extends StatelessWidget {
  const KonspektInlineText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: false,
      styleSheet: MarkdownStyleSheet(p: style, pPadding: EdgeInsets.zero),
    );
  }
}
