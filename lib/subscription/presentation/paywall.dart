import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/navigation.dart';
import '../../generated/locale_keys.g.dart';
import 'tariffs_page.dart';

/// Откуда человек пришёл к пейволлу. Пейволл показывается только в точках
/// боли — там, где нужен ответ «почему», — и никогда при запуске; источник
/// уезжает в аналитику, чтобы воронку можно было читать по входам.
enum PaywallSource {
  explanation,
  konspekt,
  konspektPage,
  analysis,
  askAi,
  russianToggle;

  String get key => switch (this) {
    PaywallSource.explanation => 'explanation',
    PaywallSource.konspekt => 'konspekt',
    PaywallSource.konspektPage => 'konspekt_page',
    PaywallSource.analysis => 'analysis',
    PaywallSource.askAi => 'ask_ai',
    PaywallSource.russianToggle => 'russian_toggle',
  };
}

/// Открыть экран пейволла — витрину тарифов — из точки боли [source].
///
/// Экран один и тот же для всех входов: три срока подписки, якорь и обещание
/// продления. Гость попадает на ту же витрину, где вместо «Оформить» стоит
/// «Войдите» — отдельного экрана для него нет.
void openPaywall(
  BuildContext context, {
  required PaywallSource source,
  int? questionId,
}) {
  analytics.logPaywallOpened(source: source.key, questionId: questionId);
  openTariffs(context);
}

/// Открыть витрину тарифов **поверх** экрана [context].
///
/// Витрина лежит над тем экраном, откуда её открыли, и «назад» возвращает
/// ровно туда — к вопросу, конспекту или разделу «Подписка». Абсолютный
/// `push('/tariffs')` строил стек заново и сносил всё, что было под витриной:
/// «назад» из тарифов, открытых с вопроса, уезжало на главную. Поэтому путь
/// относительный (`…/tariffs` есть у каждого экрана с гейтом, см.
/// `routes.dart`), а для экрана без собственного адреса — обычный
/// императивный переход, у которого «назад» такое же.
void openTariffs(BuildContext context) {
  pushScreen(context, path: 'tariffs', screen: () => const TariffsPage());
}

/// Сколько символов закрытого текста показывает превью — столько же, сколько
/// бэкенд оставляет от запертого объяснения (`PREVIEW_CHARS` в
/// `comments/model.rs`): видно, что текст настоящий и про этот вопрос, но
/// ответить по нему на следующий вопрос нельзя.
const lockedPreviewChars = 220;

/// Начало [text] для превью под пейволлом: первый абзац, обрезанный по
/// последнему пробелу до [lockedPreviewChars] символов, с многоточием, если
/// что-то отброшено. Повторяет правило бэкенда, но на клиенте: то, что
/// показывается под размытием, не должно зависеть от того, откуда пришёл
/// документ — полная копия из кэша, пережившая право, режется так же.
String lockedPreviewOf(String text) {
  final whole = text.trim();
  final firstParagraph = whole.split('\n\n').first.trim();
  final cutHere = firstParagraph.length < whole.length;
  final runes = firstParagraph.runes.toList();
  if (runes.length <= lockedPreviewChars) {
    return cutHere ? '$firstParagraph…' : firstParagraph;
  }
  final head = String.fromCharCodes(runes.take(lockedPreviewChars));
  var cut = head.length;
  for (var i = head.length - 1; i >= 0; i--) {
    if (head[i].trim().isEmpty) {
      cut = i;
      break;
    }
  }
  return '${head.substring(0, cut).trimRight()}…';
}

/// Карточка закрытого контента: то, что видно без подписки.
///
/// [preview] — кусок настоящего контента (первые строки объяснения, первый
/// блок конспекта), который показывается под затуханием и размытием, чтобы
/// было понятно, что именно покупают; без него карточка — просто заголовок и
/// одна фраза о том, что внутри. Кнопка ведёт на витрину тарифов.
///
/// Аналитика: `paywall_shown` уходит один раз на карточку — при первом
/// построении, а не на каждом кадре.
class LockedContentCard extends StatefulWidget {
  const LockedContentCard({
    super.key,
    required this.source,
    required this.title,
    required this.body,
    this.preview,
    this.questionId,
    this.categoryId,
    this.padding = const EdgeInsets.fromLTRB(14, 4, 14, 8),
  });

  final PaywallSource source;
  final String title;
  final String body;
  final Widget? preview;
  final int? questionId;
  final String? categoryId;
  final EdgeInsetsGeometry padding;

  @override
  State<LockedContentCard> createState() => _LockedContentCardState();
}

class _LockedContentCardState extends State<LockedContentCard> {
  @override
  void initState() {
    super.initState();
    analytics.logPaywallShown(
      source: widget.source.key,
      questionId: widget.questionId,
      categoryId: widget.categoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The card sits inside content screens that a test may build without the
    // session holder above them; without it the reader counts as a guest.
    final authenticated =
        context.watch<AuthBloc?>()?.state.isAuthenticated ?? false;
    final preview = widget.preview;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview != null) ...[
            _BlurredPreview(child: preview),
            const SizedBox(height: 4),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.colorScheme.primaryContainer.withValues(alpha: .38),
                theme.colorScheme.surface,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => openPaywall(
                    context,
                    source: widget.source,
                    questionId: widget.questionId,
                  ),
                  child: Text(
                    authenticated
                        ? LocaleKeys.subscription_lockedCta.tr()
                        : LocaleKeys.subscription_lockedGuestCta.tr(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Превью под размытием и затуханием книзу: текст читается в первых строках
/// и растворяется к концу — видно, что это настоящий контент, но дочитать его
/// нельзя. Само превью с сервера уже обрезано, размытие — только подача.
class _BlurredPreview extends StatelessWidget {
  const _BlurredPreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, .45, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: .6, sigmaY: .6),
          child: IgnorePointer(child: child),
        ),
      ),
    );
  }
}
