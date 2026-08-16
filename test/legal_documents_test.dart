import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/legal_documents.dart';

void main() {
  group('legalDocumentUri', () {
    test('сербский — базовая версия без суффикса языка', () {
      expect(
        legalDocumentUri(LegalDocument.privacyPolicy, 'sr').toString(),
        'https://docs.saobracaj.gleb.at/privacy_policy.html',
      );
      expect(
        legalDocumentUri(LegalDocument.termsOfUse, 'sr').toString(),
        'https://docs.saobracaj.gleb.at/terms_of_use.html',
      );
    });

    test('русский и английский открывают переводы', () {
      expect(
        legalDocumentUri(LegalDocument.privacyPolicy, 'ru').toString(),
        'https://docs.saobracaj.gleb.at/privacy_policy_ru.html',
      );
      expect(
        legalDocumentUri(LegalDocument.termsOfUse, 'en').toString(),
        'https://docs.saobracaj.gleb.at/terms_of_use_en.html',
      );
    });

    test('неизвестный язык ведёт на юридически значимую сербскую версию', () {
      expect(
        legalDocumentUri(LegalDocument.privacyPolicy, 'de').toString(),
        'https://docs.saobracaj.gleb.at/privacy_policy.html',
      );
    });

    test('страница удаления аккаунта одна для всех языков', () {
      for (final lang in ['sr', 'ru', 'en']) {
        expect(
          legalDocumentUri(LegalDocument.deleteAccount, lang).toString(),
          'https://docs.saobracaj.gleb.at/delete_account.html',
        );
      }
    });
  });
}
