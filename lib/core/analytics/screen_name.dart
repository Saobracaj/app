/// Turns a concrete routemaster path into the low-cardinality screen name sent
/// to analytics.
///
/// Screen names live in Google Analytics as enumerable dimensions; a raw path
/// like `/question/7923` or `/lists/3f2a.../q` would explode that dimension
/// into thousands of one-off values. Parameter segments are therefore replaced
/// with their route-template placeholders: any purely numeric segment (a
/// question id) and any segment that follows `question`, `lists`, `groups`,
/// `invite` or `threads` (see the route map in `lib/routes.dart`). Query
/// parameters are dropped entirely — question ids, invite codes and law
/// references all travel there.
String analyticsScreenName(String path) {
  final segments = Uri.parse(path)
      .pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return '/';
  const placeholderAfter = {
    'question': ':id',
    'lists': ':id',
    'groups': ':id',
    'invite': ':token',
    'threads': ':id',
  };
  final out = <String>[];
  for (var i = 0; i < segments.length; i++) {
    final placeholder = i > 0 ? placeholderAfter[segments[i - 1]] : null;
    if (placeholder != null) {
      out.add(placeholder);
    } else if (int.tryParse(segments[i]) != null) {
      out.add(':id');
    } else {
      out.add(segments[i]);
    }
  }
  return '/${out.join('/')}';
}
