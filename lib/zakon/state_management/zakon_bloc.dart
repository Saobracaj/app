import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/zakon_display.dart';

part 'zakon_bloc.freezed.dart';

class ZakonBloc extends Bloc<ZakonEvent, ZakonState> {
  final String? paragraph;
  final String? chlan;
  final String? chapter;
  final ZakonDataSource dataSource;

  ZakonBloc(
    this.paragraph,
    this.chlan,
    this.chapter, {
    ZakonDataSource? dataSource,
  }) : dataSource = dataSource ?? zakonOBezbednostiDataSource,
       super(ZakonState()) {
    on<Load>(_onLoad);
    on<ToggleLang>(_onToggleLang);
    on<ScrollTo>(_onScrollTo);
    add(Load());
  }

  void _onLoad(Load event, Emitter<ZakonState> emit) async {
    final paragraphs = await dataSource.paragraphs;
    emit(state.copyWith(
      zakon: paragraphs,
      rows: buildZakonDisplayRows(paragraphs),
    ));
    if (paragraph != null || chlan != null || chapter != null) {
      add(ScrollTo(paragraph, chlan, chapter));
    }
  }

  void _onToggleLang(ToggleLang event, Emitter<ZakonState> emit) {
    emit(state.copyWith(isSr: !state.isSr));
  }

  void _onScrollTo(ScrollTo event, Emitter<ZakonState> emit) {
    if (event.paragraph == null &&
        event.chlan == null &&
        event.chapter == null) {
      return; // No condition to match
    }
    bool matches(BezbParagraph element) {
      var condition = true;
      if (event.paragraph != null) {
        condition = condition && element.paragraph == event.paragraph;
      }
      if (event.chlan != null) {
        condition = condition && element.chlan == event.chlan;
      }
      if (event.chapter != null) {
        condition = condition && element.chapter == event.chapter;
      }
      return condition;
    }

    // Индекс ищется по строкам экрана: подпись, склеенная со строкой
    // картинок, всё ещё находится по своему адресу — ссылка ведёт на её блок.
    final index = state.rows.indexWhere(
      (r) => matches(r.row) || r.mergedCaptions.any(matches),
    );
    if (index != -1) {
      emit(state.copyWith(scrollTo: index));
      emit(state.copyWith(scrollTo: null));
    }
  }
}

sealed class ZakonEvent {}

class Load extends ZakonEvent {}

class ToggleLang extends ZakonEvent {}

class ScrollTo extends ZakonEvent {
  final String? paragraph;
  final String? chlan;
  final String? chapter;

  ScrollTo(this.paragraph, this.chlan, this.chapter);
}

@freezed
abstract class ZakonState with _$ZakonState {
  const factory ZakonState({
    @Default([]) List<BezbParagraph> zakon,
    // Те же строки, как их показывает экран: блоки «картинки + подписи»
    // правилника склеены в одну строку-таблицу (см. buildZakonDisplayRows).
    @Default([]) List<ZakonDisplayRow> rows,
    @Default(false) bool isBusy,
    @Default(true) bool isSr,
    String? errorMessage,
    int? scrollTo,
  }) = _ZakonState;
}
