import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/attribution/data/attribution_repository.dart';
import 'package:saobracaj/attribution/data/attribution_service.dart';
import 'package:saobracaj/attribution/models/link_source.dart';
import 'package:saobracaj/attribution/presentation/link_sources_page.dart';
import 'package:saobracaj/attribution/state_management/link_sources_bloc.dart';
import 'package:saobracaj/attribution/state_management/link_sources_events.dart';
import 'package:saobracaj/attribution/state_management/link_sources_state.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/auth_status.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Клиент-заглушка: запоминает запросы и отвечает заданным.
class _FakeClient extends GraphqlClient {
  _FakeClient(this.responses) : super(TokenStorage());

  final Map<String, Map<String, dynamic>> responses;
  final calls = <({String query, Map<String, dynamic> variables, bool auth})>[];

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    calls.add((query: query, variables: variables, auth: authenticated));
    for (final entry in responses.entries) {
      if (query.contains(entry.key)) return entry.value;
    }
    return const {};
  }
}

/// Один отчёт о запуске, как его увидел бы бэкенд.
typedef _Report = ({
  String platform,
  bool authenticated,
  DateTime? installedAt,
  String? playReferrer,
  String? linkCode,
  String? clickId,
});

class _FakeAttributionRepository implements AttributionRepository {
  final reports = <_Report>[];
  Object? failure;
  String? target;

