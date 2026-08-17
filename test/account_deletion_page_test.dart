import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/account_deletion/data/account_deletion_repository.dart';
import 'package:saobracaj/account_deletion/models/account_deletion_preview.dart';
import 'package:saobracaj/account_deletion/presentation/account_deletion_page.dart';
import 'package:saobracaj/account_deletion/state_management/account_deletion_bloc.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран удаления аккаунта: чек-лист с двумя обязательными пунктами, согласия,
/// кнопка кода недоступна без согласия; при подписке — второе согласие.

class _StubRepository extends AccountDeletionRepository {
  _StubRepository(this._preview) : super(GraphqlClient(TokenStorage()));

  final AccountDeletionPreview _preview;
  int codeRequests = 0;

  @override
  Future<AccountDeletionPreview> preview() async => _preview;

  @override
  Future<void> requestCode() async {
    codeRequests++;
  }
}

class _SignedInAuthBloc extends AuthBloc {
  _SignedInAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  tearDown(getIt.reset);

  Widget wrap(AccountDeletionPreview preview, _StubRepository repo) {
    final storage = TokenStorage();
    final client = GraphqlClient(storage);
    final auth = _SignedInAuthBloc(
      AuthRepository(client, storage, AnalyticsService()),
      GraphqlSubscriptionClient(client, storage),
    );
    getIt.registerFactory<AccountDeletionBloc>(
      () => AccountDeletionBloc(repo, auth),
    );
    return EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: BlocProvider<AuthBloc>.value(
            value: auth,
            child: const AccountDeletionPage(),
          ),
        ),
      ),
    );
  }

  testWidgets('обязательные пункты отмечены и заблокированы, код — только '
      'после согласия', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _StubRepository(
      const AccountDeletionPreview(email: 'a@b.c', publicCommentCount: 3),
    );
    await tester.pumpWidget(wrap(repo._preview, repo));
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    // Аккаунт+email и имя: включены, выключить нельзя.
    expect(tiles[0].value, isTrue);
    expect(tiles[0].onChanged, isNull);
    expect(tiles[1].value, isTrue);
    expect(tiles[1].onChanged, isNull);
    // Все остальные — сняты по умолчанию и переключаемы.
    for (final tile in tiles.skip(2)) {
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNotNull);
    }
    // Комментарии — со счётчиком.
    expect(find.text('Публичные комментарии (3)'), findsOneWidget);
    // Согласия про подписку нет — подписки нет.
    expect(find.textContaining('подписка'), findsNothing);

    final button = find.widgetWithText(
      FilledButton,
      'Отправить код подтверждения',
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.textContaining('без возможности восстановления'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.codeRequests, 1);
    expect(find.textContaining('Мы отправили код на a@b.c'), findsOneWidget);
    expect(find.text('Удалить аккаунт навсегда'), findsOneWidget);
  });

  testWidgets('при активной подписке требуется второе согласие', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _StubRepository(
      AccountDeletionPreview(
        email: 'a@b.c',
        hasActiveSubscription: true,
        subscriptionUntil: DateTime(2027, 3, 1),
      ),
    );
    await tester.pumpWidget(wrap(repo._preview, repo));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(
      FilledButton,
      'Отправить код подтверждения',
    );
    await tester.tap(find.textContaining('без возможности восстановления'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.textContaining('деньги за неё не возвращаются'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
}
