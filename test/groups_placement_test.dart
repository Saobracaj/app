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
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/groups/data/groups_repository.dart';
import 'package:saobracaj/groups/models/group.dart';
import 'package:saobracaj/groups/presentation/groups_page.dart';
import 'package:saobracaj/groups/presentation/groups_section.dart';
import 'package:saobracaj/groups/state_management/groups_bloc.dart';
import 'package:saobracaj/groups/state_management/groups_events.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Где живут группы: на главной — только сами группы пользователя (и ничего,
/// пока он ни в одну не вступил), а обе точки входа — в разделе настроек.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Экран с включённой фичей «группы» и блоком групп, которому можно подсунуть
/// готовый список.
Widget _app(Widget child, {required GroupsBloc groups}) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final flags = FeatureFlagsRepository(client, storage, deviceLanguage: 'ru');
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
            BlocProvider(create: (_) => NetworkStatusBloc(NetworkStatus())),
            BlocProvider(
              create: (_) => FeatureFlagsBloc(flags)
                // Группы — фича «по входу»: снимок вошедшего её включает.
                ..add(
                  FeatureFlagsSnapshotChanged(
                    FeatureFlagsSnapshot.resolve(
                      localOverrides: const {},
                      grants: const {},
                      authenticated: true,
                    ),
                  ),
                ),
            ),
            BlocProvider.value(value: groups),
          ],
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
}

GroupsBloc _groupsBloc() {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final subscriptions = GraphqlSubscriptionClient(client, storage);
  final authBloc = AuthBloc(
    AuthRepository(client, storage, AnalyticsService()),
    subscriptions,
  );
  return GroupsBloc(
    GroupsRepository(client, subscriptions),
    ProfileRepository(client),
    authBloc,
    FeatureFlagsRepository(client, storage, deviceLanguage: 'ru'),
    NetworkStatus(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('без групп главная не показывает про них ничего', (tester) async {
    final groups = _groupsBloc();
    addTearDown(groups.close);
    // Рядом с секцией стоит раздел настроек — он на тех же флагах, и его
    // кнопки доказывают, что фича включена, а пусто на главной не потому, что
    // всё выключено.
    await tester.pumpWidget(
      _app(
        const Column(children: [GroupsSection(), GroupsContent()]),
        groups: groups,
      ),
    );
    // Флаги и список групп доезжают событиями — блокам нужен ещё кадр.
    await tester.pump();
    await tester.pump();

    expect(find.text(LocaleKeys.groups_create.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.groups_section.tr()), findsNothing);
  });

  testWidgets('группы, в которые вступил, на главной есть — без кнопок', (
    tester,
  ) async {
    final groups = _groupsBloc();
    addTearDown(groups.close);
    groups.add(
      const GroupsUpdated([
        Group(id: 'g1', name: 'Ауто-школа', memberCount: 2),
      ]),
    );
    await tester.pumpWidget(_app(const GroupsSection(), groups: groups));
    // Флаги и список групп доезжают событиями — блокам нужен ещё кадр.
    await tester.pump();
    await tester.pump();

    expect(find.text('Ауто-школа'), findsOneWidget);
    expect(find.text(LocaleKeys.groups_section.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.groups_create.tr()), findsNothing);
    expect(find.text(LocaleKeys.groups_join.tr()), findsNothing);
  });

  testWidgets('раздел настроек: обе точки входа и список групп', (
    tester,
  ) async {
    final groups = _groupsBloc();
    addTearDown(groups.close);
    groups.add(
      const GroupsUpdated([
        Group(id: 'g1', name: 'Ауто-школа', memberCount: 2),
      ]),
    );
    await tester.pumpWidget(_app(const GroupsContent(), groups: groups));
    await tester.pump();
    await tester.pump();

    expect(find.text(LocaleKeys.groups_create.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.groups_join.tr()), findsOneWidget);
    expect(find.text('Ауто-школа'), findsOneWidget);
  });
}
