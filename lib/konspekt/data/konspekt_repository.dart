import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source of category konspekts (study notes).
///
/// The konspekts used to ship inside the app bundle as `assets/konspekt/*.json`,
/// which meant a store release for every content fix. They now live in
/// `saobracaj_backend`: the catalog (`konspektCategories`) says which categories
/// have notes and at which version, and `konspekt(categoryId:)` returns the
/// document itself — premium content, so the backend enforces the
/// `category_summaries` flag on that query as well as the UI.
///
/// Both are cached in shared preferences and kept in memory for the session, so
/// a konspekt the user has already opened still opens offline. A cached
/// document is reused only while its version matches the catalog; a bumped
/// version re-downloads it.
@lazySingleton
class KonspektRepository {
  KonspektRepository(this._client);

  final GraphqlClient _client;

  static const _catalogKey = 'konspekt_catalog';
  static const _documentPrefix = 'konspekt_document.';

  final Map<String, Konspekt> _documents = {};

  /// `categoryId` → published document version, from the backend catalog.
  Map<String, int> _versions = {};
  bool _catalogLoaded = false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Ids of the categories that have a konspekt. Refreshed from the backend
  /// once per session; an offline start falls back to the cached catalog.
  Future<Set<String>> availableCategories() async => (await _catalog()).keys.toSet();

  /// The konspekt for [categoryId], or `null` if the backend has none.
  ///
  /// Throws whatever [GraphqlClient] throws when the document has to be
  /// downloaded and that fails (no session, no premium grant, no network) and
  /// nothing usable is cached — the caller turns it into a message.
  Future<Konspekt?> load(String categoryId) async {
    final loaded = _documents[categoryId];
    if (loaded != null) return loaded;

    final catalog = await _catalog();
    final cached = await _readCachedDocument(categoryId);
    // The catalog is the freshness oracle: an unchanged version means the
    // cached copy is still exactly what the backend would send.
    if (cached != null && cached.version == catalog[categoryId]) {
      _documents[categoryId] = cached.konspekt;
      return cached.konspekt;
    }

    try {
      final data = await _client.run(
        r'''
          query Konspekt($categoryId: String!) {
            konspekt(categoryId: $categoryId) { categoryId version document }
          }
        ''',
        variables: {'categoryId': categoryId},
        authenticated: true,
      );
      final raw = data['konspekt'];
      if (raw is! Map) return null;
      final document = raw['document'];
      if (document is! Map) return null;

      final konspekt = Konspekt.fromJson(document.cast<String, dynamic>());
      _documents[categoryId] = konspekt;
      unawaited(_cacheDocument(categoryId, raw['version'], document));
      return konspekt;
    } catch (_) {
      // Offline or a transient failure: a stale cached copy beats nothing.
      if (cached != null) {
        _documents[categoryId] = cached.konspekt;
        return cached.konspekt;
      }
      rethrow;
    }
  }

  /// The catalog, fetched once per session and cached across launches.
  Future<Map<String, int>> _catalog() async {
    if (_catalogLoaded) return _versions;
    _versions = await _readCachedCatalog();
    try {
      final data = await _client.run(
        'query KonspektCategories { konspektCategories { categoryId version } }',
      );
      final raw = data['konspektCategories'];
      if (raw is List) {
        final versions = <String, int>{};
        for (final entry in raw) {
          if (entry is! Map) continue;
          final id = entry['categoryId']?.toString();
          final version = entry['version'];
          if (id != null) versions[id] = version is int ? version : 1;
        }
        _versions = versions;
        unawaited(_cacheCatalog(versions));
      }
    } catch (_) {
      // Offline / server down — keep whatever the last launch saw.
    }
    _catalogLoaded = true;
    return _versions;
  }

  Future<Map<String, int>> _readCachedCatalog() async {
    try {
      final raw = (await _prefs).getString(_catalogKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(key.toString(), value is int ? value : 1));
    } catch (_) {
      return {};
    }
  }

  Future<void> _cacheCatalog(Map<String, int> versions) async {
    try {
      (await _prefs).setString(_catalogKey, jsonEncode(versions));
    } catch (_) {
      // Best-effort cache.
    }
  }

  Future<_CachedKonspekt?> _readCachedDocument(String categoryId) async {
    try {
      final raw = (await _prefs).getString('$_documentPrefix$categoryId');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final document = decoded['document'];
      if (document is! Map) return null;
      final version = decoded['version'];
      return _CachedKonspekt(
        version is int ? version : 1,
        Konspekt.fromJson(document.cast<String, dynamic>()),
      );
    } catch (_) {
      // A corrupt or outdated cache entry is not worth crashing over.
      return null;
    }
  }

  Future<void> _cacheDocument(String categoryId, Object? version, Map<dynamic, dynamic> document) async {
    try {
      (await _prefs).setString(
        '$_documentPrefix$categoryId',
        jsonEncode({'version': version is int ? version : 1, 'document': document}),
      );
    } catch (_) {
      // Best-effort cache.
    }
  }
}

/// A konspekt read back from the local cache, with the version it was stored at.
class _CachedKonspekt {
  const _CachedKonspekt(this.version, this.konspekt);

  final int version;
  final Konspekt konspekt;
}
