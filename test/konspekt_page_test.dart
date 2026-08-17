import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the authored sources from `konspekt_content/` instead of calling the
/// backend, so the page can be rendered without a server.
class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<Set<String>> availableCategories() async => {'25'};

  @override
  Future<Konspekt?> load(String categoryId) async {
    final file = File('konspekt_content/$categoryId.json');
    if (!file.existsSync()) return null;
    return Konspekt.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }
}

/// A feature-flags repository reporting fixed premium grants, so a test can
/// render the page both as an entitled user and as one without the entitlement.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(this._grants, this._locals)
      : super(GraphqlClient(TokenStorage()), TokenStorage());

  final Set<String> _grants;

  /// Локальные тумблеры. По умолчанию русский контент выключен — так его
  /// держит настоящий репозиторий на несербском… точнее, на нерусском
  /// устройстве, пока пользователь не ответил на вопрос о русских материалах.
  final Map<String, bool> _locals;

  @override
  FeatureFlagsSnapshot get snapshot =>
      FeatureFlagsSnapshot.resolve(localOverrides: _locals, grants: _grants, authenticated: true);

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    getIt.registerLazySingleton<KonspektRepository>(_StubKonspektRepository.new);
    getIt.registerFactoryParam<KonspektBloc, String, String?>(
      (categoryId, section) => KonspektBloc(getIt(), NetworkStatus(), categoryId, section),
    );
    await EasyLocalization.ensureInitialized();
  });

  /// EasyLocalization здесь не для красоты: в тексте конспекта есть маркеры
  /// `anim/…`, а виджеты-иллюстрации читают подписи через `context.tr` и без
  /// локализации в дереве падают с LocalizationNotFoundException.
  Widget wrap(
    Widget child, {
    Set<String> grants = const {'category_summaries'},
    Map<String, bool> locals = const {'russian_content': false},
  }) {
    final flags = FeatureFlagsBloc(_StubFeatureFlagsRepository(grants, locals));
    return EasyLocalization(
      useOnlyLangCode: true,
      ignorePluralRules: false,
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
          home: BlocProvider.value(value: flags, child: child),
        ),
      ),
    );
  }

  testWidgets('KonspektPage renders the category 25 konspekt in Serbian by default', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25')));
    await tester.pumpAndSettle();

    // Without russian_content the authored Serbian fragment wins, both for the
    // category name and for the section titles below it.
    expect(find.text('Основе безбедности саобраћаја'), findsOneWidget);
    expect(find.textContaining('Ко регулише и ко контролише саобраћај'), findsWidgets);
  });

  testWidgets('KonspektPage shows Russian with the russian_content feature on', (tester) async {
    await tester.pumpWidget(wrap(
      const KonspektPage(categoryId: '25'),
      grants: const {'category_summaries', 'russian_content'},
      locals: const {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Основы безопасности дорожного движения'), findsOneWidget);
  });

  testWidgets('KonspektPage deep link scrolls to the requested section', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25', section: 'popravka-i-prepravka')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Поправка и преправка'), findsWidgets);
  });

  testWidgets('KonspektPage shows an error for a category without a konspekt', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '999')));
    await tester.pumpAndSettle();

    expect(find.text('Конспект не найден'), findsOneWidget);
  });

  // Гейт — свойство вопроса: категория 27 платная, поэтому без гранта конспект
  // закрыт…
  testWidgets('KonspektPage stays closed without the category_summaries entitlement', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '27'), grants: const {}));
    await tester.pumpAndSettle();

    expect(find.text('Конспект недоступен'), findsOneWidget);
  });

  // …а бесплатная категория 25 открыта всем, в том числе с русским контентом:
  // премиум-гранта нет, а конспект показывается.
  testWidgets('KonspektPage opens a free category without any entitlement', (tester) async {
    await tester.pumpWidget(wrap(
      const KonspektPage(categoryId: '25'),
      grants: const {},
      locals: const {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Конспект недоступен'), findsNothing);
    expect(find.text('Основы безопасности дорожного движения'), findsOneWidget);
  });
}
