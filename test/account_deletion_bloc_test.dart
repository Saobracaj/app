import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/account_deletion/data/account_deletion_repository.dart';
import 'package:saobracaj/account_deletion/data/local_data_cleaner.dart';
import 'package:saobracaj/account_deletion/models/account_deletion_preview.dart';
import 'package:saobracaj/account_deletion/state_management/account_deletion_bloc.dart';
import 'package:saobracaj/account_deletion/state_management/account_deletion_events.dart';
import 'package:saobracaj/account_deletion/state_management/account_deletion_state.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сеть в этих тестах не используется.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Заглушка API удаления: запоминает, что у неё спрашивали, и отдаёт
/// заданный превью/результат.
class _FakeRepository extends AccountDeletionRepository {
  _FakeRepository(super.client, {required this.previewValue});

  final AccountDeletionPreview previewValue;
  int codeRequests = 0;
  Map<String, Object?>? lastDelete;
  GraphqlException? deleteError;

  @override
  Future<AccountDeletionPreview> preview() async => previewValue;

  @override
  Future<void> requestCode() async {
    codeRequests++;
  }

  @override
  Future<bool> deleteAccount({
    required String code,
    required bool deletePublicComments,
    required bool deleteSupportAttachments,
    required bool deleteSupportChat,
    required bool deleteGroupHistory,
    required bool acceptIrreversible,
    required bool acceptSubscriptionLoss,
  }) async {
    if (deleteError != null) throw deleteError!;
    lastDelete = {
      'code': code,
      'deletePublicComments': deletePublicComments,
      'deleteSupportAttachments': deleteSupportAttachments,
      'deleteSupportChat': deleteSupportChat,
      'deleteGroupHistory': deleteGroupHistory,
      'acceptIrreversible': acceptIrreversible,
      'acceptSubscriptionLoss': acceptSubscriptionLoss,
    };
    return true;
  }
}

/// AuthBloc, который вместо реального выхода запоминает событие удаления.
class _RecordingAuthBloc extends AuthBloc {
  _RecordingAuthBloc(super.repository, super.subscriptions);

  final List<AccountDeleted> deletions = [];

  @override
  void add(AuthEvent event) {
    if (event is AccountDeleted) {
      deletions.add(event);
      return;
    }
    super.add(event);
  }
}

