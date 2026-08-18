import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/chat/models/chat_update.dart';
import 'package:saobracaj/chat/presentation/linked_text.dart';
import 'package:saobracaj/chat/presentation/chat_page.dart';

/// Тесты «чата с разработчиком» (lib/chat/): разбор ответа бэкенда,
/// распознавание картинок и ссылок, маршруты и диплинки из пуша.
void main() {
  _chatModelTests();
  group('ChatAttachment', () {
    test('тип вложения приходит с сервера в верхнем регистре', () {
      expect(ChatAttachmentKind.parse('IMAGE'), ChatAttachmentKind.image);
      expect(
        ChatAttachmentKind.parse('QUESTION'),
        ChatAttachmentKind.question,
      );
      expect(ChatAttachmentKind.parse('FILE'), ChatAttachmentKind.file);
      // Незнакомый тип — файл: скачать можно всегда, а показать инлайн нет.
      expect(ChatAttachmentKind.parse(null), ChatAttachmentKind.file);
      expect(ChatAttachmentKind.parse('WAT'), ChatAttachmentKind.file);
    });

    test('размер показывается в человеческих единицах', () {
      ChatAttachment sized(int bytes) => ChatAttachment(
        id: '1',
        kind: ChatAttachmentKind.file,
        sizeBytes: bytes,
        createdAt: DateTime(2026),
      );
      expect(sized(0).readableSize, '');
      expect(sized(512).readableSize, '512 B');
      expect(sized(2048).readableSize, '2.0 KB');
      expect(sized(20 * 1024 * 1024).readableSize, '20 MB');
    });

    test('ссылка на вопрос ничего не хранит', () {
      final attachment = ChatAttachment.parse({
        'id': 'a1',
        'kind': 'QUESTION',
        'questionId': 1234,
        'createdAt': '2026-08-07T10:00:00Z',
      });
      expect(attachment.kind, ChatAttachmentKind.question);
      expect(attachment.questionId, 1234);
      expect(attachment.url, isNull);
      expect(attachment.readableSize, '');
    });
  });

  group('ChatMessage', () {
    test('разбирает сообщение с вложениями и статусом прочтения', () {
      final message = ChatMessage.parse({
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
      expect(message.attachments.single.kind, ChatAttachmentKind.image);
      expect(message.attachments.single.url, 'https://example.com/signed');
    });

    test('непрочитанное сообщение приходит без readAt', () {
      final message = ChatMessage.parse({
        'id': 'm2',
        'createdAt': '2026-08-07T10:00:00Z',
        'readAt': null,
      });
      expect(message.isRead, isFalse);
      expect(message.attachments, isEmpty);
      expect(message.fromStaff, isFalse);
    });
  });

  group('Chat', () {
    test('в списке модератора тред подписан именем, иначе почтой', () {
      final named = Chat.parse({
        'id': 't1',
        'userDisplayName': 'Ана',
        'userEmail': 'ana@example.com',
        'createdAt': '2026-08-07T10:00:00Z',
      });
      final anonymous = Chat.parse({
        'id': 't2',
        'userEmail': 'zoran@example.com',
        'createdAt': '2026-08-07T10:00:00Z',
      });
      expect(named.title, 'Ана');
      expect(anonymous.title, 'zoran@example.com');
    });

    test('страницы разбираются вместе со счётчиками', () {
      final threads = ChatConnection.parse({
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
      final messages = ChatMessagePage.parse({'nodes': null});
      expect(messages.nodes, isEmpty);
      expect(messages.hasNextPage, isFalse);
    });
  });

  group('картинки в сообщениях', () {
    ChatAttachment attachment({
      ChatAttachmentKind kind = ChatAttachmentKind.file,
      String fileName = '',
      String contentType = '',
    }) => ChatAttachment(
      id: 'a1',
      kind: kind,
      fileName: fileName,
      contentType: contentType,
      createdAt: DateTime(2026),
    );

    test('картинка узнаётся по типу с сервера', () {
      expect(attachment(kind: ChatAttachmentKind.image).isImage, isTrue);
    });

    test('старое вложение без MIME-типа узнаётся по расширению', () {
      // Пока приложение не подставляло content-type, скриншот с телефона
      // приезжал как FILE + application/octet-stream и не показывался вовсе.
      expect(
        attachment(
          fileName: 'IMG_0042.HEIC',
          contentType: 'application/octet-stream',
        ).isImage,
        isTrue,
      );
      expect(attachment(contentType: 'image/png').isImage, isTrue);
    });

    test('файл и ссылка на вопрос картинками не считаются', () {
      expect(attachment(fileName: 'отчёт.pdf').isImage, isFalse);
      expect(attachment(fileName: 'без расширения').isImage, isFalse);
      expect(
        attachment(
          kind: ChatAttachmentKind.question,
          fileName: 'x.png',
        ).isImage,
        isFalse,
      );
    });

    test('тип содержимого угадывается по имени файла', () {
      expect(contentTypeForFileName('shot.PNG'), 'image/png');
      expect(contentTypeForFileName('фото.jpeg'), 'image/jpeg');
      expect(contentTypeForFileName('doc.pdf'), 'application/pdf');
      // Незнакомое расширение — пусть транспорт ставит octet-stream сам.
      expect(contentTypeForFileName('dump.bin'), isNull);
      expect(contentTypeForFileName('README'), isNull);
    });
  });

  group('ссылки в сообщениях', () {
    test('находит ссылку и не забирает знак препинания', () {
      final links = findLinks('смотри https://example.com/a. и всё');
      expect(links, hasLength(1));
      expect(links.single.uri.toString(), 'https://example.com/a');
    });

    test('голый www превращается в https', () {
      final links = findLinks('зайди на www.example.com');
      expect(links.single.uri.toString(), 'https://www.example.com');
    });

    test('незакрытая скобка не попадает в адрес, закрытая — попадает', () {
      expect(
        findLinks('(см. https://example.com/x)').single.uri.toString(),
        'https://example.com/x',
      );
      expect(
        findLinks('https://ru.wikipedia.org/wiki/Знак_(значения)')
            .single
            .uri
            .toString(),
        contains('(%D0%B7%D0%BD%D0%B0%D1%87%D0%B5%D0%BD%D0%B8%D1%8F)'),
      );
    });

    test('текст без ссылок остаётся текстом', () {
      expect(findLinks('просто сообщение про http и www'), isEmpty);
    });

    test('свои ссылки — только хост приложения и его поддомены', () {
      expect(isInternalLink(Uri.parse('https://saobracaj.gleb.at/q/1')), isTrue);
      expect(
        isInternalLink(Uri.parse('https://api.saobracaj.gleb.at/graphql')),
        isTrue,
      );
      expect(isInternalLink(Uri.parse('https://example.com')), isFalse);
      // Подделка под свой хост чужим доменом второго уровня.
      expect(
        isInternalLink(Uri.parse('https://saobracaj.gleb.at.evil.com')),
        isFalse,
      );
    });
  });

  group('имя автора сообщения', () {
    test('display name показывается как есть', () {
      final message = ChatMessage(
        id: 'm1',
        authorDisplayName: '  Ана  ',
        createdAt: DateTime(2026),
      );
      expect(authorName(message), 'Ана');
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

void _chatModelTests() {
  group('универсальный чат: разбор новых полей', () {
    test('чат несёт сущность, тред-родителя и состояние колокольчика', () {
      final chat = Chat.parse(const {
        'id': 'c1',
        'entityType': 'MESSAGE_THREAD',
        'entityId': 'm1',
        'parentMessageId': 'm1',
        'isGroup': false,
        'notificationsEnabled': true,
        'createdAt': '2026-08-18T10:00:00Z',
      });

      expect(chat.entityType, ChatEntityType.messageThread);
      expect(chat.isThread, isTrue);
      expect(chat.parentMessageId, 'm1');
      expect(chat.notificationsEnabled, isTrue);
    });

    test('незнакомая сущность читается как чат с разработчиком', () {
      final chat = Chat.parse(const {
        'id': 'c1',
        'entityType': 'WAT',
        'createdAt': '2026-08-18T10:00:00Z',
      });
      expect(chat.entityType, ChatEntityType.support);
      expect(chat.isThread, isFalse);
      // Пустая строка идентификатора родителя — это «родителя нет».
      expect(chat.parentMessageId, isNull);
    });

    test('сообщение знает про правку и про свой тред', () {
      final edited = ChatMessage.parse(const {
        'id': 'm1',
        'body': 'текст',
        'createdAt': '2026-08-18T10:00:00Z',
        'editedAt': '2026-08-18T10:05:00Z',
        'threadChatId': 'c2',
        'replyCount': 3,
      });
      expect(edited.isEdited, isTrue);
      expect(edited.hasThread, isTrue);

      final plain = ChatMessage.parse(const {
        'id': 'm2',
        'body': 'текст',
        'createdAt': '2026-08-18T10:00:00Z',
      });
      expect(plain.isEdited, isFalse);
      // Тред без ответов ссылкой не показывается — показывать нечего.
      expect(plain.hasThread, isFalse);
      expect(
        ChatMessage.parse(const {
          'id': 'm3',
          'createdAt': '2026-08-18T10:00:00Z',
          'threadChatId': 'c3',
          'replyCount': 0,
        }).hasThread,
        isFalse,
      );
    });

    test('виды событий подписки покрывают правку и открытие треда', () {
      expect(
        ChatChangeKind.parse('MESSAGE_EDITED'),
        ChatChangeKind.messageEdited,
      );
      expect(
        ChatChangeKind.parse('THREAD_OPENED'),
        ChatChangeKind.threadOpened,
      );
    });
  });
}
