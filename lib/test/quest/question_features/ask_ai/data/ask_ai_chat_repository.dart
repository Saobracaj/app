import 'package:injectable/injectable.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';

/// The live Ask-AI chat transport: history, the daily quota, the `askAi`
/// mutation and the `askAiStream` subscription of `saobracaj_backend`.
/// Everything is behind the premium `ask_ai` flag on the server, and the
/// conversation is keyed by `(user, scope)` there — the client never says who
/// is asking.
///
/// The mutation returns only the assistant's reply; the user's own message is
/// persisted server-side but not echoed back, so the caller appends its own
/// bubble itself.
@lazySingleton
class AskAiChatRepository {
  AskAiChatRepository(this._client, this._subscriptions);

  final GraphqlClient _client;
  final GraphqlSubscriptionClient _subscriptions;

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

  /// The reply being generated in this conversation, live: text deltas, tool
  /// statuses, the finished message. The server filters the feed to the
  /// session user's own conversation, exactly like everything else here.
  ///
  /// The stream starts the subscription on its first listener and stops it
  /// when the listener leaves. (Re)connections need no reaction from the
  /// caller — the mutation delivers the whole reply regardless, so a missed
  /// delta costs nothing durable.
  Stream<AskAiStreamUpdate> replyStream(AskAiChatScope scope, String scopeId) {
    return _subscriptions
        .subscribe(
          '''
            subscription AskAiStream(\$scope: AskAiScope!, \$scopeId: String!) {
              askAiStream(scope: \$scope, scopeId: \$scopeId) {
                kind text tool message { $_messageFields }
              }
            }
          ''',
          variables: {'scope': scope.wireName, 'scopeId': scopeId},
        )
        .map<AskAiStreamUpdate?>(
          (message) => switch (message) {
            GraphqlSubscriptionData(:final data) when data['askAiStream'] is Map
                => AskAiStreamUpdate.parse(
                    (data['askAiStream'] as Map).cast<String, dynamic>(),
                  ),
            _ => null,
          },
        )
        .where((update) => update != null)
        .cast<AskAiStreamUpdate>();
  }
}
