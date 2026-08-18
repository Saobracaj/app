/// Merging several GraphQL queries into a single document.
///
/// A GraphQL operation may ask for any number of root fields at once, and the
/// server resolves them concurrently — so `me`, `featureFlags`,
/// `myQuestionLists` and `myGroups`, which the app fires within a few
/// milliseconds of each other on startup, can travel as **one** request
/// instead of four (four TLS round trips, four token verifications, four
/// context builds).
///
/// The merge is textual and deliberately conservative: an operation is only
/// batchable when it is a plain `query` with no fragments and no operation-level
/// directives (see [parseBatchableQuery], which answers `null` for everything
/// else — mutations included, since merging side effects is a different
/// problem). Every batched operation gets a namespace prefix (`_b0_`, `_b1_`,
/// …) that is applied to
///
/// * each root field, as an alias — `me` becomes `_b0_me: me`, so two
///   operations asking for the same field keep separate answers, and
/// * each variable — `$id` becomes `$_b1_id`, in both the definitions and the
///   selection set, so identically named variables cannot collide.
///
/// Splitting the answer is then just stripping that prefix off the keys of
/// `data`, and routing each error by the first element of its `path`.
library;

/// The namespace of the operation at [index] inside a batch.
String batchPrefix(int index) => '_b${index}_';

/// A query that passed [parseBatchableQuery] and can be rendered into a batch.
///
/// Parsing records offsets only, so the same instance can be rendered under any
/// prefix (its position in a batch is not known until the batch is flushed).
class BatchableQuery {
  BatchableQuery._(
    this.source,
    this._varDefsStart,
    this._varDefsEnd,
    this._bodyStart,
    this._bodyEnd,
    this._variableOffsets,
    this._rootFields,
  );

  /// The original document, unchanged.
  final String source;

  /// Range of the variable definitions, *inside* the parentheses.
  final int? _varDefsStart;
  final int? _varDefsEnd;

  /// Offsets of the operation's outermost `{` and of the character past its `}`.
  final int _bodyStart;
  final int _bodyEnd;

  /// Offset just after every `$` that introduces a variable name.
  final List<int> _variableOffsets;

  final List<_RootField> _rootFields;

  /// Whether the operation declares variables (and therefore contributes to the
  /// batch's variable definitions).
  bool get hasVariables => _varDefsStart != null;

  /// The response keys this operation's root fields answer under, before
  /// namespacing — used to check nothing was lost when splitting the answer.
  List<String> get responseKeys => [
    for (final field in _rootFields) field.responseKey,
  ];

  /// The variable definitions namespaced with [prefix], without the parentheses.
  String variableDefinitions(String prefix) =>
      _render(_varDefsStart!, _varDefsEnd!, prefix);

  /// The selection set namespaced with [prefix], without the outer braces:
  /// every root field aliased, every variable renamed.
  String selections(String prefix) =>
      _render(_bodyStart + 1, _bodyEnd - 1, prefix);

  String _render(int start, int end, String prefix) {
    final edits = <_Edit>[
      for (final offset in _variableOffsets)
        if (offset >= start && offset < end) _Edit(offset, offset, prefix),
      for (final field in _rootFields)
        if (field.start >= start && field.start < end) field.edit(prefix),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final out = StringBuffer();
    var cursor = start;
    for (final edit in edits) {
      out.write(source.substring(cursor, edit.start));
      out.write(edit.text);
      cursor = edit.end;
    }
    out.write(source.substring(cursor, end));
    return out.toString();
  }
}

/// A replacement of `source[start, end)` with [text]; an insertion when
/// `start == end`.
class _Edit {
  const _Edit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

/// One root field of a batchable operation. [start]–[end] covers the alias when
/// the field already has one (it is replaced), otherwise both point at the
/// field name (the alias is inserted in front of it).
class _RootField {
  const _RootField(this.start, this.end, this.responseKey, this.aliased);

  final int start;
  final int end;
  final String responseKey;
  final bool aliased;

  _Edit edit(String prefix) => aliased
      ? _Edit(start, end, '$prefix$responseKey')
      : _Edit(start, start, '$prefix$responseKey: ');
}

/// The document and variables of a flushed batch.
class MergedBatch {
  const MergedBatch(this.query, this.variables, this.prefixes);

  final String query;
  final Map<String, dynamic> variables;

