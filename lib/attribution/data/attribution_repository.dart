import 'package:injectable/injectable.dart' show lazySingleton;

import '../../auth/data/graphql_client.dart';
import '../models/link_source.dart';

/// Атрибуция установок: отчёт о запуске (`reportAppOpen`, открыт и гостю) и
/// админка источников ссылок (закрыта правом `manage_attribution` на бэкенде).
@lazySingleton
class AttributionRepository {
  AttributionRepository(this._client);

  final GraphqlClient _client;

  /// Сообщить о запуске приложения (о загрузке веб-версии). Устройство бэкенд
  /// берёт из заголовка `X-Device-Id`, сеть — из адреса запроса. Возвращает,
  /// куда ведёт ссылка [linkCode], если запуск был по ней.
  ///
  /// [authenticated] — с токеном: так бэкенд засчитывает источник аккаунту.
  Future<String?> reportAppOpen({
    required String platform,
    required bool authenticated,
    DateTime? installedAt,
    String? playReferrer,
    String? linkCode,
    String? clickId,
  }) async {
    final data = await _client.run(
      r'''
        mutation ReportAppOpen($input: AppOpenInput!) {
          reportAppOpen(input: $input) {
            targetPath
            touch { sourceCode kind method }
          }
        }
      ''',
      variables: {
        'input': {
          'platform': platform,
          'installedAt': installedAt?.toUtc().toIso8601String(),
          'playReferrer': playReferrer,
          'linkCode': linkCode,
          'clickId': clickId,
        },
      },
      authenticated: authenticated,
    );
    final report = data['reportAppOpen'];
    return report is Map ? report['targetPath'] as String? : null;
  }

  /// Источники, новые сверху; архивные — по запросу.
  Future<List<LinkSource>> linkSources({bool includeArchived = false}) async {
    final data = await _client.run(
      '''
        query LinkSources(\$includeArchived: Boolean!) {
          linkSources(includeArchived: \$includeArchived) { ${LinkSource.fields} }
        }
      ''',
      variables: {'includeArchived': includeArchived},
      authenticated: true,
    );
    return [
      for (final raw in data['linkSources'] as List? ?? const [])
        LinkSource.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// Воронки источников по id — для кликов, сделанных начиная с [since]
  /// (за всё время без него). Источника без кликов в ответе нет.
  Future<Map<String, LinkSourceStats>> linkSourceStats({
    DateTime? since,
  }) async {
    final data = await _client.run(
      '''
        query LinkSourceStats(\$since: DateTime) {
          linkSourceStats(since: \$since) {
            sourceId
            stats { ${LinkSourceStats.fields} }
          }
        }
      ''',
      variables: {'since': since?.toUtc().toIso8601String()},
      authenticated: true,
    );
    return {
      for (final raw in data['linkSourceStats'] as List? ?? const [])
        (raw as Map<String, dynamic>)['sourceId'] as String:
            LinkSourceStats.fromJson(raw['stats'] as Map<String, dynamic>),
    };
  }

  /// Завести источник. Пустой [code] — бэкенд придумает короткий сам.
  ///
  /// Бросает [GraphqlException] с кодом `link_code_taken`, если код занят.
  Future<LinkSource> createLinkSource({
    required String name,
    String description = '',
    String? code,
    String? targetPath,
  }) async {
    final data = await _client.run(
      '''
        mutation CreateLinkSource(\$input: CreateLinkSourceInput!) {
          createLinkSource(input: \$input) { ${LinkSource.fields} }
        }
      ''',
      variables: {
        'input': {
          'name': name,
          'description': description,
          'code': _orNull(code),
          'targetPath': _orNull(targetPath),
        },
      },
      authenticated: true,
    );
    return LinkSource.fromJson(
      data['createLinkSource'] as Map<String, dynamic>,
    );
  }

  /// Переименовать источник, поменять описание или экран назначения. Код и
  /// ссылка остаются прежними.
  Future<LinkSource> updateLinkSource(
    String id, {
    required String name,
    String description = '',
    String? targetPath,
  }) async {
    final data = await _client.run(
      '''
        mutation UpdateLinkSource(\$id: ID!, \$input: UpdateLinkSourceInput!) {
          updateLinkSource(id: \$id, input: \$input) { ${LinkSource.fields} }
        }
      ''',
      variables: {
        'id': id,
        'input': {
          'name': name,
          'description': description,
          'targetPath': _orNull(targetPath),
        },
      },
      authenticated: true,
    );
    return LinkSource.fromJson(
      data['updateLinkSource'] as Map<String, dynamic>,
    );
  }

  /// Убрать источник в архив или вернуть. Ссылка работает в обоих случаях.
  Future<LinkSource> setArchived(String id, {required bool archived}) async {
    final data = await _client.run(
      '''
        mutation SetLinkSourceArchived(\$id: ID!, \$archived: Boolean!) {
          setLinkSourceArchived(id: \$id, archived: \$archived) {
            ${LinkSource.fields}
          }
        }
      ''',
      variables: {'id': id, 'archived': archived},
      authenticated: true,
    );
    return LinkSource.fromJson(
      data['setLinkSourceArchived'] as Map<String, dynamic>,
    );
  }

  static String? _orNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
