import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
import 'tariff_formatting.dart';

/// Ключ кнопки «Отменить подписку» в листе — для тестов.
@visibleForTesting
const lavaCancelButtonKey = ValueKey('lava-cancel-subscription');

/// Кнопка «Управление подпиской» для подписки через lava.top: открывает лист
/// с датой следующего списания, суммой и явной отменой. Подписку в сторе
/// отменяет только стор; эту — мы сами, поэтому и управление здесь.
class LavaManageButton extends StatelessWidget {
  const LavaManageButton({super.key, this.outlined = true});

  /// Широкая обведённая кнопка (витрина) или текстовая (раздел аккаунта).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SubscriptionBloc>();
    void open() => showLavaManageSheet(context, bloc);
    final label = Text(LocaleKeys.subscription_manageSubscription.tr());
    const icon = Icon(Icons.tune, size: 18);
    return outlined
        ? SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: open,
              icon: icon,
              label: label,
            ),
          )
        : Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: open, icon: icon, label: label),
          );
  }
}

/// Лист управления подпиской lava.top. Bloc передаётся явно: лист живёт в
/// корневом навигаторе, где провайдера витрины нет.
Future<void> showLavaManageSheet(BuildContext context, SubscriptionBloc bloc) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const _LavaManageSheet()),
  );
}

class _LavaManageSheet extends StatelessWidget {
  const _LavaManageSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      // После отмены лист закрывается: снэкбар с датой покажет экран под ним.
      listenWhen: (prev, curr) =>
          prev.lavaCancelling &&
          !curr.lavaCancelling &&
          curr.errorMessage == null,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) {
        final lava = state.subscription.lavaSubscription;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.subscription_lavaSheetTitle.tr(),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (lava == null)
                  Text(LocaleKeys.subscription_noSubscriptionTitle.tr())
                else ...[
                  Text(
                    passLabel(lava.months),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  if (lava.cancelled) ...[
                    Text(
                      LocaleKeys.subscription_lavaAccessUntil.tr(
                        args: [formatDate(lava.endsAt)],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocaleKeys.subscription_lavaCancelledHint.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    if (lava.nextChargeAt != null)
                      Text(
                        LocaleKeys.subscription_lavaNextCharge.tr(
                          args: [formatDate(lava.nextChargeAt!)],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    Text(
                      LocaleKeys.subscription_lavaChargeAmount.tr(
                        args: [rubLabel(lava.priceRub)],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocaleKeys.subscription_legalLavaNote.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!lava.cancelled)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        key: lavaCancelButtonKey,
                        onPressed: state.lavaCancelling
                            ? null
                            : () => _confirmCancel(context, lava),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: state.lavaCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(
                          LocaleKeys.subscription_cancelSubscription.tr(),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Отмена — необратимое для человека действие, поэтому с подтверждением,
  /// в котором названо, до какого числа доступ сохранится.
  Future<void> _confirmCancel(
    BuildContext context,
    LavaSubscription lava,
  ) async {
    final bloc = context.read<SubscriptionBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(LocaleKeys.subscription_cancelConfirmTitle.tr()),
        content: Text(
          LocaleKeys.subscription_cancelConfirmBody.tr(
            args: [formatDate(lava.endsAt)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(LocaleKeys.subscription_cancelConfirmNo.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(LocaleKeys.subscription_cancelConfirmYes.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(LavaCancelRequested());
  }
}

/// Строка «подписка отменена, доступ до …» — под названием тарифа в разделе
/// «Подписка» и в карточке действующего тарифа на витрине.
class LavaCancelledLine extends StatelessWidget {
  const LavaCancelledLine({super.key, required this.lava});

  final LavaSubscription lava;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      LocaleKeys.subscription_lavaCancelled.tr(args: [formatDate(lava.endsAt)]),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
