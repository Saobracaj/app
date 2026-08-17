import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/question_lists/models/question_list_share.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сторона владельца: «Поделиться» получает (или переиспользует) ссылку и
/// выставляет её для системного share sheet; «Отозвать ссылку» убирает её из
/// состояния; ошибка — одноразовый флаг.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

class _StubShares extends SharedListsRepository {
  _StubShares({this.fail = false}) : super(_FakeClient(TokenStorage()));

  final bool fail;
  int shareCalls = 0;
  final revoked = <String>[];

  @override
  Future<QuestionListShare> share(String listId) async {
    shareCalls++;
    if (fail) throw GraphqlException('boom');
    return QuestionListShare(
      code: 'ABCDEFGH',
      url: 'https://saobracaj.gleb.at/shared/ABCDEFGH',
      listId: listId,
    );
  }

  @override
  Future<void> revoke(String listId) async {
    if (fail) throw GraphqlException('boom');
    revoked.add(listId);
  }
}

class _SignedIn extends AuthBloc {
  _SignedIn()
    : super(
        AuthRepository(
          _FakeClient(TokenStorage()),
          TokenStorage(),
          AnalyticsService(),
        ),
        GraphqlSubscriptionClient(_FakeClient(TokenStorage()), TokenStorage()),
      );

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

QuestionListsBloc _bloc(_StubShares shares) => QuestionListsBloc(
  QuestionListsRepository(_FakeClient(TokenStorage())),
  shares,
  _SignedIn(),
  AnalyticsService(),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('«Поделиться» даёт ссылку и помечает список как расшаренный', () async {
    final shares = _StubShares();
    final bloc = _bloc(shares)..add(QuestionListShareRequested('list-1'));
    await _settle();

    expect(bloc.state.shareOf('list-1')?.code, 'ABCDEFGH');
    expect(bloc.state.shareToPresent?.url, endsWith('/shared/ABCDEFGH'));
    expect(bloc.state.shareBusy, isFalse);

    bloc.add(QuestionListSharePresented());
    await _settle();
    expect(bloc.state.shareToPresent, isNull);
    // Ссылка по-прежнему активна — повторный «Поделиться» отдаёт её же.
    bloc.add(QuestionListShareRequested('list-1'));
    await _settle();
    expect(shares.shareCalls, 2);
    expect(bloc.state.shareToPresent?.code, 'ABCDEFGH');
    await bloc.close();
  });

  test('«Отозвать ссылку» снимает шару', () async {
    final shares = _StubShares();
    final bloc = _bloc(shares)..add(QuestionListShareRequested('list-1'));
    await _settle();
    bloc.add(QuestionListShareRevoked('list-1'));
    await _settle();

    expect(shares.revoked, ['list-1']);
    expect(bloc.state.shareOf('list-1'), isNull);
    expect(bloc.state.shareRevoked, isTrue);
    bloc.add(QuestionListSharePresented());
    await _settle();
    expect(bloc.state.shareRevoked, isFalse);
    await bloc.close();
  });

  test('ошибка сети — одноразовый флаг, состояние шар не меняется', () async {
    final bloc = _bloc(_StubShares(fail: true))
      ..add(QuestionListShareRequested('list-1'));
    await _settle();
    expect(bloc.state.shareFailed, isTrue);
    expect(bloc.state.shareOf('list-1'), isNull);
    expect(bloc.state.shareToPresent, isNull);
    bloc.add(QuestionListsErrorShown());
    await _settle();
    expect(bloc.state.shareFailed, isFalse);
    await bloc.close();
  });
}