  @override
  Future<String?> reportAppOpen({
    required String platform,
    required bool authenticated,
    DateTime? installedAt,
    String? playReferrer,
    String? linkCode,
    String? clickId,
  }) async {
    reports.add((
      platform: platform,
      authenticated: authenticated,
      installedAt: installedAt,
      playReferrer: playReferrer,
      linkCode: linkCode,
      clickId: clickId,
    ));
    if (failure != null) throw failure!;
    return linkCode == null ? null : target;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthRepository {
  final controller = StreamController<AuthStatus>.broadcast();

  @override
  Stream<AuthStatus> get sessionStatus => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSignals extends LaunchSignals {
  _FakeSignals({this.referrer, this.clickId, this.platformName = 'ANDROID'});

  final String? referrer;
  final String? clickId;
  final String platformName;
  int referrerReads = 0;
  final installed = DateTime.utc(2026, 9, 29, 10);

  @override
  Future<DateTime?> installedAt() async => installed;

  @override
  Future<String?> playReferrer() async {
    referrerReads++;
    return referrer;
  }

  @override
  String? webClickId() => clickId;

  @override
  String platform() => platformName;
}

/// Даёт очереди отчётов доработать.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

LinkSource _source(String id, {String code = 'insta', DateTime? archivedAt}) =>
    LinkSource(
      id: id,
      code: code,
      name: 'Instagram',
      description: '',
      targetPath: '/',
      url: 'https://saobracaj.gleb.at/go/$code',
      createdAt: DateTime(2026, 9, 1),
      archivedAt: archivedAt,
    );

class _FakeSourcesRepository implements AttributionRepository {
  _FakeSourcesRepository(this.sources);

  List<LinkSource> sources;
  Map<String, LinkSourceStats> stats = const {};
  DateTime? lastSince;
  Object? failure;

  @override
  Future<List<LinkSource>> linkSources({bool includeArchived = false}) async =>
      [
        for (final s in sources)
          if (includeArchived || !s.archived) s,
      ];

  @override
  Future<Map<String, LinkSourceStats>> linkSourceStats({
    DateTime? since,
  }) async {
    lastSince = since;
    return stats;
  }

  @override
  Future<LinkSource> createLinkSource({
    required String name,
    String description = '',
    String? code,
    String? targetPath,
  }) async {
    if (failure != null) throw failure!;
    return _source('new', code: code == null || code.isEmpty ? 'abc234' : code);
  }

  @override
  Future<LinkSource> setArchived(String id, {required bool archived}) async =>
      _source(id, archivedAt: archived ? DateTime(2026, 9, 29) : null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('LinkSourcesPage', linkSourcesPageTests);

  group('attributionLinkCode', () {
    test('узнаёт /go/<код> и больше ничего', () {
      expect(attributionLinkCode('/go/insta'), 'insta');
      expect(attributionLinkCode('/go/Insta-Bio/'), 'insta-bio');
      expect(attributionLinkCode('/go/insta?x=1'), 'insta');
      expect(attributionLinkCode('/go'), isNull);
      expect(attributionLinkCode('/go/a/b'), isNull);
      expect(attributionLinkCode('/question/7921'), isNull);
      expect(attributionLinkCode('/'), isNull);
    });
  });

  group('AttributionRepository', () {
    test(
      'отчёт о запуске уходит одним input и возвращает экран ссылки',
      () async {
        final client = _FakeClient({
          'reportAppOpen': {
            'reportAppOpen': {'targetPath': '/question/7921', 'touch': null},
          },
        });
        final target = await AttributionRepository(client).reportAppOpen(
          platform: 'IOS',
          authenticated: false,
          installedAt: DateTime.utc(2026, 9, 29, 10),
          linkCode: 'insta',
        );

        expect(target, '/question/7921');
        final call = client.calls.single;
        expect(call.auth, isFalse);
        expect(call.variables['input'], {
          'platform': 'IOS',
          'installedAt': '2026-09-29T10:00:00.000Z',
          'playReferrer': null,
          'linkCode': 'insta',
          'clickId': null,
        });
      },
    );

    test('воронка разбирается по id источника', () async {
      final client = _FakeClient({
        'linkSourceStats': {
          'linkSourceStats': [
            {
              'sourceId': 's1',
              'stats': {
                'clicks': 10,
                'reached': 4,
                'installs': 3,
                'installsProbable': 1,
                'opens': 1,
                'registrations': 2,
                'buyers': 1,
                'purchases': 2,
              },
            },
          ],
        },
      });
      final stats = await AttributionRepository(client).linkSourceStats();

      expect(stats.keys, ['s1']);
      expect(stats['s1']!.clicks, 10);
      expect(stats['s1']!.installsProbable, 1);
      expect(stats['s1']!.clicksAndroid, 0, reason: 'отсутствующее — ноль');
      expect(client.calls.single.auth, isTrue);
    });

    test('пустой код и экран назначения не отправляются', () async {
      final client = _FakeClient({
        'createLinkSource': {
          'createLinkSource': {
            'id': 's1',
            'code': 'abc234',
            'name': 'Листовки',
            'description': '',
            'targetPath': '/',
            'url': 'https://saobracaj.gleb.at/go/abc234',
            'createdAt': '2026-09-29T10:00:00Z',
            'archivedAt': null,
          },
        },
      });
      final source = await AttributionRepository(
        client,
      ).createLinkSource(name: 'Листовки', code: '  ', targetPath: '');

      expect(source.code, 'abc234');
      expect(source.archived, isFalse);
      final input = client.calls.single.variables['input'] as Map;
      expect(input['code'], isNull);
      expect(input['targetPath'], isNull);
    });
  });

  group('AttributionService', () {
    late _FakeAttributionRepository repository;
    late _FakeAuth auth;

    setUp(() {
      repository = _FakeAttributionRepository();
      auth = _FakeAuth();
    });

    test('первый запуск несёт referrer, дальше он не спрашивается', () async {
      final signals = _FakeSignals(
        referrer: 'utm_source=saobracaj&click_id=c1',
      );
      final service = AttributionService(repository, auth, signals)
        ..start(watchLifecycle: false);

      auth.controller.add(AuthStatus.unauthenticated);
      await _settle();
      expect(repository.reports, hasLength(1));
      final first = repository.reports.single;
      expect(first.platform, 'ANDROID');
      expect(first.authenticated, isFalse);
      expect(first.installedAt, signals.installed);
      expect(first.playReferrer, 'utm_source=saobracaj&click_id=c1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AttributionService.installReportedKey), isTrue);

      // Возвращение из фона сразу после отчёта — не новый заход.
      service.onResumed();
      await _settle();
      expect(repository.reports, hasLength(1));

      // Вход — отчёт с токеном, уже без referrer.
      auth.controller.add(AuthStatus.authenticated);
      await _settle();
      expect(repository.reports, hasLength(2));
      expect(repository.reports.last.authenticated, isTrue);
      expect(repository.reports.last.playReferrer, isNull);
      expect(signals.referrerReads, 1);

      await service.dispose();
    });

    test('неудачный отчёт не отмечает referrer отправленным', () async {
      repository.failure = GraphqlException('offline', network: true);
      final service = AttributionService(
        repository,
        auth,
        _FakeSignals(referrer: 'utm_source=google-play'),
      )..start(watchLifecycle: false);

      auth.controller.add(AuthStatus.unauthenticated);
      await _settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AttributionService.installReportedKey), isNull);

      repository.failure = null;
      service.onResumed();
      await _settle();
      expect(repository.reports.last.playReferrer, 'utm_source=google-play');
      expect(prefs.getBool(AttributionService.installReportedKey), isTrue);

      await service.dispose();
    });

    test('клик из адреса веб-версии уходит один раз', () async {
      final service = AttributionService(
        repository,
        auth,
        _FakeSignals(clickId: 'c42', platformName: 'WEB'),
      )..start(watchLifecycle: false);

      auth.controller.add(AuthStatus.authenticated);
      await _settle();
      expect(repository.reports.single.clickId, 'c42');
      expect(repository.reports.single.platform, 'WEB');

      await service.openedByLink('insta');
      expect(repository.reports.last.clickId, isNull);

      await service.dispose();
    });

    test('ссылка, открывшая приложение, отдаёт экран источника', () async {
      repository.target = '/question/7921';
      final service = AttributionService(repository, auth, _FakeSignals())
        ..start(watchLifecycle: false);

      final target = await service.openedByLink('insta');

      expect(target, '/question/7921');
      expect(repository.reports.last.linkCode, 'insta');
      await service.dispose();
    });

    test('без бэкенда ссылка никуда не ведёт и ничего не роняет', () async {
      repository.failure = GraphqlException('offline', network: true);
      final service = AttributionService(repository, auth, _FakeSignals())
        ..start(watchLifecycle: false);

      expect(await service.openedByLink('insta'), isNull);
      await service.dispose();
    });
  });

  group('LinkSourcesBloc', () {
    test('загрузка берёт источники и воронку за выбранный период', () async {
      final repository = _FakeSourcesRepository([_source('s1')])
        ..stats = {'s1': const LinkSourceStats(clicks: 5, installs: 2)};
      final now = DateTime(2026, 9, 29, 12);
      final bloc = LinkSourcesBloc(repository, clock: () => now);

      bloc.add(LinkSourcesStarted());
      await _settle();
      expect(bloc.state.loading, isFalse);
      expect(bloc.state.sources.single.id, 's1');
      expect(bloc.state.statsOf('s1').clicks, 5);
      expect(bloc.state.statsOf('missing').clicks, 0);
      expect(repository.lastSince, isNull);

      bloc.add(LinkSourcesPeriodChanged(StatsPeriod.days7));
      await _settle();
      expect(repository.lastSince, now.subtract(const Duration(days: 7)));
      await bloc.close();
    });

    test('новый источник встаёт первым и показывается ссылкой', () async {
      final bloc = LinkSourcesBloc(_FakeSourcesRepository([_source('s1')]));
      bloc.add(LinkSourcesStarted());
      await _settle();

      bloc.add(
        LinkSourceCreated(
          name: 'Листовки',
          description: '',
          code: 'flyer',
          targetPath: '',
        ),
      );
      await _settle();
      expect(bloc.state.sources.map((s) => s.id), ['new', 's1']);
      expect(bloc.state.created?.code, 'flyer');

      bloc.add(LinkSourceCreatedShown());
      await _settle();
      expect(bloc.state.created, isNull);
      await bloc.close();
    });

    test('занятый код — понятное сообщение', () async {
      final repository = _FakeSourcesRepository([])
        ..failure = GraphqlException('taken', code: 'link_code_taken');
      final bloc = LinkSourcesBloc(repository);

      bloc.add(
        LinkSourceCreated(
          name: 'X',
          description: '',
          code: 'insta',
          targetPath: '',
        ),
      );
      await _settle();
      expect(bloc.state.errorMessage, LocaleKeys.linkSources_codeTaken.tr());
      expect(bloc.state.submitting, isFalse);
      await bloc.close();
    });

    test('архивный источник уходит из списка без архива', () async {
      final bloc = LinkSourcesBloc(
        _FakeSourcesRepository([_source('s1'), _source('s2', code: 'b')]),
      );
      bloc.add(LinkSourcesStarted());
      await _settle();

      bloc.add(LinkSourceArchiveToggled('s1', archived: true));
      await _settle();
      expect(bloc.state.sources.map((s) => s.id), ['s2']);
      await bloc.close();
    });
  });
}

/// Экран админки на узком телефоне: карточка с воронкой, ссылкой и меню
/// укладывается без переполнений, а цифры воронки видны.
void linkSourcesPageTests() {
  testWidgets('карточка источника укладывается в 360 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository =
        _FakeSourcesRepository([
            LinkSource(
              id: 's1',
              code: 'autoskola-beograd-centar',
              name: 'Автошкола «Центр» — листовки на ресепшене',
              description: 'Пачка из 200 штук, раздаёт администратор',
              targetPath: '/question/7921',
              url: 'https://saobracaj.gleb.at/go/autoskola-beograd-centar',
              createdAt: DateTime(2026, 9, 1),
            ),
          ])
          ..stats = {
            's1': const LinkSourceStats(
              clicks: 1234,
              clicksAndroid: 800,
              clicksIos: 400,
              clicksWeb: 34,
              reached: 321,
              installs: 300,
              installsProbable: 120,
              opens: 21,
              opensProbable: 3,
              registrations: 87,
              buyers: 12,
              purchases: 15,
            ),
          };
    getIt.registerFactory<LinkSourcesBloc>(() => LinkSourcesBloc(repository));
    addTearDown(getIt.reset);

    await tester.pumpWidget(
      EasyLocalization(
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
            home: const LinkSourcesPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Автошкола «Центр» — листовки на ресепшене'),
      findsOneWidget,
    );
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('Регистрации'), findsOneWidget);
    expect(find.textContaining('по сети: 120'), findsOneWidget);
    expect(find.text('7,1%'), findsOneWidget, reason: '87 из 1234 кликов');
  });
}
