import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';
import 'package:saobracaj/zakon/domain/law_document.dart';
import 'package:saobracaj/zakon/presentation/zakon_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Флаги фич не ходят в сеть: закону нужен только `russian_content`.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository()
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: const {'russian_content': false},
    grants: const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Ссылки на правилник в объяснениях к вопросам: `pravilnik?chapter=…&chlan=…`
/// устроена так же, как ссылка на закон, и должна открывать именно правилник —
/// иначе объяснение о знаке приводило бы в закон о безбедности.
///
/// Проверяется, какой документ открылся (по заголовку из [LawDocument]), а не
/// его текст: `assets/parsed_pravilnik.json` в тестовой среде не читается через
/// `rootBundle` (см. zakon_page_test.dart), список приезжает пустым.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  group('documentOfPath', () {
    test('ссылка на правилник — относительная и абсолютная', () {
      expect(
        documentOfPath('pravilnik?chapter=II&chlan=18&paragraph=21'),
        LawDocument.pravilnik,
      );
      expect(documentOfPath('/pravilnik'), LawDocument.pravilnik);
    });

    test('всё остальное — закон', () {
      expect(
        documentOfPath('zakon?chapter=VII&chlan=135&paragraph=2'),
        LawDocument.zakonOBezbednosti,
      );
      expect(documentOfPath('zakon'), LawDocument.zakonOBezbednosti);
      expect(documentOfPath(''), LawDocument.zakonOBezbednosti);
    });
  });

  Widget wrap(Widget child) {
    final flags = FeatureFlagsBloc(_StubFeatureFlagsRepository());
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
        // Провайдер стоит НАД MaterialApp: панель закона выезжает через
        // showGeneralDialog корневого навигатора, и её поддерево видит только
        // то, что объявлено выше самого приложения.
        builder: (context) => BlocProvider.value(
          value: flags,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  /// Широкое окно: закон и правилник выезжают панелью, маршрут не нужен —
  /// иначе тесту понадобился бы весь routemaster.
  void setWideWindow(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
  }

  testWidgets('ссылка pravilnik из объяснения открывает правилник', (
    tester,
  ) async {
    setWideWindow(tester);
    await tester.pumpWidget(
      wrap(
        const QuestMarkdown(
          text: '[правилник](pravilnik?chapter=II&chlan=18&paragraph=21)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('правилник'));
    await tester.pumpAndSettle();

    expect(find.text(LawDocument.pravilnik.title), findsOneWidget);
    expect(find.text(LawDocument.zakonOBezbednosti.title), findsNothing);
  });

  testWidgets('ссылка zakon из объяснения по-прежнему открывает закон', (
    tester,
  ) async {
    setWideWindow(tester);
    await tester.pumpWidget(
      wrap(
        const QuestMarkdown(
          text: '[закон](zakon?chapter=VII&chlan=135&paragraph=2)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('закон'));
    await tester.pumpAndSettle();

    expect(find.text(LawDocument.zakonOBezbednosti.title), findsOneWidget);
    expect(find.text(LawDocument.pravilnik.title), findsNothing);
  });
}
