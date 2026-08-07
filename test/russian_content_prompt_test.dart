import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/russian_content_prompt.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A client answering the `featureFlags` query with every premium flag granted
/// — the "server says yes" case the user's own answer still has to override.
class _AllGrantedClient extends GraphqlClient {
  _AllGrantedClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => {
    'featureFlags': {
      'flags': [
        for (final f in AppFeature.values)
          {'key': f.key, 'access': f.access.name, 'enabled': true},
      ],
    },
  };
}

/// A bootstrapped repository for a signed-in user whose subscription grants
/// everything, running on a device with [deviceLanguage].
Future<FeatureFlagsRepository> _bootstrapped(
  String deviceLanguage, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'auth_access_token': 'token',
    ...prefs,
  });
  final storage = TokenStorage();
  final repository = FeatureFlagsRepository(
    _AllGrantedClient(storage),
    storage,
    deviceLanguage: deviceLanguage,
  );
  await repository.bootstrap();
  // bootstrap() fires the backend refresh without awaiting it; awaiting one
  // explicitly (it is idempotent) keeps the tests off wall-clock delays, which
  // never elapse inside `testWidgets`' fake-async zone.
  await repository.refreshFromBackend();
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeatureFlagsRepository — Russian-content question', () {
    test('a non-Russian device is asked, and sees nothing until it answers', () async {
      final repository = await _bootstrapped('en');

      expect(repository.shouldAskRussianContent, isTrue);
      expect(repository.snapshot.shouldAskRussianContent, isTrue);
      // The grant is there, the answer is not — so the feature stays off.
      expect(repository.snapshot.grants, contains(AppFeature.russianContent.key));
      expect(repository.snapshot.russianContent, isFalse);
    });

    test('a Russian device is never asked and gets the content', () async {
      final repository = await _bootstrapped('ru');

      expect(repository.shouldAskRussianContent, isFalse);
      expect(repository.snapshot.russianContent, isTrue);
    });

    test('answering "yes" turns the content on and ends the question', () async {
      final repository = await _bootstrapped('en');
      await repository.setLocalEnabled(AppFeature.russianContent, true);

      expect(repository.shouldAskRussianContent, isFalse);
      expect(repository.snapshot.shouldAskRussianContent, isFalse);
      expect(repository.snapshot.russianContent, isTrue);
    });

    test('answering "no" keeps the content off and ends the question', () async {
      final repository = await _bootstrapped('en');
      await repository.setLocalEnabled(AppFeature.russianContent, false);

      expect(repository.shouldAskRussianContent, isFalse);
      expect(repository.snapshot.russianContent, isFalse);
    });

    test('the answer survives a restart', () async {
      final first = await _bootstrapped('en');
      await first.setLocalEnabled(AppFeature.russianContent, true);
      final stored = await SharedPreferences.getInstance();

      // Same preferences, a fresh repository — as after an app restart.
      final second = FeatureFlagsRepository(
        _AllGrantedClient(TokenStorage()),
        TokenStorage(),
        deviceLanguage: 'en',
      );
      await second.bootstrap();
      await second.refreshFromBackend();

      expect(stored.getBool('russian_content_asked'), isTrue);
      expect(second.shouldAskRussianContent, isFalse);
      expect(second.snapshot.russianContent, isTrue);
    });

    test('other features keep their default-on local toggle', () async {
      final repository = await _bootstrapped('en');

      expect(repository.snapshot.isEnabled(AppFeature.questionSearch), isTrue);
      expect(repository.snapshot.isEnabled(AppFeature.askAi), isTrue);
    });
  });

  group('RussianContentPrompt', () {
    Future<FeatureFlagsBloc> pump(
      WidgetTester tester,
      FeatureFlagsRepository repository,
    ) async {
      final bloc = FeatureFlagsBloc(repository)..add(FeatureFlagsStarted());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const RussianContentPrompt(
              child: Scaffold(body: Text('app content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('asks on a non-Russian device and turns the content on', (
      tester,
    ) async {
      final repository = await _bootstrapped('en');
      await pump(tester, repository);

      // Without EasyLocalization in the tree tr() falls back to the raw key.
      expect(find.text('featureFlags.russianPrompt.title'), findsOneWidget);
      expect(find.text('app content'), findsOneWidget);

      await tester.tap(find.text('featureFlags.russianPrompt.accept'));
      await tester.pumpAndSettle();

      expect(find.text('featureFlags.russianPrompt.title'), findsNothing);
      expect(repository.snapshot.russianContent, isTrue);
    });

    testWidgets('a refusal closes the dialog and leaves the content off', (
      tester,
    ) async {
      final repository = await _bootstrapped('en');
      await pump(tester, repository);

      await tester.tap(find.text('featureFlags.russianPrompt.decline'));
      await tester.pumpAndSettle();

      expect(find.text('featureFlags.russianPrompt.title'), findsNothing);
      expect(repository.snapshot.russianContent, isFalse);
      expect(repository.shouldAskRussianContent, isFalse);
    });

    testWidgets('stays out of the way on a Russian device', (tester) async {
      final repository = await _bootstrapped('ru');
      await pump(tester, repository);

      expect(find.text('featureFlags.russianPrompt.title'), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });
  });
}
