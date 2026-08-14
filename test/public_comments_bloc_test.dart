import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:saobracaj/public_comments/data/public_comments_repository.dart';
import 'package:saobracaj/public_comments/models/public_comment.dart';
import 'package:saobracaj/public_comments/models/public_comment_page.dart';
import 'package:saobracaj/public_comments/state_management/comments_bloc.dart';
import 'package:saobracaj/public_comments/state_management/comments_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ключ настройки push-уведомлений — тот же, что и в [CommentsBloc]
/// и в экране уведомлений.
const _pushNotifKey = 'notif_push_enabled';

/// Клиент-заглушка: в этих тестах сеть не используется.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async =>
      const {};
}

/// Заглушка репозитория комментариев: запоминает вызовы подписки и отдаёт
/// заранее заданный созданный комментарий.
class _FakeCommentsRepository extends PublicCommentsRepository {
  _FakeCommentsRepository(super.client, {required this.created});

  final PublicComment created;

  /// Аргументы всех вызовов `setCommentSubscription`.
  final List<({String id, bool subscribed})> subscriptionCalls = [];

  @override
  Future<PublicCommentPage> questionComments(
    int questionId, {
    int offset = 0,
    int limit = 30,
    bool authenticated = true,
  }) async =>
      PublicCommentPage(nodes: [created], totalCount: 1);

  @override
  Future<PublicComment> addComment({
    required int questionId,
    String? parentId,
    required String body,
  }) async =>
      created;

  @override
  Future<bool> setCommentSubscription(String id, bool subscribed) async {
    subscriptionCalls.add((id: id, subscribed: subscribed));
    return subscribed;
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.client);
}

class _FakePermissions extends NotificationPermissions {
  @override
  Future<NotificationPermissionState> status() async =>
      const NotificationPermissionState(granted: true, permanentlyDenied: false);

  @override
  Future<NotificationPermissionState> request() async =>
      const NotificationPermissionState(granted: true, permanentlyDenied: false);

  @override
  Future<void> openSettings() async {}
}

PublicComment _comment({
  String id = '1',
  bool subscribedByMe = false,
}) =>
    PublicComment(
      id: id,
      questionId: 42,
      body: 'текст',
      createdAt: DateTime(2026, 8, 3),
      subscribedByMe: subscribedByMe,
    );

({CommentsBloc bloc, _FakeCommentsRepository comments}) _buildBloc(
  PublicComment created,
) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final comments = _FakeCommentsRepository(client, created: created);
  final authRepo = AuthRepository(client, storage, AnalyticsService());
  return (
    bloc: CommentsBloc(
      comments,
      _FakeProfileRepository(client),
      AuthBloc(authRepo, GraphqlSubscriptionClient(client, storage)),
      authRepo,
      _FakePermissions(),
      42,
      null,
    ),
    comments: comments,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Фокус в поле ответа по кнопке «Ответить»', () {
    test('запрос фокуса не раскрывает список ответов', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(ReplyFocusRequested('7'));
      final state =
          await built.bloc.stream.firstWhere((s) => s.replyFocusTarget != null);

      expect(state.replyFocusTarget, '7');
      expect(state.replyFocusRequestId, 1);
      // Ветка ответов остаётся свёрнутой — раскрывать её кнопка не должна.
      expect(state.expandedThreads, isEmpty);
    });

    test('повторное нажатие увеличивает счётчик запросов фокуса', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(ReplyFocusRequested('7'));
      await built.bloc.stream.firstWhere((s) => s.replyFocusRequestId == 1);
      built.bloc.add(ReplyFocusRequested('7'));
      final state =
          await built.bloc.stream.firstWhere((s) => s.replyFocusRequestId == 2);

      expect(state.replyFocusTarget, '7');
    });

    test('«Показать предыдущие» по-прежнему раскрывает ветку', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(RepliesExpanded('7'));
      final state = await built.bloc.stream
          .firstWhere((s) => s.expandedThreads.isNotEmpty);

      expect(state.expandedThreads, contains('7'));
    });

    test('крестик на чипе сбрасывает цель ответа', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(ReplyFocusRequested('7'));
      await built.bloc.stream.firstWhere((s) => s.replyFocusTarget != null);
      built.bloc.add(ReplyTargetCleared());
      final state = await built.bloc.stream
          .firstWhere((s) => s.replyFocusTarget == null);

      // Счётчик фокуса не трогаем — чистится только цель.
      expect(state.replyFocusRequestId, 1);
    });

    test('успешная отправка сбрасывает цель ответа', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(ReplyFocusRequested('1'));
      await built.bloc.stream.firstWhere((s) => s.replyFocusTarget != null);
      built.bloc.add(CommentSubmitted('привет', parentId: '1'));
      final state = await built.bloc.stream.firstWhere(
        (s) => s.comments.isNotEmpty && !s.submitting,
      );

      expect(state.replyFocusTarget, isNull);
      // Тред, куда лёг ответ, раскрыт.
      expect(state.expandedThreads, contains('1'));
    });
  });

  group('Жалоба на комментарий (UI-состояние сессии)', () {
    test('подтверждённая жалоба запоминается в reportedIds', () async {
      final built = _buildBloc(_comment());
      built.bloc.add(CommentReported('9'));
      final state = await built.bloc.stream
          .firstWhere((s) => s.reportedIds.isNotEmpty);

      expect(state.reportedIds, {'9'});
    });
  });

  group('Предложение подписаться на ответы', () {
    test(
      'показывается, если подписки на уведомления ещё нет',
      () async {
        final built = _buildBloc(_comment());
        built.bloc.add(CommentSubmitted('привет'));
        final state = await built.bloc.stream
            .firstWhere((s) => s.subscriptionPromptFor != null);

        expect(state.subscriptionPromptFor?.id, '1');
        // Молча подписывать пользователя до его согласия нельзя.
        expect(built.comments.subscriptionCalls, isEmpty);
      },
    );

    test(
      'не показывается, если push уже включён — подписка оформляется молча',
      () async {
        SharedPreferences.setMockInitialValues({_pushNotifKey: true});
        final built = _buildBloc(_comment());
        built.bloc.add(CommentSubmitted('привет'));
        final state = await built.bloc.stream.firstWhere(
          (s) => s.comments.isNotEmpty && s.comments.first.subscribedByMe,
        );

        expect(state.subscriptionPromptFor, isNull);
        expect(built.comments.subscriptionCalls, hasLength(1));
        expect(built.comments.subscriptionCalls.single.subscribed, isTrue);
      },
    );

    test(
      'не показывается, если пользователь уже подписан на эту ветку',
      () async {
        final built = _buildBloc(_comment(subscribedByMe: true));
        built.bloc.add(CommentSubmitted('привет'));
        final state =
            await built.bloc.stream.firstWhere((s) => s.comments.isNotEmpty);

        expect(state.subscriptionPromptFor, isNull);
        expect(built.comments.subscriptionCalls, isEmpty);
      },
    );
  });
}
