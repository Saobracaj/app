/// Marking phrases inside question/answer markdown so that [QuestMarkdown]
/// can render them with a highlighter background.
///
/// The texts that reach the question screen are plain Serbian sentences that
/// `String.dict` has already turned into markdown by wrapping dictionary terms
/// in `[term](dict/…)` links. A highlight is expressed in that same markdown
/// as a `~~…~~` span (rendered through the `del` style slot, see
/// `QuestMarkdown`); the only care needed is not to open a span outside a link
/// and close it inside one — the markdown parser reads link text as its own
/// nested inline run, so such a pair would never match and the tildes would
/// show up literally. Highlights are therefore snapped outwards to link
/// boundaries: a dictionary term is at most a few words, so highlighting the
/// whole term instead of a part of it costs nothing a reader would notice.
library;

/// A phrase to highlight, in the form the analytics asset stores it: lower
/// case, words separated by single spaces, no punctuation. Matching is by whole
/// words, case-insensitive; [whole] restricts it to a text that consists of
/// exactly this phrase (a whole-answer cue must not light up a longer option
/// that merely contains the same words).
class PhraseHighlight {
  const PhraseHighlight(this.phrase, {this.whole = false});

  final String phrase;
  final bool whole;

  @override
  bool operator ==(Object other) =>
      other is PhraseHighlight &&
      other.phrase == phrase &&
      other.whole == whole;

  @override
  int get hashCode => Object.hash(phrase, whole);

  @override
  String toString() => 'PhraseHighlight($phrase${whole ? ', whole' : ''})';
}

/// Returns [markdown] with every occurrence of [highlights] wrapped in
/// `~~…~~`. Overlapping matches merge into one span; a match that would cut a
/// `[…](…)` link is widened to cover the link. Text without a match is
/// returned unchanged.
String markPhrases(String markdown, Iterable<PhraseHighlight> highlights) {
  final wanted = highlights.toList();
  if (wanted.isEmpty || markdown.isEmpty) return markdown;

  final layout = _VisibleText.of(markdown);
  final tokens = _tokens(layout.text);
  if (tokens.isEmpty) return markdown;

  final ranges = <_Range>[];
  for (final highlight in wanted) {
    final words = highlight.phrase
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) continue;
    if (highlight.whole) {
      if (_matchesAt(tokens, 0, words) && tokens.length == words.length) {
        ranges.add(_Range(tokens.first.start, tokens.last.end));
      }
      continue;
    }
    for (var i = 0; i + words.length <= tokens.length; i++) {
      if (_matchesAt(tokens, i, words)) {
        ranges.add(_Range(tokens[i].start, tokens[i + words.length - 1].end));
      }
    }
  }
  if (ranges.isEmpty) return markdown;

  // A `del` span cannot cross a paragraph break — a match over one is dropped
  // rather than left as literal tildes.
  ranges.removeWhere(
    (r) => layout.text.substring(r.start, r.end).contains('\n'),
  );

  final snapped = [for (final r in ranges) layout.snapToLinks(r)]
    ..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Range>[];
  for (final r in snapped) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      merged.last = _Range(
        merged.last.start,
        r.end > merged.last.end ? r.end : merged.last.end,
      );
    } else {
      merged.add(r);
    }
  }

  final out = StringBuffer();
  var cursor = 0;
  for (final r in merged) {
    final from = layout.sourceStart(r.start);
    final to = layout.sourceEnd(r.end);
    out
      ..write(markdown.substring(cursor, from))
      ..write('~~')
      ..write(markdown.substring(from, to))
      ..write('~~');
    cursor = to;
  }
  out.write(markdown.substring(cursor));
  return out.toString();
}

bool _matchesAt(List<_Token> tokens, int at, List<String> words) {
  for (var k = 0; k < words.length; k++) {
    if (tokens[at + k].text != words[k]) return false;
  }
  return true;
}

class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;
}

class _Token {
  const _Token(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

// The same notion of a "word" as `tool/question_analytics.py` (`\w+`): letters,
// digits and the underscore, in any script.
final _word = RegExp(r'[\p{L}\p{N}_]+', unicode: true);

List<_Token> _tokens(String text) => [
  for (final m in _word.allMatches(text))
    _Token(m.group(0)!.toLowerCase(), m.start, m.end),
];

/// A markdown link's place in the visible text and in the source.
class _Link {
  const _Link({
    required this.visibleStart,
    required this.visibleEnd,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final int visibleStart;
  final int visibleEnd;
  final int sourceStart;
  final int sourceEnd;
}

/// The reader-visible text of a markdown string with a map back to the source:
/// link labels count as visible, link targets and images do not.
class _VisibleText {
  _VisibleText._(this.text, this._sourceOf, this._links);

  final String text;

  /// Source offset of every visible character.
  final List<int> _sourceOf;
  final List<_Link> _links;

  static final _linkOrImage = RegExp(r'(!?)\[([^\]]*)\]\(([^)]*)\)');

  factory _VisibleText.of(String markdown) {
    final buffer = StringBuffer();
    final sourceOf = <int>[];
    final links = <_Link>[];
    var cursor = 0;
    void copyPlain(int from, int to) {
      for (var i = from; i < to; i++) {
        buffer.write(markdown[i]);
        sourceOf.add(i);
      }
    }

    for (final m in _linkOrImage.allMatches(markdown)) {
      copyPlain(cursor, m.start);
      if (m.group(1)!.isEmpty) {
        final label = m.group(2)!;
        final labelStart = m.start + 1;
        links.add(
          _Link(
            visibleStart: buffer.length,
            visibleEnd: buffer.length + label.length,
            sourceStart: m.start,
            sourceEnd: m.end,
          ),
        );
        copyPlain(labelStart, labelStart + label.length);
      }
      cursor = m.end;
    }
    copyPlain(cursor, markdown.length);
    return _VisibleText._(buffer.toString(), sourceOf, links);
  }

  /// Widens [range] so that it never starts or ends strictly inside a link.
  _Range snapToLinks(_Range range) {
    var start = range.start;
    var end = range.end;
    for (final link in _links) {
      if (start > link.visibleStart && start < link.visibleEnd) {
        start = link.visibleStart;
      }
      if (end > link.visibleStart && end < link.visibleEnd) {
        end = link.visibleEnd;
      }
    }
    return _Range(start, end);
  }

  /// Source offset at which a span starting at visible [index] must open —
  /// before the `[` when the span starts on a link.
  int sourceStart(int index) {
    for (final link in _links) {
      if (link.visibleStart == index) return link.sourceStart;
    }
    return _sourceOf[index];
  }

  /// Source offset at which a span ending at visible [index] (exclusive) must
  /// close — after the `)` when the span ends on a link.
  int sourceEnd(int index) {
    for (final link in _links) {
      if (link.visibleEnd == index) return link.sourceEnd;
    }
    return _sourceOf[index - 1] + 1;
  }
}
