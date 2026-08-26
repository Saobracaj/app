import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_feedback_state.freezed.dart';

/// Состояние диалога «Сообщить об ошибке».
///
/// [notify] — ответ пользователя на вопрос «прислать оповещение об ответе?».
/// Он не про одну эту жалобу, а про весь чат с разработчиком: другого рычага,
/// кроме общего пуш-разрешения устройства, у приложения нет, поэтому
/// переключатель показывает и меняет именно его.
@freezed
abstract class QuestionFeedbackState with _$QuestionFeedbackState {
  const factory QuestionFeedbackState({
    @Default('') String text,

    /// Оповещать об ответе разработчика (пуши включены и разрешены системой).
    @Default(false) bool notify,

    /// Уведомления запрещены в системе «навсегда» — включить их можно только
    /// руками в настройках ОС, поэтому переключатель об этом предупреждает.
    @Default(false) bool notificationsBlocked,

    /// Жалоба уходит в личный чат с разработчиком, а он есть только у вошедшего
    /// пользователя.
    @Default(false) bool signedIn,
    @Default(false) bool sending,
    @Default(false) bool sent,
    String? errorMessage,
  }) = _QuestionFeedbackState;

  const QuestionFeedbackState._();

  /// Максимальная длина тела сообщения на бэкенде (`BODY_MAX_LEN`) минус запас
  /// на служебную шапку («Report · discussion» и ссылка на вопрос).
  static const maxTextLength = 3800;

  bool get canSend => signedIn && !sending && text.trim().isNotEmpty;
}
