import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../feature_flags/domain/app_feature.dart';
import '../feature_flags/state_management/feature_flags_bloc.dart';
import 'dictionary.dart';

/// Текст вопроса или варианта ответа, готовый к разметке: термины закона
/// превращены в ссылки на определения (`String.dict`) — но только пока
/// пользователь не выключил подсветку в настройках
/// (`AppFeature.lawDefinitionsHighlight`, экран «Функции»).
///
/// Вызывать из `build()`: `context.select` подписывает виджет на сам флаг, так
/// что после переключения тумблера текст перерисуется без ссылок сразу, а на
/// прочие изменения снимка фич реакции не будет.
String dictLinks(BuildContext context, String text) =>
    context.select<FeatureFlagsBloc, bool>(
      (bloc) => bloc.state.isEnabled(AppFeature.lawDefinitionsHighlight),
    )
    ? text.dict
    : text;
