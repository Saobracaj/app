import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/core/network/state_management/network_status_bloc.dart';
import 'package:saobracaj/core/network/state_management/network_status_events.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/groups/data/groups_repository.dart';
import 'package:saobracaj/groups/state_management/groups_bloc.dart';
import 'package:saobracaj/home/home_content_page.dart';
import 'package:saobracaj/home/presentation/offline_home_card.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/test/quest/question_features/data/question_difficulty_repository.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Главная без сети: сверху карточка «приложение в режиме offline» с кнопками
/// перехода к вопросам и симуляции; когда сеть возвращается — карточка
/// исчезает сама (без снэкбаров и кнопок «повторить»).

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

Widget _app(NetworkStatus network) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final subscriptions = GraphqlSubscriptionClient(client, storage);
  final authBloc = AuthBloc(
    AuthRepository(client, storage, AnalyticsService()),
    subscriptions,
  );
  final flags = FeatureFlagsRepository(client, storage);
  return EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('ru')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  NetworkStatusBloc(network)..add(const NetworkStatusStarted()),
            ),
            BlocProvider.value(value: authBloc),
            BlocProvider(create: (_) => FeatureFlagsBloc(flags)),
            BlocProvider(
              create: (_) => QuestionListsBloc(
                QuestionListsRepository(client),
                SharedListsRepository(client),
                authBloc,
                AnalyticsService(),
                QuestionDifficultyRepository(client),
                network,
              ),
            ),
            BlocProvider(
              create: (_) => GroupsBloc(
                GroupsRepository(client, subscriptions),
                ProfileRepository(client),
                authBloc,
                flags,
                network,
              ),
            ),
          ],
          child: const HomeContentPage(),
        ),
      ),
    ),
  );
}

/// На главной есть бесконечные анимации (индикаторы), поэтому
/// `pumpAndSettle` не подходит — прокачиваем несколько кадров.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('без сети — карточка offline с переходами; с сетью — её нет', (
    tester,
  ) async {
    final network = NetworkStatus();
    await tester.pumpWidget(_app(network));
    await _settle(tester);
    expect(find.byType(OfflineHomeCard), findsNothing);

    // Запрос не дошёл до сервера — клиент сообщает об этом статусу сети.
    network.reportFailure();
    await _settle(tester);
    expect(find.byType(OfflineHomeCard), findsOneWidget);
    expect(find.text(LocaleKeys.network_offlineTitle.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.network_goToQuestions.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.network_goToExam.tr()), findsOneWidget);
    // Никаких снэкбаров и «повторить» — только карточка.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(LocaleKeys.network_retry.tr()), findsNothing);

    // Сеть вернулась — карточка исчезает сама.
    network.reportSuccess();
    await _settle(tester);
    expect(find.byType(OfflineHomeCard), findsNothing);
  });
}
