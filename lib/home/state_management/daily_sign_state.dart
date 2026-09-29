import 'package:freezed_annotation/freezed_annotation.dart';

import '../../zakon/domain/road_sign_index.dart';

part 'daily_sign_state.freezed.dart';

@freezed
sealed class DailySignState with _$DailySignState {
  const factory DailySignState({
    /// Today's sign; `null` until the pravilnik index is built.
    RoadSignInfo? sign,

    /// Whether the name is shown (the card starts as a flashcard: sign only).
    @Default(false) bool revealed,
  }) = _DailySignState;
}
