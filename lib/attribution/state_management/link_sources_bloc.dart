import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../generated/locale_keys.g.dart';
import '../data/attribution_repository.dart';
import '../models/link_source.dart';
import 'link_sources_events.dart';
import 'link_sources_state.dart';

/// Источники ссылок (`/go/<код>`) и их воронка: переходы → открытия
/// приложения (новые установки и уже установленные) → регистрации → покупки.
/// Экран виден держателям `manage_attribution`; право проверяет бэкенд на
/// каждом запросе.
@injectable
class LinkSourcesBloc extends Bloc<LinkSourcesEvent, LinkSourcesState> {
  LinkSourcesBloc(this._repository, {@ignoreParam DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const LinkSourcesState()) {
    on<LinkSourcesStarted>((e, emit) => _load(emit));
    on<LinkSourcesRefreshed>((e, emit) => _load(emit));
    on<LinkSourcesPeriodChanged>(_onPeriodChanged);
    on<LinkSourcesArchivedShown>(_onArchivedShown);
    on<LinkSourceCreated>(_onCreated);
    on<LinkSourceEdited>(_onEdited);
    on<LinkSourceArchiveToggled>(_onArchiveToggled);
    on<LinkSourceCreatedShown>(
      (e, emit) => emit(_clean().copyWith(created: null)),
    );
  }

  final AttributionRepository _repository;
  final DateTime Function() _clock;

  Future<void> _load(Emitter<LinkSourcesState> emit) async {
    emit(_clean().copyWith(loading: true));
    try {
      final sources = await _repository.linkSources(
        includeArchived: state.showArchived,
      );
      final stats = await _repository.linkSourceStats(
        since: state.period.since(_clock()),
      );
      emit(state.copyWith(loading: false, sources: sources, stats: stats));
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onPeriodChanged(
    LinkSourcesPeriodChanged event,
    Emitter<LinkSourcesState> emit,
  ) async {
    if (event.period == state.period) return;
    emit(_clean().copyWith(period: event.period));
    try {
      final stats = await _repository.linkSourceStats(
        since: event.period.since(_clock()),
      );
      emit(state.copyWith(stats: stats));
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  Future<void> _onArchivedShown(
    LinkSourcesArchivedShown event,
    Emitter<LinkSourcesState> emit,
  ) async {
    if (event.show == state.showArchived) return;
    emit(_clean().copyWith(showArchived: event.show));
    await _load(emit);
  }

  Future<void> _onCreated(
    LinkSourceCreated event,
    Emitter<LinkSourcesState> emit,
  ) async {
    emit(_clean().copyWith(submitting: true));
    try {
      final source = await _repository.createLinkSource(
        name: event.name.trim(),
        description: event.description.trim(),
        code: event.code,
        targetPath: event.targetPath,
      );
      emit(
        state.copyWith(
          submitting: false,
          sources: [source, ...state.sources],
          created: source,
        ),
      );
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onEdited(
    LinkSourceEdited event,
    Emitter<LinkSourcesState> emit,
  ) async {
    emit(_clean().copyWith(submitting: true));
    try {
      final source = await _repository.updateLinkSource(
        event.id,
        name: event.name.trim(),
        description: event.description.trim(),
        targetPath: event.targetPath,
      );
      emit(
        state.copyWith(
          submitting: false,
          sources: _replace(source),
          infoMessage: LocaleKeys.linkSources_saved.tr(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onArchiveToggled(
    LinkSourceArchiveToggled event,
    Emitter<LinkSourcesState> emit,
  ) async {
    emit(_clean().copyWith(submitting: true));
    try {
      final source = await _repository.setArchived(
        event.id,
        archived: event.archived,
      );
      final sources = source.archived && !state.showArchived
          ? [
              for (final s in state.sources)
                if (s.id != source.id) s,
            ]
          : _replace(source);
      emit(
        state.copyWith(
          submitting: false,
          sources: sources,
          infoMessage: source.archived
              ? LocaleKeys.linkSources_archivedDone.tr()
              : LocaleKeys.linkSources_restoredDone.tr(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  List<LinkSource> _replace(LinkSource source) => [
    for (final s in state.sources) s.id == source.id ? source : s,
  ];

  /// Состояние без одноразовых сообщений прошлого шага.
  LinkSourcesState _clean() =>
      state.copyWith(errorMessage: null, infoMessage: null);

  String _message(Object e) {
    if (e is GraphqlException) {
      if (e.code == 'link_code_taken') {
        return LocaleKeys.linkSources_codeTaken.tr();
      }
      return e.message;
    }
    return LocaleKeys.linkSources_requestFailed.tr();
  }
}
