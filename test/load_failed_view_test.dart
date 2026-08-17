import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/presentation/load_failed_view.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// Общий блок «не удалось загрузить — повторить»: текст, иконка offline и
/// кнопка, вызывающая переданный retry (в обеих раскладках).
///
/// Без EasyLocalization `tr()` возвращает сам ключ — этого достаточно, чтобы
/// проверить, какой текст выбран.
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('полная раскладка: сообщение + кнопка «повторить»', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(LoadFailedView(message: 'Нет сети', onRetry: () => retries++)),
    );

    expect(find.text('Нет сети'), findsOneWidget);
    expect(find.text(LocaleKeys.network_retry), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(retries, 1);
  });

  testWidgets('без сообщения — общий текст, offline меняет иконку', (tester) async {
    await tester.pumpWidget(
      _app(LoadFailedView(compact: true, offline: true, onRetry: () {})),
    );

    expect(find.text(LocaleKeys.network_loadFailed), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('компактная раскладка: retry — текстовая кнопка', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(
        LoadFailedView(compact: true, message: 'x', onRetry: () => retries++),
      ),
    );

    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
    expect(find.byType(FilledButton), findsNothing);
  });
}
