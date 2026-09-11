import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/translation_chip.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/quest/presentation/quest_app_bar.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Первые три показа перевода «РУ» на вопросах платных категорий бесплатны:
/// чип включает перевод как при подписке, тратит попытку и говорит, сколько
/// осталось; когда попытки кончились — ведёт на пейволл. В бесплатных
/// категориях и с подпиской счётчик не участвует вовсе.
class _RecordingAnalytics extends AnalyticsService {
  final events = <String>[];

  @override
  void logPaywallOpened({required String source, int? questionId}) =>
      events.add('paywall_opened:$source:$questionId');

  @override
  void logTranslationTrialUsed({required int usesLeft, int? questionId}) =>
      events.add('translation_trial_used:$usesLeft:$questionId');
}

/// Гость с русскоязычного устройства: русские материалы включены по
/// умолчанию, подписки нет — перевод в платной категории заперт.
Future<FeatureFlagsRepository> _guestRepository() async {
  final storage = TokenStorage();
  final repository = FeatureFlagsRepository(
    GraphqlClient(storage),
    storage,
    deviceLanguage: 'ru',
  );
  await repository.bootstrap();
  return repository;
}

Widget _appBar({
  required FeatureFlagsBloc flags,
  required TranslationsBloc translations,
  String categoryId = '27',
}) {
  return EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<FeatureFlagsBloc>.value(value: flags),
            BlocProvider<TranslationsBloc>.value(value: translations),
          ],
          child: Scaffold(
            appBar: QuestAppBar(
              questionNumber: 1,
              questionCount: 2,
              points: 2,
              questionId: 777,
              categoryId: categoryId,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FeatureFlagsSnapshot snapshot({
    Set<String> grants = const {},
    Map<String, bool> locals = const {},
    bool authenticated = false,
    int triesLeft = russianTranslationTrialUses,
  }) => FeatureFlagsSnapshot.resolve(
    localOverrides: locals,
    grants: grants,
    authenticated: authenticated,
    russianTranslationTriesLeft: triesLeft,
  );

  group('FeatureFlagsSnapshot.canTryRussianTranslation', () {
    test('бесплатная попытка есть только там, где перевод заперт', () {
      final flags = snapshot();
      expect(flags.canTryRussianTranslation('27'), isTrue);
      // В бесплатной категории перевод и так открыт — попытка не нужна.
      expect(flags.canTryRussianTranslation('25'), isFalse);
    });

    test('с подпиской счётчик не участвует', () {
      final flags = snapshot(
        grants: {AppFeature.russianContent.key},
        authenticated: true,
      );
      expect(flags.canTryRussianTranslation('27'), isFalse);
      expect(
        flags.isEnabledForCategory(AppFeature.russianContent, '27'),
        isTrue,
      );
    });

    test('выключенные русские материалы попыток не дают', () {
      final flags = snapshot(locals: {AppFeature.russianContent.key: false});
      expect(flags.canTryRussianTranslation('27'), isFalse);
    });

    test('когда попытки кончились — заперто без попытки', () {
      final flags = snapshot(triesLeft: 0);
      expect(flags.canTryRussianTranslation('27'), isFalse);
      expect(
        flags.isLockedForCategory(AppFeature.russianContent, '27'),
        isTrue,
      );
    });

    test('до чтения сохранённого счётчика попыток нет', () {
      expect(FeatureFlagsSnapshot.initial().russianTranslationTriesLeft, 0);
    });
  });

  group('FeatureFlagsRepository — счётчик бесплатных показов', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('три попытки, каждая тратится и сохраняется', () async {
      final repository = await _guestRepository();
      expect(repository.russianTranslationTriesLeft, 3);
      expect(repository.snapshot.russianTranslationTriesLeft, 3);

      await repository.consumeRussianTranslationTrial();
      await repository.consumeRussianTranslationTrial();
      expect(repository.snapshot.russianTranslationTriesLeft, 1);
      expect(repository.snapshot.canTryRussianTranslation('27'), isTrue);

      await repository.consumeRussianTranslationTrial();
      expect(repository.snapshot.russianTranslationTriesLeft, 0);
      expect(repository.snapshot.canTryRussianTranslation('27'), isFalse);

      // Ниже нуля не уходит.
      await repository.consumeRussianTranslationTrial();
      expect(repository.snapshot.russianTranslationTriesLeft, 0);

      // Счётчик переживает перезапуск: новый экземпляр читает то же число.
      final restarted = await _guestRepository();
      expect(restarted.russianTranslationTriesLeft, 0);
    });

    test('сохранённые попытки читаются при старте', () async {
      SharedPreferences.setMockInitialValues({
        'russian_translation_trial_used': 2,
      });
      final repository = await _guestRepository();
      expect(repository.snapshot.russianTranslationTriesLeft, 1);
    });
  });

  group('чип «РУ» на вопросе платной категории без подписки', () {
    late _RecordingAnalytics recorded;
    late FeatureFlagsRepository repository;
    late FeatureFlagsBloc flags;
    late TranslationsBloc translations;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      recorded = _RecordingAnalytics();
      getIt.registerSingleton<AnalyticsService>(recorded);
      repository = await _guestRepository();
      flags = FeatureFlagsBloc(repository)..add(FeatureFlagsStarted());
      translations = TranslationsBloc();
    });

    tearDown(() async {
      await flags.close();
      await translations.close();
      await getIt.reset();
    });

    // Блоки созданы в setUp и живут в реальной зоне, а тело теста — в
    // fake-async: счётчик пишется в SharedPreferences настоящими Future, и
    // ждать их надо через runAsync, а уже потом перестраивать дерево.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    Future<void> tapChip(WidgetTester tester) async {
      await tester.tap(find.byType(TranslationChip));
      await settle(tester);
    }

    testWidgets('первые три включения открывают перевод, четвёртое — пейволл', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appBar(flags: flags, translations: translations),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TranslationChip), findsOneWidget);

      for (var use = 1; use <= 3; use++) {
        // Включить.
        await tapChip(tester);
        expect(
          translations.state.showTranslation,
          isTrue,
          reason: 'показ №$use должен открыть перевод',
        );
        expect(flags.state.russianTranslationTriesLeft, 3 - use);
        expect(recorded.events.last, 'translation_trial_used:${3 - use}:777');
        // Выключить — попытка на это не тратится.
        await tapChip(tester);
        expect(translations.state.showTranslation, isFalse);
        expect(flags.state.russianTranslationTriesLeft, 3 - use);
      }

      // Попытки кончились: чип больше не переключает, а ведёт к тарифам.
      // Витрина открывается через роутер, которого в этом дереве нет, —
      // сам переход падает, но событие пейволла уходит до него.
      await tester.tap(find.byType(TranslationChip));
      expect(tester.takeException(), isNotNull);
      expect(translations.state.showTranslation, isFalse);
      expect(recorded.events.last, 'paywall_opened:russian_toggle:777');
    });

    testWidgets('снекбар говорит, сколько бесплатных показов осталось', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appBar(flags: flags, translations: translations),
      );
      await tester.pumpAndSettle();

      await tapChip(tester);
      expect(find.textContaining('Осталось бесплатных показов: 2'), findsOne);
    });

    testWidgets('после последней попытки открытый перевод ещё можно закрыть', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'russian_translation_trial_used': 2,
      });
      await tester.runAsync(() async {
        await flags.close();
        repository = await _guestRepository();
        flags = FeatureFlagsBloc(repository)..add(FeatureFlagsStarted());
      });
      await tester.pumpWidget(
        _appBar(flags: flags, translations: translations),
      );
      await settle(tester);
      await tester.pumpAndSettle();

      await tapChip(tester);
      expect(translations.state.showTranslation, isTrue);
      expect(flags.state.russianTranslationTriesLeft, 0);
      expect(find.textContaining('последний бесплатный показ'), findsOne);

      // Перевод показан — чип его же и выключает, без пейволла.
      await tapChip(tester);
      expect(translations.state.showTranslation, isFalse);
      expect(
        recorded.events.where((e) => e.startsWith('paywall_opened')),
        isEmpty,
      );
    });

    testWidgets('в бесплатной категории попытки не тратятся', (tester) async {
      await tester.pumpWidget(
        _appBar(flags: flags, translations: translations, categoryId: '25'),
      );
      await tester.pumpAndSettle();

      await tapChip(tester);
      expect(translations.state.showTranslation, isTrue);
      expect(flags.state.russianTranslationTriesLeft, 3);
      expect(recorded.events, isEmpty);
    });
  });
}
