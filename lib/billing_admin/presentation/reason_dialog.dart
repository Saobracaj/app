import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

/// Ответ диалога с причиной: подтверждено, причина может быть пустой.
class ReasonResult {
  const ReasonResult(this.reason);

  final String? reason;
}

/// Подтверждение действия с необязательной причиной (попадёт в журнал):
/// отмена заказа, отзыв подписки. `null` — оператор передумал.
Future<ReasonResult?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String hint,
  required String action,
  bool destructive = false,
  String initialReason = '',
}) {
  return showDialog<ReasonResult>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      body: body,
      hint: hint,
      action: action,
      destructive: destructive,
      initialReason: initialReason,
    ),
  );
}

/// Одно текстовое поле и две кнопки — тот самый «тривиальный» случай, где
/// контроллер поля живёт в виджете, а не в блоке (как в редакторе списков).
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.hint,
    required this.action,
    required this.destructive,
    required this.initialReason,
  });

  final String title;
  final String body;
  final String hint;
  final String action;
  final bool destructive;
  final String initialReason;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialReason,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.body),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.comments_cancel.tr()),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () {
            final reason = _controller.text.trim();
            Navigator.of(
              context,
            ).pop(ReasonResult(reason.isEmpty ? null : reason));
          },
          child: Text(widget.action),
        ),
      ],
    );
  }
}