  /// The namespace of each merged operation, in the order they were given.
  final List<String> prefixes;
}

/// Merges [queries] (already parsed) with their [variables] into one document.
///
/// The lists must be the same length; the result's `prefixes[i]` is the
/// namespace of `queries[i]`.
MergedBatch mergeBatchableQueries(
  List<BatchableQuery> queries,
  List<Map<String, dynamic>> variables,
) {
  assert(queries.length == variables.length);
  final prefixes = [for (var i = 0; i < queries.length; i++) batchPrefix(i)];
  final definitions = <String>[];
  final selections = <String>[];
  final merged = <String, dynamic>{};

  for (var i = 0; i < queries.length; i++) {
    final prefix = prefixes[i];
    if (queries[i].hasVariables) {
      definitions.add(queries[i].variableDefinitions(prefix).trim());
    }
    selections.add(queries[i].selections(prefix).trim());
    variables[i].forEach((key, value) => merged['$prefix$key'] = value);
  }

  final header = definitions.isEmpty
      ? 'query _Batch'
      : 'query _Batch(${definitions.join(', ')})';
  return MergedBatch(
    '$header {\n${selections.join('\n')}\n}',
    merged,
    prefixes,
  );
}

/// The part of a batched `data` payload that belongs to [prefix], with the
/// namespace stripped back off. `null` when the operation contributed no key at
/// all — its result was swallowed by an error somewhere else in the batch, so
/// it has to be asked for again on its own.
Map<String, dynamic>? extractBatchData(dynamic data, String prefix) {
  if (data is! Map) return null;
  final out = <String, dynamic>{};
  data.forEach((key, value) {
    final name = key.toString();
    if (name.startsWith(prefix)) out[name.substring(prefix.length)] = value;
  });
  return out.isEmpty ? null : out;
}

/// The index of the batched operation an error belongs to, read off the first
/// element of its `path`; `null` when the error names no operation (a parse or
/// validation failure — it condemns the whole document, not one field).
int? batchErrorOwner(dynamic error, List<String> prefixes) {
  if (error is! Map) return null;
  final path = error['path'];
  if (path is! List || path.isEmpty) return null;
  final head = path.first?.toString();
  if (head == null) return null;
  for (var i = 0; i < prefixes.length; i++) {
    if (head.startsWith(prefixes[i])) return i;
  }
  return null;
}

/// Parses [query] and returns it as a [BatchableQuery], or `null` when it must
/// not be merged: anything that is not a single plain `query` operation
/// (mutations, subscriptions, documents with fragments, operation-level
/// directives, root-level fragment spreads) and anything this small parser
/// cannot make sense of.
BatchableQuery? parseBatchableQuery(String query) {
  final scanner = _Scanner(query);
  scanner.skipIgnored();
  if (scanner.atEnd) return null;

  // Operation type: either the shorthand `{ … }` or an explicit `query`.
  if (!scanner.peekChar('{')) {
    if (scanner.readName() != 'query') return null;
    // Optional operation name.
    if (!scanner.peekChar('(') && !scanner.peekChar('{')) {
      if (scanner.readName() == null) return null;
    }
  }

  int? varDefsStart;
  int? varDefsEnd;
  if (scanner.peekChar('(')) {
    final open = scanner.pos;
    if (!scanner.skipBalanced('(', ')')) return null;
    varDefsStart = open + 1;
    varDefsEnd = scanner.pos - 1;
  }

  // Operation-level directives would have to be merged too — bail instead.
  if (scanner.peekChar('@')) return null;
  if (!scanner.peekChar('{')) return null;

  final bodyStart = scanner.pos;
  scanner.pos++; // consume '{'
  final rootFields = <_RootField>[];
  while (true) {
    scanner.skipIgnored();
    if (scanner.pos >= query.length) return null;
    if (query[scanner.pos] == '}') {
      scanner.pos++;
      break;
    }
    // A root-level fragment spread or inline fragment has no response key of
    // its own to alias.
    if (query.startsWith('...', scanner.pos)) return null;

    final nameStart = scanner.pos;
    final first = scanner.readName();
    if (first == null) return null;
    final nameEnd = scanner.pos;

    var responseKey = first;
    var aliased = false;
    if (scanner.peekChar(':')) {
      scanner.pos++; // consume ':'
      if (scanner.readName() == null) return null;
      aliased = true;
      responseKey = first;
    }
    if (scanner.peekChar('(') && !scanner.skipBalanced('(', ')')) return null;
    while (scanner.peekChar('@')) {
      scanner.pos++; // consume '@'
      if (scanner.readName() == null) return null;
      if (scanner.peekChar('(') && !scanner.skipBalanced('(', ')')) return null;
    }
    if (scanner.peekChar('{') && !scanner.skipBalanced('{', '}')) return null;

    rootFields.add(
      _RootField(
        nameStart,
        aliased ? nameEnd : nameStart,
        responseKey,
        aliased,
      ),
    );
  }
  final bodyEnd = scanner.pos;
  if (rootFields.isEmpty) return null;

  // Anything after the operation is a second operation or a fragment
  // definition; both are out of scope.
  scanner.skipIgnored();
  if (scanner.pos != query.length) return null;

  return BatchableQuery._(
    query,
    varDefsStart,
    varDefsEnd,
    bodyStart,
    bodyEnd,
    _variableOffsets(query),
    rootFields,
  );
}

/// Offsets just after every `$` that starts a variable name, skipping the ones
/// inside strings and comments.
List<int> _variableOffsets(String source) {
  final offsets = <int>[];
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char == '#') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (char == '"') {
      i = _endOfString(source, i);
      continue;
    }
    if (char == r'$') {
      final nameStart = i + 1;
      var end = nameStart;
      while (end < source.length && _isNameChar(source.codeUnitAt(end))) {
        end++;
      }
      if (end > nameStart) offsets.add(nameStart);
      i = end;
      continue;
    }
    i++;
  }
  return offsets;
}

