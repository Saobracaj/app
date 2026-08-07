import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/support_chat/models/support_chat.dart';

/// Тесты «чата с разработчиком» (lib/support_chat/): разбор ответа бэкенда,
/// маршруты и диплинки из пуша.
void main() {
  group('SupportAttachment', () {
    test('тип вложения приходит с сервера в верхнем регистре', () {
      expect(SupportAttachmentKind.parse('IMAGE'), SupportAttachmentKind.image);
      expect(
        SupportAttachmentKind.parse('QUESTION'),
        SupportAttachmentKind.question,
      );
      expect(SupportAttachmentKind.parse('FILE'), SupportAttachmentKind.file);
      // Незнакомый тип — файл: скачать можно всегда, а показать инлайн нет.
      expect(SupportAttachmentKind.parse(null), SupportAttachmentKind.file);
      expect(SupportAttachmentKind.parse('WAT'), SupportAttachmentKind.file);
    });

    test('размер показывается в человеческих единицах', () {
      SupportAttachment sized(int bytes) => SupportAttachment(
        id: '1',
        kind: SupportAttachmentKind.file,
        sizeBytes: bytes,
        createdAt: DateTime(2026),
      );
      expect(sized(0).readableSize, '');
      expect(sized(512).readableSize, '512 B');
      expect(sized(2048).readableSize, '2.0 KB');
      expect(sized(20 * 1024 * 1024).readableSize, '20 MB');
    });

    test('ссылка на вопрос ничего не хранит', () {
      final attachment = SupportAttachment.parse({
        'id': 'a1',
        'kind': 'QUESTION',
        'questionId': 1234,
        'createdAt': '2026-08-07T10:00:00Z',
      });
      expect(attachment.kind, SupportAttachmentKind.question);
      expect(attachment.questionId, 1234);
      expect(attachment.url, isNull);
      expect(attachment.readableSize, '');
    });
  });

  group('SupportMessage', () {
    test('разбирает сообщение с вложениями и статусом прочтения', () {
      final message = SupportMessage.parse({
        'id': 'm1',
        'threadId': 't1',
        'authorId': 'u1',
        'authorDisplayName': 'Пера',
        'fromStaff': true,
        'body': 'смотрим',
        'createdAt': '2026-08-07T10:00:00Z',
        'readAt': '2026-08-07T11:00:00Z',
        'attachments': [
          {
            'id': 'a1',
            'kind': 'IMAGE',
            'fileName': 'screen.png',
            'contentType': 'image/png',
            'sizeBytes': 1024,
            'url': 'https://example.com/signed',
            'createdAt': '2026-08-07T10:00:00Z',
          },
        ],
      });

      expect(message.fromStaff, isTrue);
      expect(message.isRead, isTrue);
      expect(message.attachments.single.kind, SupportAttachmentKind.image);
      expect(message.attachments.single.url, 'https://example.com/signed');
    });

    test('непрочитанное сообщение приходит без readAt', () {
      final message = SupportMessage.parse({
        'id': 'm2',
        'createdAt': '2026-08-07T10:00:00Z',
        'readAt': null,
      });
      expect(message.isRead, isFalse);
      expect(message.attachments, isEmpty);
      expect(message.fromStaff, isFalse);
    });
  });

  group('SupportThread', () {
    test('в списке модератора тред подписан именем, иначе почтой', () {
      final named = SupportThread.parse({
        'id': 't1',
        'userDisplayName': 'Ана',
        'userEmail': 'ana@example.com',
        'createdAt': '2026-08-07T10:00:00Z',
      });
      final anonymous = SupportThread.parse({
        'id': 't2',
        'userEmail': 'zoran@example.com',
        'createdAt': '2026-08-07T10:00:00Z',
      });
      expect(named.title, 'Ана');
      expect(anonymous.title, 'zoran@example.com');
    });

    test('страницы разбираются вместе со счётчиками', () {
      final threads = SupportThreadPage.parse({
        'totalCount': 3,
        'hasNextPage': true,
        'nodes': [
          {'id': 't1', 'createdAt': '2026-08-07T10:00:00Z', 'unreadCount': 2},
        ],
      });
      expect(threads.totalCount, 3);
      expect(threads.hasNextPage, isTrue);
      expect(threads.nodes.single.unreadCount, 2);

      // Пустой/битый ответ не роняет экран.
      final messages = SupportMessagePage.parse({'nodes': null});
      expect(messages.nodes, isEmpty);
      expect(messages.hasNextPage, isFalse);
    });
  });

  group('маршруты и диплинки', () {
    test('чат, список обращений и один тред — это пути', () {
      expect(routes.get('/support'), isNotNull);
      expect(routes.get('/support/threads'), isNotNull);
      expect(routes.get('/support/threads/abc-123'), isNotNull);
    });

    test('пуш о поддержке открывает нужный экран', () {
      // Ответ разработчика — свой чат.
      expect(deepLinkPathFor(Uri.parse('saobracaj://support')), '/support');
      // Новое обращение — конкретный тред у модератора.
      expect(
        deepLinkPathFor(Uri.parse('saobracaj://support/threads/abc-123')),
        '/support/threads/abc-123',
      );
    });
  });
}