({AccountDeletionBloc bloc, _FakeRepository repo, _RecordingAuthBloc auth})
_build({AccountDeletionPreview preview = const AccountDeletionPreview()}) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final repo = _FakeRepository(client, previewValue: preview);
  final authRepo = AuthRepository(client, storage, AnalyticsService());
  final auth = _RecordingAuthBloc(
    authRepo,
    GraphqlSubscriptionClient(client, storage),
  );
  return (bloc: AccountDeletionBloc(repo, auth), repo: repo, auth: auth);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('без согласия с необратимостью код не запрашивается', () async {
    final h = _build();
    h.bloc.add(AccountDeletionStarted());
    await _settle();
    expect(h.bloc.state.loading, isFalse);
    expect(h.bloc.state.canRequestCode, isFalse);

    h.bloc.add(RequestCodePressed());
    await _settle();
    expect(h.repo.codeRequests, 0);
    expect(h.bloc.state.step, AccountDeletionStep.options);

    h.bloc.add(AcceptIrreversibleToggled(true));
    h.bloc.add(RequestCodePressed());
    await _settle();
    expect(h.repo.codeRequests, 1);
    expect(h.bloc.state.step, AccountDeletionStep.code);
    expect(h.bloc.state.codeSentTick, 1);
  });

  test('все необязательные галочки сняты по умолчанию', () async {
    final h = _build(
      preview: const AccountDeletionPreview(
        publicCommentCount: 5,
        supportAttachmentCount: 2,
        supportMessageCount: 3,
        groupActivityCount: 7,
      ),
    );
    h.bloc.add(AccountDeletionStarted());
    await _settle();
    final s = h.bloc.state;
    expect(s.deletePublicComments, isFalse);
    expect(s.deleteSupportAttachments, isFalse);
    expect(s.deleteSupportChat, isFalse);
    expect(s.deleteGroupHistory, isFalse);
    expect(s.clearLocalData, isFalse);
    // Согласия — тоже не проставлены заранее.
    expect(s.acceptIrreversible, isFalse);
    expect(s.acceptSubscriptionLoss, isFalse);

    // Ничего лишнего не уходит на сервер, если пользователь только согласился.
    h.bloc.add(AcceptIrreversibleToggled(true));
    h.bloc.add(RequestCodePressed());
    await _settle();
    h.bloc.add(CodeChanged('123456'));
    h.bloc.add(ConfirmDeletePressed());
    await _settle();
    expect(h.repo.lastDelete, {
      'code': '123456',
      'deletePublicComments': false,
      'deleteSupportAttachments': false,
      'deleteSupportChat': false,
      'deleteGroupHistory': false,
      'acceptIrreversible': true,
      'acceptSubscriptionLoss': false,
    });
  });

  test('удаление переписки подразумевает её вложения', () async {
    final h = _build();
    h.bloc.add(AccountDeletionStarted());
    await _settle();
    h.bloc.add(DeleteSupportChatToggled(true));
    await _settle();
    // Строка «фотографии и файлы» в чек-листе показывается отмеченной.
    expect(h.bloc.state.deleteSupportAttachments, isFalse);
    expect(h.bloc.state.deletesSupportAttachments, isTrue);
  });

  test('при активной подписке нужно отдельное согласие', () async {
    final h = _build(
      preview: AccountDeletionPreview(
        hasActiveSubscription: true,
        subscriptionUntil: DateTime(2027, 1, 1),
      ),
    );
    h.bloc.add(AccountDeletionStarted());
    await _settle();
    h.bloc.add(AcceptIrreversibleToggled(true));
    await _settle();
    expect(h.bloc.state.canRequestCode, isFalse);
    h.bloc.add(AcceptSubscriptionLossToggled(true));
    await _settle();
    expect(h.bloc.state.canRequestCode, isTrue);
  });

  test('подтверждение передаёт выбор на сервер и завершает сессию', () async {
    final h = _build();
    h.bloc.add(AccountDeletionStarted());
    await _settle();
    h.bloc.add(AcceptIrreversibleToggled(true));
    h.bloc.add(DeletePublicCommentsToggled(true));
    h.bloc.add(DeleteSupportChatToggled(true));
    h.bloc.add(DeleteGroupHistoryToggled(true));
    h.bloc.add(ClearLocalDataToggled(true));
    h.bloc.add(RequestCodePressed());
    await _settle();

    h.bloc.add(CodeChanged('12345'));
    await _settle();
    expect(h.bloc.state.canConfirm, isFalse);
    h.bloc.add(CodeChanged('123456'));
    h.bloc.add(ConfirmDeletePressed());
    await _settle();

    expect(h.repo.lastDelete, {
      'code': '123456',
      'deletePublicComments': true,
      // Отдельно не отмечались — но удаление переписки уносит и вложения.
      'deleteSupportAttachments': true,
      'deleteSupportChat': true,
      'deleteGroupHistory': true,
      'acceptIrreversible': true,
      'acceptSubscriptionLoss': false,
    });
    expect(h.bloc.state.deleted, isTrue);
    expect(h.auth.deletions, hasLength(1));
    expect(h.auth.deletions.single.clearLocalData, isTrue);
  });

  test(
    'неверный код показывает ошибку сервера и не завершает сессию',
    () async {
      final h = _build();
      h.bloc.add(AccountDeletionStarted());
      await _settle();
      h.bloc.add(AcceptIrreversibleToggled(true));
      h.bloc.add(RequestCodePressed());
      await _settle();
      h.repo.deleteError = GraphqlException('Неверный код', code: 'wrong_code');
      h.bloc.add(CodeChanged('000000'));
      h.bloc.add(ConfirmDeletePressed());
      await _settle();
      expect(h.bloc.state.deleted, isFalse);
      expect(h.bloc.state.errorMessage, 'Неверный код');
      expect(h.auth.deletions, isEmpty);
    },
  );

  test('LocalDataCleaner чистит кэши, но оставляет язык и тему', () async {
    SharedPreferences.setMockInitialValues({
      'locale': 'ru',
      'theme_mode': 'dark',
      'question_explanation.1': 'x',
      'konspekt_catalog': 'y',
      'auth_access_token': 't',
    });
    var statisticsCleared = 0;
    // База Drift — глобал приложения, в тесте её не открываем.
    final cleaner = LocalDataCleaner()
      ..clearStatistics = () async => statisticsCleared++;
    await cleaner.wipe();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'locale', 'theme_mode'});
    expect(statisticsCleared, 1);
  });
}
