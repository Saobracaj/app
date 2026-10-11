import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/chat/state_management/support_chats_bloc.dart';
import 'package:saobracaj/chat/state_management/support_chats_events.dart';
import 'package:saobracaj/chat/state_management/support_chats_state.dart';
import 'package:saobracaj/notifications/data/push_message_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Список обращений у модератора (SAOBR-522): обращение, о котором только что
/// пришёл пуш, должно появиться в списке само, а его превью — показывать текст
/// пользователя, а не служебную шапку репорта.

/// Сервер: отдаёт список обращений, который тест меняет между запросами.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.threads);

  List<Map<String, dynamic>> threads;

  /// Сколько раз список запрашивали.
  int listRequests = 0;

  /// Ронять ли следующий запрос списка ошибкой сервера.
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final raw = options.data;
    final body = raw is String
        ? json.decode(raw) as Map<String, dynamic>
        : (raw as Map).cast<String, dynamic>();
    final query = body['query'].toString();
    if (!query.contains('supportChats')) {
      throw StateError('неожиданный запрос: $query');
    }
    listRequests++;
    if (failNext) {
      failNext = false;
      return ResponseBody.fromString(
        json.encode({
          'errors': [
            {'message': 'boom'},
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      json.encode({
        'data': {
          'supportChats': {
            'totalCount': threads.length,
            'hasNextPage': false,
            'nodes': threads,
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _thread(
  String id, {
  String email = 'user@example.com',
  String preview = 'привет',
  int unread = 1,
}) => {
  'id': id,
  'entityType': 'SUPPORT',
  'entityId': 'u-$id',
  'userId': 'u-$id',
  'userDisplayName': '',
  'userEmail': email,
  'createdAt': '2026-10-11T21:05:16Z',
  'lastMessageAt': '2026-10-11T21:05:16Z',
  'lastMessagePreview': preview,
  'unreadCount': unread,
  'messagesCount': 1,
};

/// Крутить цикл событий, пока условие не станет истинным (или не выйдет срок).
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

({
  SupportChatsBloc bloc,
  PushMessageService pushes,
  List<SupportChatsState> seen,
})
_bloc(_FakeApi api) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final repository = ChatRepository(
    client,
    GraphqlSubscriptionClient(
      client,
      storage,
      endpoint: Uri.parse('ws://localhost:1/ws'),
      retryDelay: (_) => const Duration(days: 1),
    ),
  );
  final pushes = PushMessageService();
  // Без биндинга виджетов за возвратом из фона следить нельзя — в этих тестах
  // проверяется реакция на пуш и явную просьбу перечитать.
  final bloc = SupportChatsBloc(repository, pushes, watchLifecycle: false);
  final seen = <SupportChatsState>[];
  bloc.stream.listen(seen.add);
  return (bloc: bloc, pushes: pushes, seen: seen);
}

const _reportBody =
    'Report · summary\nhttps://saobracaj.gleb.at/question/7922\n\nNije na srpski';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Токены клиент читает из SharedPreferences — без мока канал молча виснет.
  SharedPreferences.setMockInitialValues({});

  group('SupportChatsBloc', () {
    test('первое чтение показывает обращения', () async {
      final api = _FakeApi([_thread('t1')]);
      final h = _bloc(api);
      h.bloc.add(SupportChatsRequested());
      await _until(() => !h.bloc.state.loading);

      expect(h.bloc.state.threads.map((t) => t.id), ['t1']);
      expect(h.bloc.state.totalCount, 1);
      expect(api.listRequests, 1);
      await h.bloc.close();
    });

    test(
      'пуш о новом обращении в foreground перечитывает список без индикатора',
      () async {
        final api = _FakeApi([_thread('t1')]);
        final h = _bloc(api);
        h.bloc.add(SupportChatsRequested());
        await _until(() => !h.bloc.state.loading);
        h.seen.clear();

        api.threads = [
          _thread(
            't2',
            preview: _reportBody,
            email: 'x@privaterelay.appleid.com',
          ),
          _thread('t1'),
        ];
        h.pushes.handleForeground(
          const RemoteMessage(
            notification: RemoteNotification(
              title: 'Новое обращение',
              body: 'Nije na srpski',
            ),
            data: {'link': 'saobracaj://support/threads/t2'},
          ),
        );
        await _until(() => h.bloc.state.threads.length == 2);

        expect(h.bloc.state.threads.first.id, 't2');
        expect(h.bloc.state.totalCount, 2);
        expect(api.listRequests, 2);
        // Тихое обновление: индикатор загрузки не мигал.
        expect(h.seen.any((s) => s.loading), isFalse);
        await h.bloc.close();
      },
    );

    test('пуш про обсуждение вопроса список не трогает', () async {
      final api = _FakeApi([_thread('t1')]);
      final h = _bloc(api);
      h.bloc.add(SupportChatsRequested());
      await _until(() => !h.bloc.state.loading);

      h.pushes.handleForeground(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Обсуждение', body: '…'),
          data: {'link': 'saobracaj://question/7922?chat=1&message=m1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(api.listRequests, 1);
      await h.bloc.close();
    });

    test('неудачное тихое обновление оставляет прежний список', () async {
      final api = _FakeApi([_thread('t1')]);
      final h = _bloc(api);
      h.bloc.add(SupportChatsRequested());
      await _until(() => !h.bloc.state.loading);

      api.failNext = true;
      h.bloc.add(SupportChatsRefreshed());
      await _until(() => api.listRequests == 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(h.bloc.state.threads.map((t) => t.id), ['t1']);
      expect(h.bloc.state.errorMessage, isNull);
      expect(h.bloc.state.loading, isFalse);
      await h.bloc.close();
    });

    test('фильтр «только непрочитанные» переживает тихое обновление', () async {
      final api = _FakeApi([_thread('t1')]);
      final h = _bloc(api);
      h.bloc.add(SupportChatsFilterToggled(true));
      await _until(() => !h.bloc.state.loading);

      h.bloc.add(SupportChatsRefreshed());
      await _until(() => api.listRequests == 2);

      expect(h.bloc.state.onlyUnread, isTrue);
      await h.bloc.close();
    });
  });

  group('Chat.previewLine', () {
    Chat chat(String preview) => Chat.parse(_thread('t', preview: preview));

    test('у репорта показывает шапку и текст пользователя, без ссылки', () {
      expect(
        chat(_reportBody).previewLine,
        'Report · summary · Nije na srpski',
      );
    });

    test('многострочное сообщение склеивается в одну строку', () {
      expect(
        chat('Здравствуйте!\n\nНе работает оплата  \n').previewLine,
        'Здравствуйте! · Не работает оплата',
      );
    });

    test('сообщение из одной ссылки остаётся ссылкой', () {
      expect(
        chat('https://saobracaj.gleb.at/question/7922').previewLine,
        'https://saobracaj.gleb.at/question/7922',
      );
    });

    test('пустое превью остаётся пустым', () {
      expect(chat('').previewLine, '');
    });
  });
}
