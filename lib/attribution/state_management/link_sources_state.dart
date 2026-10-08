import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/link_source.dart';

part 'link_sources_state.freezed.dart';

/// За какой период показывать воронку: когорта кликов, сделанных за него.
enum StatsPeriod {
  allTime(null),
  days30(30),
  days7(7);

  const StatsPeriod(this.days);

  /// Длина периода в днях; `null` — за всё время.
  final int? days;

  DateTime? since(DateTime now) =>
      days == null ? null : now.subtract(Duration(days: days!));
}

/// Админка источников ссылок: список, воронка каждого и формы.
@freezed
abstract class LinkSourcesState with _$LinkSourcesState {
  const factory LinkSourcesState({
    @Default(true) bool loading,
    @Default(<LinkSource>[]) List<LinkSource> sources,

    /// Воронки по id источника; источника без кликов здесь нет.
    @Default(<String, LinkSourceStats>{}) Map<String, LinkSourceStats> stats,
    @Default(StatsPeriod.allTime) StatsPeriod period,
    @Default(false) bool showArchived,

    /// Идёт мутация — кнопки форм на это время выключены.
    @Default(false) bool submitting,

    /// Только что созданный источник — экран показывает его ссылку.
    LinkSource? created,

    /// Одноразовые сообщения для снэкбара.
    String? errorMessage,
    String? infoMessage,
  }) = _LinkSourcesState;

  const LinkSourcesState._();

  LinkSourceStats statsOf(String sourceId) =>
      stats[sourceId] ?? LinkSourceStats.empty;
}
