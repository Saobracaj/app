import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_events.dart';

class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<Set<String>> availableCategories() async => {'25'};

  @override
  Future<Konspekt?> load(String categoryId) async => const Konspekt(
    categoryId: '25',
    categoryName: KonspektText(ru: 'Основы'),
    sections: [
      KonspektSection(id: 'a', title: KonspektText(ru: 'А'), content: KonspektText(ru: 'а')),
      KonspektSection(id: 'b', title: KonspektText(ru: 'Б'), content: KonspektText(ru: 'б')),
    ],
  );
}

/// Записывает вызовы вместо отправки: «имя:параметры».
class _RecordingAnalytics extends AnalyticsService {
  final events = <String>[];

  @override
  void logKonspektOpened({required String categoryId, String? section}) =>
      events.add('konspekt_opened:$categoryId:$section');

  @override
  void logKonspektSectionOpened({required String categoryId, required String section}) =>
      events.add('konspekt_section_opened:$categoryId:$section');
}

void main() {
  late _RecordingAnalytics recorded;

  setUp(() {
    recorded = _RecordingAnalytics();
    getIt.registerSingleton<AnalyticsService>(recorded);
  });

  tearDown(() => getIt.reset());

  KonspektBloc bloc({String? section}) =>
      KonspektBloc(_StubKonspektRepository(), NetworkStatus(), '25', section);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('открытие с начала: одно событие без секции', () async {
    final b = bloc();
    await settle();
    expect(recorded.events, ['konspekt_opened:25:null']);
    await b.close();
  });

  test('открытие по ссылке на секцию: секция в самом событии открытия, '
      'без отдельного перехода', () async {
    final b = bloc(section: 'b');
    await settle();
    expect(recorded.events, ['konspekt_opened:25:b']);
    await b.close();
  });

  test('переход по содержанию логируется; неизвестная секция — нет', () async {
    final b = bloc();
    await settle();
    b.add(KonspektSectionRequested('b'));
    b.add(KonspektSectionRequested('nope'));
    await settle();
    expect(recorded.events, ['konspekt_opened:25:null', 'konspekt_section_opened:25:b']);
    await b.close();
  });
}
