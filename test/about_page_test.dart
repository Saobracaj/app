import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/about/about_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Раздел «О приложении» ссылается на внешние юридические документы:
/// адрес в подзаголовке должен соответствовать языку интерфейса, а иконка
/// подсказывать, что откроется браузер.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Locale locale) {
    return EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: locale,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(
            body: SingleChildScrollView(child: AboutContent()),
          ),
        ),
      ),
    );
  }

  testWidgets('русский интерфейс ведёт на русские переводы документов', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const Locale('ru')));
    await tester.pumpAndSettle();

    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(
      find.text('docs.saobracaj.gleb.at/privacy_policy_ru.html'),
      findsOneWidget,
    );
    expect(
      find.text('docs.saobracaj.gleb.at/terms_of_use_ru.html'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_new), findsNWidgets(2));
  });

  testWidgets('сербский интерфейс ведёт на базовые (сербские) версии', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const Locale('sr')));
    await tester.pumpAndSettle();

    expect(find.text('Политика приватности'), findsOneWidget);
    expect(find.text('Услови коришћења'), findsOneWidget);
    expect(
      find.text('docs.saobracaj.gleb.at/privacy_policy.html'),
      findsOneWidget,
    );
    expect(
      find.text('docs.saobracaj.gleb.at/terms_of_use.html'),
      findsOneWidget,
    );
  });
}
