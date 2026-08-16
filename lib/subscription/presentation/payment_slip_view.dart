import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';

/// Реквизиты для оплаты заказа: IPS QR-код и уплатница.
///
/// QR рисуется на устройстве из текста стандарта НБС — картинка с сервера
/// ([PaymentSlip.ipsQrUrl]) нужна только письму и кнопке «открыть картинкой».
/// Каждое поле уплатницы копируется по отдельности: их переписывают в форму
/// перевода, а опечатка в счёте или позиве на број стоит потерянного платежа.
class PaymentSlipView extends StatelessWidget {
  const PaymentSlipView({super.key, required this.slip, this.compact = false});

  final PaymentSlip slip;

  /// Компактный вид (админский список): без подсказки и без QR-кода.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      (LocaleKeys.subscription_slipPayer.tr(), slip.payer),
      (LocaleKeys.subscription_slipPurpose.tr(), slip.purpose),
      (LocaleKeys.subscription_slipPayee.tr(), slip.payeeLine),
      (LocaleKeys.subscription_slipPaymentCode.tr(), slip.paymentCode),
      (LocaleKeys.subscription_slipCurrency.tr(), slip.currency),
      (LocaleKeys.subscription_slipAmount.tr(), slip.amountDisplay),
      (LocaleKeys.subscription_slipAccount.tr(), slip.payeeAccount),
      (LocaleKeys.subscription_slipModel.tr(), slip.model),
      (LocaleKeys.subscription_slipReference.tr(), slip.referenceDisplay),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 560;
    final slipCard = _SlipCard(rows: rows);
    final qr = compact ? null : _QrBlock(slip: slip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            LocaleKeys.subscription_paymentTitle.tr(),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.subscription_paymentHint.tr(),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (qr != null && wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              qr,
              const SizedBox(width: 16),
              Expanded(child: slipCard),
            ],
          )
        else ...[
          if (qr != null) ...[Center(child: qr), const SizedBox(height: 12)],
          slipCard,
        ],
        if (!compact)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _copyAll(context, rows),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(LocaleKeys.subscription_copyAll.tr()),
                ),
                if (slip.ipsQrUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(slip.ipsQrUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: Text(LocaleKeys.subscription_openQrImage.tr()),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _copyAll(
    BuildContext context,
    List<(String, String)> rows,
  ) async {
    final text = [
      for (final (label, value) in rows) '$label: $value',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.subscription_allCopied.tr())),
    );
  }
}

/// QR-код с подписью; белая подложка обязательна — сканеры банков не читают
/// инвертированный QR тёмной темы.
class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.slip});

  final PaymentSlip slip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: QrImageView(
            data: slip.ipsQrText,
            size: 200,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.subscription_ipsQrTitle.tr(),
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// Уплатница: подписи полей — сербские, как на бланке (человек будет искать
/// именно их в форме своего банка), значения — крупно и с копированием.
class _SlipCard extends StatelessWidget {
  const _SlipCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              LocaleKeys.subscription_slipTitle.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final (label, value) in rows)
            _SlipRow(label: label, value: value),
        ],
      ),
    );
  }
}

class _SlipRow extends StatelessWidget {
  const _SlipRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: value.isEmpty ? null : () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SelectableText(
                    value.isEmpty ? '—' : value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (value.isNotEmpty)
              IconButton(
                tooltip: LocaleKeys.subscription_copyValue.tr(),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copy(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.subscription_copied.tr(args: [label]))),
    );
  }
}
