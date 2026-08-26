import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../core/network/error_messages.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../../notifications/data/notification_permissions.dart';
import '../../chat/data/chat_repository.dart';
import '../domain/question_feedback_source.dart';
import '../domain/question_feedback_target.dart';
import 'question_feedback_events.dart';
import 'question_feedback_state.dart';

/// Жалоба на контент — вкладку вопроса («Объяснение», «Конспект») или полный
/// конспект категории.
///
/// Отдельного канала для таких сообщений нет — и не нужно: жалоба уходит
/// обычным сообщением в чат пользователя с разработчиком, с шапкой `Report`,
/// именем источника и ссылкой на предмет жалобы. Ссылку на вопрос бэкенд
/// превращает во вложение «вопрос N» сам, но id передаётся и явно (сервер их
/// дедуплицирует), чтобы вложение появилось, даже если формат ссылки
/// когда-нибудь поменяется.
///
/// Перед отправкой пользователя спрашивают, прислать ли оповещение об ответе.
/// Это не свойство одной жалобы, а весь чат с разработчиком: своей подписки на
/// тред у бэкенда нет, есть одно общее пуш-разрешение устройства — его
/// переключатель и показывает, тот же, что на экране настроек уведомлений.
/// Поэтому состояние переключателя применяется сразу при переключении (включая
/// системный запрос разрешения), а не в момент отправки: пользователь, который
/// его не трогал, ничего у себя не меняет.
@injectable
class QuestionFeedbackBloc
    extends Bloc<QuestionFeedbackEvent, QuestionFeedbackState> {
  QuestionFeedbackBloc(
    this._chat,
    this._permissions,
    this._authRepo,
    this._authBloc,
    @factoryParam this.target,
    @factoryParam this.source,
  ) : super(const QuestionFeedbackState()) {
    on<QuestionFeedbackOpened>(_onOpened);
    on<QuestionFeedbackTextChanged>(
      (event, emit) => emit(state.copyWith(text: event.text)),
    );
    on<QuestionFeedbackNotifyToggled>(_onNotifyToggled);
    on<QuestionFeedbackSubmitted>(_onSubmitted);
    on<QuestionFeedbackErrorDismissed>(
      (_, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final ChatRepository _chat;
  final NotificationPermissions _permissions;
  final AuthRepository _authRepo;
  final AuthBloc _authBloc;

  final QuestionFeedbackTarget target;
  final QuestionFeedbackSource source;

  /// Одно на всё приложение — те же ключи, что у `NotificationsBloc` и
  /// `ChatBloc`.
  static const _pushNotifKey = 'notif_push_enabled';

  /// Чат с разработчиком делает такое же предложение при первом открытии;
  /// ответив здесь, пользователь отвечает и ему.
  static const _supportPromptKey = 'support_chat_notifications_asked';

  Future<void> _onOpened(
    QuestionFeedbackOpened event,
    Emitter<QuestionFeedbackState> emit,
  ) async {
    final signedIn = _authBloc.state.isAuthenticated;
    try {
      final prefs = await SharedPreferences.getInstance();
      final preference = prefs.getBool(_pushNotifKey) ?? true;
      final status = await _permissions.status();
      if (emit.isDone) return;
      emit(
        state.copyWith(
          signedIn: signedIn,
          // Ровно то же «действующее» значение, что показывает переключатель на
          // экране настроек: разрешение включено и система его даёт.
          notify: preference && status.granted,
          notificationsBlocked: status.permanentlyDenied,
        ),
      );
    } catch (_) {
      // Читать настройки — не то, из-за чего стоит не дать пожаловаться.
      if (!emit.isDone) emit(state.copyWith(signedIn: signedIn));
    }
  }

  /// Ответ на предложение оповещений. Включение проходит через системное
  /// разрешение: без него пуш всё равно не дойдёт, а переключатель, который
  /// говорит «включено», врал бы.
  Future<void> _onNotifyToggled(
    QuestionFeedbackNotifyToggled event,
    Emitter<QuestionFeedbackState> emit,
  ) async {
    if (!event.enabled) {
      emit(state.copyWith(notify: false));
      await _persistPush(false);
      return;
    }

    var status = await _permissions.status();
    if (status.permanentlyDenied) {
      // Системный диалог больше не покажут — остаётся отправить пользователя в
      // настройки ОС и перечитать разрешение, когда он вернётся.
      await _permissions.openSettings();
      status = await _permissions.status();
    } else if (!status.granted) {
      status = await _permissions.request();
    }
    if (emit.isDone) return;
    if (!status.granted) {
      emit(
        state.copyWith(
          notify: false,
          notificationsBlocked: status.permanentlyDenied,
        ),
      );
      return;
    }
    emit(state.copyWith(notify: true, notificationsBlocked: false));
    await _persistPush(true);
  }

  /// Сохранить общее пуш-разрешение — локально и, для вошедшего пользователя,
  /// на бэкенде. Полностью best-effort: жалоба важнее, чем настройка.
  Future<void> _persistPush(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pushNotifKey, enabled);
      // Спросили здесь — чат с разработчиком не спросит второй раз.
      await prefs.setBool(_supportPromptKey, true);
      if (!_authBloc.state.isAuthenticated) return;
      if (enabled) await _authRepo.registerDevice(platform: _platform());
      await _authRepo.setDevicePushEnabled(enabled);
    } catch (_) {
      // Требует настроенного FCM-токена, чтобы подействовать полностью.
    }
  }

  Future<void> _onSubmitted(
    QuestionFeedbackSubmitted event,
    Emitter<QuestionFeedbackState> emit,
  ) async {
    if (!state.canSend) return;
    emit(state.copyWith(sending: true, errorMessage: null));
    try {
      // Жалоба уезжает в собственный чат пользователя с разработчиком: его
      // идентификатор бэкенд отдаёт по токену, и он же нужен мутации отправки.
      final chat = await _chat.supportChat();
      await _chat.send(
        chatId: chat.id,
        body: composeBody(state.text),
        questionIds: target.questionIds,
      );
      if (emit.isDone) return;
      emit(state.copyWith(sending: false, sent: true, text: ''));
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(sending: false, errorMessage: _message(e)));
    }
  }

  /// Текст сообщения: маркер `Report`, источник жалобы, ссылка на её предмет и
  /// сам текст пользователя.
  ///
  /// Шапка нарочно не переводится — её читает разработчик, и она должна
  /// выглядеть одинаково независимо от языка приложения.
  @visibleForTesting
  String composeBody(String text) => [
    'Report · ${source.key}',
    target.link.toString(),
    '',
    text.trim(),
  ].join('\n');

  String _platform() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  String _message(Object e) => describeError(e);
}
