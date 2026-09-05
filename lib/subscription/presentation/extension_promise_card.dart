import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';
import 'extension_request_dialog.dart';

/// Обещание продлить пропуск тому, кто не сдал: «напиши нам — продлим на
/// месяц бесплатно».
///
/// Это не гарантия и не возврат — возврат делает только стор, а продление
/// делаем мы, одним действием оператора. Проверить результат экзамена негде,
/// и не надо: ложное заявление стоит один месяц доступа с нулевой
/// себестоимостью, а снятый страх «а вдруг не сдам» стоит дороже.
///
/// На витрине — просто текст; в разделе «Подписка» ([withRequestButton]) —
/// ещё и кнопка, которая отправляет запрос в чат с разработчиком.
class ExtensionPromiseCard extends StatelessWidget {
  const ExtensionPromiseCard({super.key, this.withRequestButton = false});

  final bool withRequestButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LocaleKeys.subscription_extensionPromiseTitle.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.subscription_extensionPromiseBody.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          if (withRequestButton)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => showExtensionRequestDialog(context),
                child: Text(LocaleKeys.subscription_extensionRequest.tr()),
              ),
            ),
        ],
      ),
    );
  }
}
