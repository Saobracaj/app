import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_events.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_state.dart';

/// Knows which categories have a konspekt, so list screens can decide whether
/// to show the "open konspekt" button next to a category header.
@injectable
class KonspektCatalogBloc extends Bloc<KonspektCatalogEvent, KonspektCatalogState> {
  KonspektCatalogBloc(this._repository) : super(const KonspektCatalogState()) {
    on<KonspektCatalogStarted>(_onStarted);
    add(KonspektCatalogStarted());
  }

  final KonspektRepository _repository;

  Future<void> _onStarted(KonspektCatalogStarted event, Emitter<KonspektCatalogState> emit) async {
    final categories = await _repository.availableCategories();
    emit(state.copyWith(categories: categories));
  }
}
