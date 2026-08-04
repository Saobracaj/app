import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_events.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_state.dart';

@injectable
class KonspektBloc extends Bloc<KonspektEvent, KonspektState> {
  KonspektBloc(
    this._repository,
    @factoryParam this.categoryId,
    @factoryParam this.initialSection,
  ) : super(const KonspektState()) {
    on<KonspektStarted>(_onStarted);
    on<KonspektSectionRequested>(_onSectionRequested);
    add(KonspektStarted());
  }

  final KonspektRepository _repository;

  /// The category whose konspekt this page shows.
  final String categoryId;

  /// Section slug from the deep link (`/konspekt?category=..&section=..`).
  final String? initialSection;

  Future<void> _onStarted(KonspektStarted event, Emitter<KonspektState> emit) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    final konspekt = await _repository.load(categoryId);
    if (konspekt == null) {
      emit(state.copyWith(inProgress: false, errorMessage: LocaleKeys.konspekt_notFound.tr()));
      return;
    }
    emit(state.copyWith(inProgress: false, konspekt: konspekt));
    final section = initialSection;
    if (section != null) {
      add(KonspektSectionRequested(section));
    }
  }

  void _onSectionRequested(KonspektSectionRequested event, Emitter<KonspektState> emit) {
    final index = state.indexOfSection(event.sectionId);
    if (index == null) return;
    // One-shot signal, same pattern as ZakonBloc.scrollTo.
    emit(state.copyWith(scrollTo: index));
    emit(state.copyWith(scrollTo: null));
  }
}
