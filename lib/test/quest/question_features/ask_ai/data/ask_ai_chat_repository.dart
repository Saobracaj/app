import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';

/// The live Ask-AI chat transport: history, the daily quota and the `askAi`
/// mutation of `saobracaj_backend`. Everything is behind the premium `ask_ai`
/// flag on the server, and the conversation is keyed by `(user, scope)` there —
/// the client never says who is asking.
///
/// The mutation returns only the assistant's reply; the user's own message is
/// persisted server-side but not echoed back, so the caller appends its own
/// bubble itself.
@lazySingleton
class AskAiChatRepository {
  AskAiChatRepository(this._client);

  final GraphqlClient _client;

  static const _messageFields = 'id role content createdAt';

  Future<List<AskAiChatMessage>> history(
    AskAiChatScope scope,
    String scopeId,
  ) async {
    final data = await _client.run(
      '''
        query AskAiHistory(\$scope: AskAiScope!, \$scopeId: String!) {
          askAiHistory(scope: \$scope, scopeId: \$scopeId) { $_messageFields }
        }
      ''',
      variables: {'scope': scope.wireName, 'scopeId': scopeId},
      authenticated: true,
    );
    final raw = data['askAiHistory'];
    return raw is List
        ? raw
              .whereType<Map>()
              .map((e) => AskAiChatMessage.parse(e.cast<String, dynamic>()))
              .toList()
        : const [];
  }

  Future<AskAiQuota> quota() async {
    final data = await _client.run(
      'query AskAiQuota { askAiQuota { limit used remaining } }',
      authenticated: true,
    );
    return AskAiQuota.parse(
      (data['askAiQuota'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }

  /// Sends one message and returns the assistant's whole reply.
  Future<AskAiChatMessage> ask(
    AskAiChatScope scope,
    String scopeId,
    String message,
  ) async {
    final data = await _client.run(
      '''
        mutation AskAi(\$scope: AskAiScope!, \$scopeId: String!, \$message: String!) {
          askAi(scope: \$scope, scopeId: \$scopeId, message: \$message) { $_messageFields }
        }
      ''',
      variables: {
        'scope': scope.wireName,
        'scopeId': scopeId,
        'message': message,
      },
      authenticated: true,
    );
    return AskAiChatMessage.parse(
      (data['askAi'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }
}
