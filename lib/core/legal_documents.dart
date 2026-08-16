/// Публичные юридические документы приложения.
///
/// Документы живут в отдельном публичном репозитории
/// (github.com/Saobracaj/public_documents) и публикуются через GitHub Pages
/// на `docs.saobracaj.gleb.at`. Приложение их не встраивает — только открывает
/// как внешнюю ссылку: так актуальная редакция всегда одна, а история
/// изменений видна в git-истории репозитория.
///
/// Соглашение об именах файлов: сербская (юридически значимая) версия без
/// суффикса, переводы — с суффиксом `_ru` / `_en`. Переименовывать файлы в
/// репозитории нельзя — ссылки зашиты в выпущенные сборки.
library;

/// Хост, на котором опубликованы документы.
const String kLegalDocumentsHost = 'docs.saobracaj.gleb.at';

/// Какие документы есть и как называются их файлы (без суффикса языка).
enum LegalDocument {
  privacyPolicy('privacy_policy', localized: true),
  termsOfUse('terms_of_use', localized: true),
  /// Инструкция по удалению аккаунта — одна страница на трёх языках.
  deleteAccount('delete_account', localized: false);

  const LegalDocument(this.fileName, {required this.localized});

  /// Имя файла без расширения и без языкового суффикса.
  final String fileName;

  /// Есть ли у документа отдельные файлы переводов (`_ru`, `_en`).
  final bool localized;
}

/// Ссылка на [document] для языка интерфейса [languageCode].
///
/// Сербский — базовая версия без суффикса; для русского и английского
/// открывается перевод. Неизвестный язык ведёт на сербскую версию: она
/// юридически значимая, и такая ссылка точно существует.
Uri legalDocumentUri(LegalDocument document, String languageCode) {
  final suffix = switch (languageCode) {
    'ru' || 'en' when document.localized => '_$languageCode',
    _ => '',
  };
  return Uri.https(kLegalDocumentsHost, '/${document.fileName}$suffix.html');
}
