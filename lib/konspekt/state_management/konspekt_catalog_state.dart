import 'package:freezed_annotation/freezed_annotation.dart';

part 'konspekt_catalog_state.freezed.dart';

@freezed
sealed class KonspektCatalogState with _$KonspektCatalogState {
  const factory KonspektCatalogState({
    /// Ids of the categories that have a bundled konspekt.
    @Default({}) Set<String> categories,
  }) = _KonspektCatalogState;
}
