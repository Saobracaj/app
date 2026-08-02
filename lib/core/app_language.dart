/// Current UI language code (e.g. `ru` / `en` / `sr`).
///
/// Sent as the `Accept-Language` header on every GraphQL request so the backend
/// can keep the stored user language in sync (see `GraphqlClient`). Kept up to
/// date with easy_localization's active locale by `MyApp.build`; defaults to the
/// fallback locale until the first frame sets it.
String appLanguageCode = 'ru';
