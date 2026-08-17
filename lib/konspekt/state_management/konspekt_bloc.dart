import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/core/network/error_messages.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_events.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_state.dart';

@injectable
class KonspektBloc extends Bloc<KonspektEvent, KonspektState> {
  KonspektBloc(
    this._repository,
    this._network,
    @factoryParam this.categoryId,
    @factoryParam this.initialSection,
  ) : super(const KonspektState()) {
    on<KonspektStarted>(_onStarted);
    on<KonspektSectionRequested>(_onSectionRequested);
    // Back online: fetch the document that could not be downloaded offline.
    _reconnectSubscription = _network.onReconnected.listen((_) {
      if (state.retryable && !state.inProgress) add(KonspektStarted());
    });
    add(KonspektStarted());
  }

  final KonspektRepository _repository;
  final NetworkStatus _network;
  StreamSubscription<void>? _reconnectSubscription;

  /// The category whose konspekt this page shows.
  final String categoryId;

  /// Section slug from the deep link (`/konspekt?category=..&section=..`).
  final String? initialSection;

  Future<void> _onStarted(KonspektStarted event, Emitter<KonspektState> emit) async {
    emit(
      state.copyWith(
        inProgress: true,
        errorMessage: null,
        retryable: false,
        offline: false,
      ),
    );
    final Konspekt? konspekt;
    try {
      konspekt = await _repository.load(categoryId);
    } catch (e) {
      // The konspekt lives on the backend now, so a download can fail: no
      // network, or no premium entitlement (the server enforces
      // `category_summaries` too). Both are "can't show it", not a crash.
      final denied = e is GraphqlException && e.code == 'access_denied';
      final offline = isNetworkError(e);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          inProgress: false,
          errorMessage: denied
              ? LocaleKeys.konspekt_unavailable.tr()
              : offline
              ? LocaleKeys.network_noConnection.tr()
              : LocaleKeys.konspekt_loadFailed.tr(),
          retryable: !denied,
          offline: offline,
        ),
      );
      return;
    }
    if (emit.isDone) return;
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

  @override
  Future<void> close() {
    _reconnectSubscription?.cancel();
    return super.close();
  }
}
