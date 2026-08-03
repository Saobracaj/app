import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/display_name_rules.dart';

/// Modal that asks a signed-in user for a display name before their first
/// comment (per the public-comments spec: a comment may not be posted without
/// one). Returns the entered, client-validated name, or `null` if cancelled.
///
/// The backend re-validates on `setDisplayName`; this dialog only enforces the
/// same rules client-side so the user gets an immediate inline error.
Future<String?> showDisplayNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DisplayNameDialog(),
  );
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog();

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    final error = validateDisplayName(name);
    if (error != null) {
      setState(() => _error = displayNameErrorMessage(error));
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отображаемое имя'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Укажите имя, которое увидят другие пользователи рядом с вашими '
            'комментариями.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: displayNameMaxLen,
            inputFormatters: [
              LengthLimitingTextInputFormatter(displayNameMaxLen),
              FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Ваше имя',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
