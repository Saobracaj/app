import 'package:freezed_annotation/freezed_annotation.dart';

part 'extension_request_state.freezed.dart';

/// Состояние диалога «Не сдал экзамен» — запроса бесплатного продления.
///
/// Запрос уезжает обычным сообщением в чат пользователя с разработчиком, как
/// и жалоба на контент: отдельного канала нет и не нужно, оператор продлевает
/// пропуск вручную и отвечает там же.
@freezed
abstract class ExtensionRequestState with _$ExtensionRequestState {
  const factory ExtensionRequestState({
    @Default('') String examDate,
    @Default('') String note,

    /// Чат с разработчиком есть только у вошедшего пользователя.
    @Default(false) bool signedIn,
    @Default(false) bool sending,
    @Default(false) bool sent,
    String? errorMessage,
  }) = _ExtensionRequestState;

  const ExtensionRequestState._();

  static const maxNoteLength = 2000;

  /// Дата экзамена — единственное обязательное поле: без неё оператору нечего
  /// сверять с периодом подписки.
  bool get canSend => signedIn && !sending && examDate.trim().isNotEmpty;
}