/// The offset just past the string literal starting at [start] (a `"` or the
/// opening `"""` of a block string).
int _endOfString(String source, int start) {
  if (source.startsWith('"""', start)) {
    var i = start + 3;
    while (i < source.length) {
      if (source[i] == r'\') {
        i += 2;
        continue;
      }
      if (source.startsWith('"""', i)) return i + 3;
      i++;
    }
    return source.length;
  }
  var i = start + 1;
  while (i < source.length) {
    final char = source[i];
    if (char == r'\') {
      i += 2;
      continue;
    }
    i++;
    if (char == '"') return i;
    if (char == '\n') return i; // unterminated — stop at the line break
  }
  return source.length;
}

bool _isNameStart(int code) =>
    (code >= 0x41 && code <= 0x5A) || // A-Z
    (code >= 0x61 && code <= 0x7A) || // a-z
    code == 0x5F; // _

bool _isNameChar(int code) =>
    _isNameStart(code) || (code >= 0x30 && code <= 0x39); // 0-9

/// A cursor over a GraphQL document with just enough of the grammar to find the
/// pieces [parseBatchableQuery] rewrites.
class _Scanner {
  _Scanner(this.source);

  final String source;
  int pos = 0;

  /// Whitespace, commas (insignificant in GraphQL) and `#` comments.
  void skipIgnored() {
    while (pos < source.length) {
      final char = source[pos];
      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == ',' ||
          char == '\uFEFF') {
        pos++;
        continue;
      }
      if (char == '#') {
        while (pos < source.length && source[pos] != '\n') {
          pos++;
        }
        continue;
      }
      break;
    }
  }

  bool get atEnd {
    skipIgnored();
    return pos >= source.length;
  }

  String? readName() {
    skipIgnored();
    if (pos >= source.length || !_isNameStart(source.codeUnitAt(pos))) {
      return null;
    }
    final start = pos;
    pos++;
    while (pos < source.length && _isNameChar(source.codeUnitAt(pos))) {
      pos++;
    }
    return source.substring(start, pos);
  }

  bool peekChar(String char) {
    skipIgnored();
    return pos < source.length && source[pos] == char;
  }

  /// Skips a balanced `open`…`close` pair starting at the cursor, ignoring the
  /// brackets that appear inside strings and comments. Answers `false` when the
  /// document ends first.
  bool skipBalanced(String open, String close) {
    if (!peekChar(open)) return false;
    pos++;
    var depth = 1;
    while (pos < source.length) {
      final char = source[pos];
      if (char == '#') {
        while (pos < source.length && source[pos] != '\n') {
          pos++;
        }
        continue;
      }
      if (char == '"') {
        pos = _endOfString(source, pos);
        continue;
      }
      if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        pos++;
        if (depth == 0) return true;
        continue;
      }
      pos++;
    }
    return false;
  }
}
