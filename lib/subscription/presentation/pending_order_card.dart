import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import 'tariff_formatting.dart';

/// Заказ в статусе «ждём оплату»: сумма, позив на број и срок, до которого
/// заказ оплачиваем.
///
/// Сами реквизиты (IPS QR и печатная квитанция) на этой итерации — заглушка:
/// показываем номер и честно пишем, что платёжные данные вот-вот появятся.
/// Позив на број настоящий и уже закреплён за заказом, по нему оператор найдёт
/// перевод в банковской выписке.
class PendingOrderCard extends StatelessWidget {
  const PendingOrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.subscription_pendingTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.subscription_pendingBody.tr(
                namedArgs: {
                  'tariff':
                      '${tariffKindName(order.kind)}, ${monthsLabel(order.months)}',
                  'amount': '${order.amountRsd}',
                },
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _ReferenceRow(reference: order.referenceDisplay),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.subscription_paymentStub.tr(),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.subscription_payUntil.tr(
                args: [formatDate(order.paymentDueAt)],
              ),
              style: theme.textTheme.bodySmall,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.read<SubscriptionBloc>().add(
                  OrderCancelled(order.id),
                ),
                child: Text(LocaleKeys.subscription_cancelOrder.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Позив на број крупно и с копированием: его переписывают в форму перевода,
/// и опечатка здесь стоит потерянного платежа.
class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.subscription_reference.tr(),
                style: theme.textTheme.labelMedium,
              ),
              SelectableText(
                reference,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: LocaleKeys.subscription_reference.tr(),
          icon: const Icon(Icons.copy_outlined),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: reference)).then((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LocaleKeys.subscription_referenceCopied.tr()),
                ),
              );
            });
          },
        ),
      ],
    );
  }
}
