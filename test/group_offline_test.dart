import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/group_posts/data/group_posts_repository.dart';
import 'package:saobracaj/group_posts/presentation/group_posts_tab.dart';
import 'package:saobracaj/group_posts/state_management/group_posts_bloc.dart';
import 'package:saobracaj/group_posts/state_management/group_posts_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Стена группы без сети: вместо снек-бара «Network error» — строка «нет связи»
/// с кнопкой, и ни при каком нажатии на неё стена не притворяется пустой.

/// Клиент, до сервера не доходящий: ровно то, что случается в offline-режиме.
class _OfflineClient extends GraphqlClient {
  _OfflineClient(super.storage);

  /// Сколько раз стена попыталась прочитаться.
  int calls = 0;

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    calls++;
    throw GraphqlException('Network error', network: true);
  }
}

Widget _app(GroupPostsBloc bloc) {
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
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const GroupPostsTab(groupId: 'g1'),
          ),
        ),
      ),
    ),
  );
}

/// На экране есть бесконечные анимации (индикатор загрузки), поэтому
/// `pumpAndSettle` не годится — прокачиваем несколько кадров.
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

  testWidgets(
    'стена без сети: строка «нет связи» вместо снек-бара, и «обновить» не выдаёт её за пустую',
    (tester) async {
      final client = _OfflineClient(TokenStorage());
      final bloc = GroupPostsBloc(
        GroupPostsRepository(client),
        NetworkStatus(),
        'g1',
      );
      await tester.pumpWidget(_app(bloc));
      bloc.add(const GroupPostsOpened());
      await _settle(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(LocaleKeys.groups_feed_offline.tr()), findsOneWidget);
      expect(find.text(LocaleKeys.groups_posts_empty.tr()), findsNothing);

      // Тот самый баг: нажатие на «Нет связи с сервером — обновить» в offline
      // отвечало «в группе ещё нет постов».
      await tester.tap(find.text(LocaleKeys.groups_feed_offline.tr()));
      await _settle(tester);

      expect(client.calls, 2, reason: 'кнопка действительно перечитывает');
      expect(find.text(LocaleKeys.groups_posts_empty.tr()), findsNothing);
      expect(find.text(LocaleKeys.groups_feed_offline.tr()), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Не `await`: close() ждёт обработчики, а прокачать их в FakeAsync-зоне
      // после конца теста уже некому.
      unawaited(bloc.close());
    },
  );
}
