import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/test_push_result.dart';

part 'test_push_state.freezed.dart';

/// Состояние экрана «Тестовый пуш».
///
/// Форма из четырёх полей: почта получателя, заголовок, текст и ссылка
/// (deep link, который откроется по нажатию на уведомление). Пустые заголовок и
/// текст — это не ошибка: бэкенд подставит свои значения по умолчанию.
@freezed
abstract class TestPushState with _$TestPushState {
  const factory TestPushState({
    @Default('') String email,
    @Default('') String title,
    @Default('') String body,
    @Default('') String link,
    @Default(false) bool sending,

    /// Результат последней успешной отправки — показывается плашкой под формой.
    TestPushResult? result,
    String? errorMessage,
  }) = _TestPushState;

  const TestPushState._();

  /// Единственное обязательное поле. Формат почты не проверяем всерьёз:
  /// адресата всё равно ищет бэкенд, и «нет такого пользователя» — более
  /// полезная ошибка, чем придирка к регулярному выражению.
  bool get canSend => !sending && email.trim().contains('@');
}
