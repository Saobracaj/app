/// Whether a subcategory (block) id is the phantom "null" / empty block.
///
/// Block-less runs (the "recent mistakes" list, a saved question list) used to
/// reach the quiz through an address that interpolated a Dart `null`
/// (`subcategory=null`); the route took the literal string as a block id, and
/// every such run was recorded as a result for a block called "null" — visible
/// in the statistics and, through sync, in the group feed. Such an id describes
/// no real block: it is not recorded, not uploaded and not accepted back from
/// the server. Old links carrying it still live in browser history and
/// bookmarks, hence the check on the literal.
bool isPhantomSubcategory(Object? subcategory) {
  final value = subcategory?.toString().trim() ?? '';
  return value.isEmpty || value == 'null';
}
