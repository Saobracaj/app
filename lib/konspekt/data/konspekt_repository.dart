import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';

/// Loads bundled category konspekts (study notes) from `assets/konspekt/`.
@lazySingleton
class KonspektRepository {
  final Map<String, Konspekt> _cache = {};
  Set<String>? _available;

  /// Ids of the categories that ship a konspekt asset, discovered from the
  /// asset manifest so new `assets/konspekt/<id>.json` files are picked up
  /// without a code change.
  Future<Set<String>> availableCategories() async {
    if (_available != null) return _available!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _available = manifest
        .listAssets()
        .where((path) => path.startsWith('assets/konspekt/') && path.endsWith('.json'))
        .map((path) => path.split('/').last.replaceAll('.json', ''))
        .toSet();
    return _available!;
  }

  /// The konspekt for [categoryId], or `null` if none is bundled.
  Future<Konspekt?> load(String categoryId) async {
    final cached = _cache[categoryId];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/konspekt/$categoryId.json');
      final konspekt = Konspekt.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _cache[categoryId] = konspekt;
      return konspekt;
    } catch (_) {
      return null;
    }
  }
}
