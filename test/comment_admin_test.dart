import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/quest/comment/comment_widget/comment_editor_panel.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuestionCommentDetails _details({
  required String status,
  String? text,
  String? draft,
}) =>
    QuestionCommentDetails(
      status: status,
      text: text,
      draft: draft,
      textRu: text,
      draftRu: draft,
    );

/// Поднимает плашку редактора с настоящими переводами (RU), чтобы проверять
/// подписи так, как их увидит редактор.
Future<void> _pumpPanel(
  WidgetTester tester,
  QuestionCommentDetails? details, {
  VoidCallback? onPublish,
}) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: CommentEditorPanel(
              details: details,
              isPublishing: false,
              onPublish: onPublish ?? () {},
              onEdit: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Признаки комментария для редактора', () {
    test('черновик поверх опубликованного текста считается неопубликованным',
        () {
      final details = _details(
        status: 'READY',
        text: 'старый текст',
        draft: 'новый текст',
      );

      expect(details.hasUnpublishedDraft, isTrue);
      expect(details.showsDraft, isTrue);
      expect(details.canPublish, isTrue);
    });

    test('совпадающий с текстом черновик публиковать нечего', () {
      final details = _details(
        status: 'READY',
        text: 'текст',
        draft: '  текст  ',
      );

      expect(details.hasUnpublishedDraft, isFalse);
      expect(details.showsDraft, isFalse);
      expect(details.canPublish, isFalse);
    });

    test('опубликованный комментарий без черновика публиковать нечего', () {
      final details = _details(status: 'READY', text: 'текст');

      expect(details.hasUnpublishedDraft, isFalse);
      expect(details.canPublish, isFalse);
    });

    test('черновик неопубликованного комментария можно опубликовать', () {
      final details = _details(status: 'DRAFT', draft: 'черновик');

      expect(details.hasUnpublishedDraft, isTrue);
      expect(details.showsDraft, isTrue);
      expect(details.canPublish, isTrue);
    });

    test('текст на модерации можно перевести в READY без черновика', () {
      final details = _details(status: 'MODERATION', text: 'текст');

      expect(details.hasUnpublishedDraft, isFalse);
      expect(details.showsDraft, isFalse);
      expect(details.canPublish, isTrue);
    });

    test('пустой комментарий публиковать нечего', () {
      final details = _details(status: 'PENDING');

      expect(details.hasUnpublishedDraft, isFalse);
      expect(details.canPublish, isFalse);
    });
  });

  group('Плашка редактора комментария', () {
    testWidgets(
        'у READY-комментария с черновиком есть метка и кнопка публикации',
        (tester) async {
      var published = 0;
      await _pumpPanel(
        tester,
        _details(status: 'READY', text: 'старый', draft: 'новый'),
        onPublish: () => published++,
      );

      expect(find.text('Черновик не опубликован'), findsOneWidget);
      final publish = find.text('Опубликовать черновик');
      expect(publish, findsOneWidget);

      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(published, 1);
    });

    testWidgets('у READY-комментария без черновика нет метки и публикации',
        (tester) async {
      await _pumpPanel(tester, _details(status: 'READY', text: 'текст'));

      expect(find.text('Черновик не опубликован'), findsNothing);
      expect(find.text('Опубликовать черновик'), findsNothing);
      expect(find.text('Опубликовать'), findsNothing);
      expect(find.text('Редактировать'), findsOneWidget);
    });

    testWidgets('черновик показывает метку и кнопку публикации',
        (tester) async {
      await _pumpPanel(tester, _details(status: 'DRAFT', draft: 'черновик'));

      expect(find.text('Черновик'), findsOneWidget);
      expect(find.text('Опубликовать черновик'), findsOneWidget);
    });

    testWidgets('без комментария доступно только редактирование',
        (tester) async {
      await _pumpPanel(tester, null);

      expect(find.text('Комментария пока нет'), findsOneWidget);
      expect(find.text('Опубликовать'), findsNothing);
      expect(find.text('Опубликовать черновик'), findsNothing);
      expect(find.text('Редактировать'), findsOneWidget);
    });
  });
}
