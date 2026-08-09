import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../data/push_test_repository.dart';
import 'test_push_events.dart';
import 'test_push_state.dart';

/// Экран «Тестовый пуш» — инструмент администратора, а не пользователя: он
/// нужен, чтобы проверить, что живой путь доставки (очередь → FCM → устройство)
/// работает на проде.
///
/// Ничего локально не хранит и не кэширует: каждая отправка — один вызов
/// `sendTestPush`. Результат последней отправки остаётся в состоянии, чтобы
/// показать число пригодных устройств получателя, — именно оно объясняет
/// «отправилось, но не пришло».
@injectable
class TestPushBloc extends Bloc<TestPushEvent, TestPushState> {
  TestPushBloc(this._repository, this._authBloc)
    : super(const TestPushState()) {
    on<TestPushOpened>(_onOpened);
    on<TestPushEmailChanged>(
      (event, emit) => emit(state.copyWith(email: event.email)),
    );
    on<TestPushTitleChanged>(
      (event, emit) => emit(state.copyWith(title: event.title)),
    );
    on<TestPushBodyChanged>(
      (event, emit) => emit(state.copyWith(body: event.body)),
    );
    on<TestPushLinkChanged>(
      (event, emit) => emit(state.copyWith(link: event.link)),
    );
    on<TestPushSubmitted>(_onSubmitted);
  }

  final PushTestRepository _repository;
  final AuthBloc _authBloc;

  void _onOpened(TestPushOpened event, Emitter<TestPushState> emit) {
    // Проверка «на себе» — самый частый сценарий, поэтому своя почта уже в поле;
    // адрес всё равно можно поменять на чужой.
    final email = _authBloc.state.viewer?.email ?? '';
    if (state.email.isEmpty && email.isNotEmpty) {
      emit(state.copyWith(email: email));
    }
  }

  Future<void> _onSubmitted(
    TestPushSubmitted event,
    Emitter<TestPushState> emit,
  ) async {
    if (!state.canSend) return;
    // Прошлый результат убираем сразу: иначе плашка «отправлено» висела бы над
    // новой, ещё не завершённой отправкой.
    emit(state.copyWith(sending: true, errorMessage: null, result: null));
    try {
      final result = await _repository.sendTestPush(
        email: state.email,
        title: state.title,
        body: state.body,
        link: state.link,
      );
      if (emit.isDone) return;
      emit(state.copyWith(sending: false, result: result));
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(sending: false, errorMessage: _message(e)));
    }
  }

  String _message(Object e) => e is GraphqlException ? e.message : e.toString();
}
