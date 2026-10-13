import 'package:freezed_annotation/freezed_annotation.dart';

part 'ask_ai_client_settings.freezed.dart';

/// The device-side settings the chat sends to the backend with every message
/// (`askAi(settings:)`), so the model can *read* them from its prompt — and
/// *change* them through the `update_user_settings` tool, whose changes come
/// back as [AskAiClientAction]s on the reply.
///
/// Everything here lives on the device (shared preferences, the theme bloc,
/// the «РУ» chip of the question screen), which is why the server has to be
/// told. The shape mirrors `AskAiClientSettingsInput` of `saobracaj_backend`.
@freezed
abstract class AskAiClientSettings with _$AskAiClientSettings {
  const factory AskAiClientSettings({
    /// `ru` / `sr` / `en`; follows the device, read-only for the model.
    String? interfaceLanguage,

    /// `light` / `dark` / `system`.
    String? theme,

    /// Whether the user has the Russian materials switched on.
    bool? russianContent,

    /// Whether the Russian materials are available at all (the subscription
    /// grant or a free category) — switching them on is pointless without it.
    bool? russianContentAvailable,

    /// Whether the translation of the current ticket is shown (the «РУ»
    /// chip); `null` on a screen without a ticket.
    bool? translationShown,

    /// The switchable features and their local toggles.
    @Default(<AskAiFeatureToggle>[]) List<AskAiFeatureToggle> features,
  }) = _AskAiClientSettings;

  const AskAiClientSettings._();

  /// The GraphQL input object, nulls dropped.
  Map<String, dynamic> toGraphql() => {
    if (interfaceLanguage != null) 'interfaceLanguage': interfaceLanguage,
    if (theme != null) 'theme': theme,
    if (russianContent != null) 'russianContent': russianContent,
    if (russianContentAvailable != null)
      'russianContentAvailable': russianContentAvailable,
    if (translationShown != null) 'translationShown': translationShown,
    'features': [
      for (final f in features)
        {
          'key': f.key,
          if (f.title != null) 'title': f.title,
          'enabled': f.enabled,
        },
    ],
  };
}

/// One switchable feature as the model sees it: the catalog key, the title
/// the settings screen shows (so «выключи карточку активности» can be matched
/// to a key) and the current local toggle.
@freezed
abstract class AskAiFeatureToggle with _$AskAiFeatureToggle {
  const factory AskAiFeatureToggle({
    required String key,
    String? title,
    required bool enabled,
  }) = _AskAiFeatureToggle;
}

/// A settings change the assistant asked for, to be applied the moment the
/// reply lands. A flat key/value pair on the wire, so a key this build does
/// not know is simply skipped.
///
/// Keys: [russianContent] / [translationShown] (`"true"` / `"false"`),
/// [theme] (`light` / `dark` / `system`) and `feature.<key>`
/// (`"true"` / `"false"`).
@freezed
abstract class AskAiClientAction with _$AskAiClientAction {
  const factory AskAiClientAction({
    required String key,
    required String value,
  }) = _AskAiClientAction;

  const AskAiClientAction._();

  static const russianContent = 'russian_content';
  static const translationShown = 'translation_shown';
  static const theme = 'theme';
  static const featurePrefix = 'feature.';

  /// `null` for a malformed frame — a newer server talking.
  static AskAiClientAction? parse(Map<String, dynamic> json) {
    final key = json['key']?.toString();
    final value = json['value']?.toString();
    if (key == null || key.isEmpty || value == null) return null;
    return AskAiClientAction(key: key, value: value);
  }

  /// The value read as a flag; `null` when it is not one.
  bool? get asBool => switch (value.trim().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  /// The feature key behind a `feature.<key>` action, `null` otherwise.
  String? get featureKey => key.startsWith(featurePrefix)
      ? key.substring(featurePrefix.length)
      : null;
}
