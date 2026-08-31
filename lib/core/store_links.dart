/// Ссылки на приложение в сторах — их показывает веб-версия там, где раньше
/// была оплата.
///
/// Android-ссылка собирается из applicationId (`android/app/build.gradle.kts`).
/// Apple-ссылке нужен числовой идентификатор приложения из App Store Connect —
/// bundle id для неё не годится; пока оператор его не проставил,
/// [appStoreUrl] возвращает `null` и кнопка App Store просто не показывается.
library;

/// applicationId Android-сборки.
const androidApplicationId = 'at.gleb.saobracaj';

/// Числовой Apple ID приложения (App Store Connect → App Information →
/// General Information → Apple ID). Пустая строка — ссылка неизвестна.
const appStoreAppId = '';

Uri get googlePlayUrl => Uri.parse(
  'https://play.google.com/store/apps/details?id=$androidApplicationId',
);

Uri? get appStoreUrl => appStoreAppId.isEmpty
    ? null
    : Uri.parse('https://apps.apple.com/app/id$appStoreAppId');
