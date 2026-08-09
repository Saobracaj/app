import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../models/test_push_result.dart';

/// Отправка тестового пуша через мутацию `sendTestPush` в `saobracaj_backend`.
///
/// Получателя задаёт **почта**, а не id пользователя: человек, который
/// разбирается с жалобой, знает адрес и никогда — UUID. Мутация закрыта правом
/// `send_test_push`, так что вызывать её осмысленно только с экрана, который
/// это право уже проверил.
@lazySingleton
class PushTestRepository {
  PushTestRepository(this._client);

  final GraphqlClient _client;

  static const _sendTestPushMutation = r'''
    mutation SendTestPush(
      $email: String!
      $title: String
      $body: String
      $link: String
    ) {
      sendTestPush(email: $email, title: $title, body: $body, link: $link) {
        email
        userId
        devices
        notificationId
      }
    }
  ''';

  /// Поставить тестовый пуш в очередь. Пустые [title] / [body] / [link]
  /// не передаются — бэкенд подставит свои значения по умолчанию.
  ///
  /// Бросает [GraphqlException], если такой почты нет или права не хватает.
  Future<TestPushResult> sendTestPush({
    required String email,
    String? title,
    String? body,
    String? link,
  }) async {
    String? orNull(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    final data = await _client.run(
      _sendTestPushMutation,
      variables: {
        'email': email.trim(),
        'title': orNull(title),
        'body': orNull(body),
        'link': orNull(link),
      },
      authenticated: true,
    );
    final result = data['sendTestPush'];
    if (result is! Map) {
      throw GraphqlException('Пустой ответ сервера');
    }
    return TestPushResult.fromJson(result.cast<String, dynamic>());
  }
}
