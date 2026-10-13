import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_client_settings.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_events.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_state.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/theme/state_management/theme_bloc.dart';
import 'package:saobracaj/theme/state_management/theme_events.dart';

/// The bridge between the Ask-AI chat and the app's settings.
///
/// The settings the assistant may read and change live in Blocs of the widget
/// tree — the «РУ» chip in `TranslationsBloc` (question screen only), the
/// theme in `ThemeBloc`, the Russian materials and the feature toggles in
/// `FeatureFlagsBloc` — so the chat Bloc neither reads nor applies them
/// itself. [readAskAiClientSettings] gathers the snapshot sent with a message;
/// [AskAiActionsApplier] applies what the reply asks for.
///
/// Every Bloc is looked up tolerantly: the exam-result chat has no
/// `TranslationsBloc`, a widget test may have none of them.

/// The snapshot of the device-side settings as seen from [context].
/// [categoryId] is the current ticket's category — in a free category the
/// Russian materials are available without the subscription.
AskAiClientSettings readAskAiClientSettings(
  BuildContext context, {
  String? categoryId,
}) {
  final flags = _maybeRead<FeatureFlagsBloc>(context)?.state;
  final theme = _maybeRead<ThemeBloc>(context)?.state;
  final translations = _maybeRead<TranslationsBloc>(context)?.state;
  final locale =
      EasyLocalization.of(context)?.locale ??
      Localizations.maybeLocaleOf(context);

  final snapshot = flags?.snapshot;
  return AskAiClientSettings(
    interfaceLanguage: locale?.languageCode,
    theme: theme?.mode.name,
    russianContent: snapshot?.localEnabled(AppFeature.russianContent),
    russianContentAvailable: snapshot == null
        ? null
        : (snapshot.authenticated &&
                  snapshot.grants.contains(AppFeature.russianContent.key)) ||
              isFreeCategory(categoryId),
    translationShown: translations?.showTranslation,
    features: snapshot == null
        ? const []
        : [
            for (final f in AppFeature.values)
              if (!f.shelved && f != AppFeature.russianContent)
                AskAiFeatureToggle(
                  key: f.key,
                  title: _featureTitle(f),
                  enabled: snapshot.localEnabled(f),
                ),
          ],
  );
}

/// The title the «Функции» screen shows for [feature]; `null` when the
/// translation is missing (then the key alone is sent).
String? _featureTitle(AppFeature feature) {
  final key = 'featureFlags.features.${feature.key}';
  final title = tr(key);
  return title == key ? null : title;
}

/// Apply the settings changes the assistant asked for. Unknown keys and
/// unparsable values are skipped — a newer server may know more than this
/// build. Returns how many actions were applied.
int applyAskAiClientActions(
  BuildContext context,
  List<AskAiClientAction> actions,
) {
  var applied = 0;
  for (final action in actions) {
    if (_apply(context, action)) applied++;
  }
  return applied;
}

bool _apply(BuildContext context, AskAiClientAction action) {
  if (action.key == AskAiClientAction.russianContent) {
    final on = action.asBool;
    final bloc = _maybeRead<FeatureFlagsBloc>(context);
    if (on == null || bloc == null) return false;
    bloc.add(FeatureToggled(AppFeature.russianContent, on));
    return true;
  }
  if (action.key == AskAiClientAction.translationShown) {
    final shown = action.asBool;
    final bloc = _maybeRead<TranslationsBloc>(context);
    if (shown == null || bloc == null) return false;
    bloc.add(SetShowTranslation(shown));
    return true;
  }
  if (action.key == AskAiClientAction.theme) {
    final bloc = _maybeRead<ThemeBloc>(context);
    final mode = ThemeMode.values
        .where((m) => m.name == action.value.trim().toLowerCase())
        .firstOrNull;
    if (mode == null || bloc == null) return false;
    bloc.add(ModeChanged(mode));
    return true;
  }
  final featureKey = action.featureKey;
  if (featureKey != null) {
    final feature = AppFeature.fromKey(featureKey);
    final on = action.asBool;
    final bloc = _maybeRead<FeatureFlagsBloc>(context);
    if (feature == null || on == null || bloc == null) return false;
    bloc.add(FeatureToggled(feature, on));
    return true;
  }
  return false;
}

/// Listens to the chat for settings changes the assistant asked for, applies
/// them to the surrounding Blocs and tells the chat they are handled. Wrap the
/// chat's content with it, below the `AskAiChatBloc` provider.
class AskAiActionsApplier extends StatelessWidget {
  const AskAiActionsApplier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AskAiChatBloc, AskAiChatState>(
      listenWhen: (previous, current) =>
          current.pendingActions.isNotEmpty &&
          !identical(previous.pendingActions, current.pendingActions),
      listener: (context, state) {
        applyAskAiClientActions(context, state.pendingActions);
        context.read<AskAiChatBloc>().add(AskAiChatActionsHandled());
      },
      child: child,
    );
  }
}

/// `context.read<T>()`, or `null` when no provider of [T] is above — the
/// exam-result chat has no `TranslationsBloc`, a test may have no theme.
T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
