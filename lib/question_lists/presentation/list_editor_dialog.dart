import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../generated/locale_keys.g.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';

/// The name + colour a user picked in [showListEditorDialog].
class QuestionListDraft {
  const QuestionListDraft({required this.name, required this.color});

  final String name;

  /// ARGB value, ready for `QuestionList.color`.
  final int color;
}

/// Maximum name length, mirroring `LIST_NAME_MAX_LEN` in the backend
/// (`saobracaj_backend/src/question_lists/model.rs`).
const int listNameMaxLen = 40;

/// Ask for a list name and colour. Used both to create a list (pass no
/// [existing]; the colour starts on a random one) and to edit an existing list.
///
/// Returns the draft, or `null` when the user cancelled. The caller decides what
/// to do with it — this dialog performs no writes.
Future<QuestionListDraft?> showListEditorDialog(
  BuildContext context, {
  QuestionList? existing,
}) {
  return showDialog<QuestionListDraft>(
    context: context,
    builder: (_) => _ListEditorDialog(existing: existing),
  );
}

class _ListEditorDialog extends StatefulWidget {
  const _ListEditorDialog({this.existing});

  final QuestionList? existing;

  @override
  State<_ListEditorDialog> createState() => _ListEditorDialogState();
}

class _ListEditorDialogState extends State<_ListEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Color _color = widget.existing == null
      ? randomListColor()
      : Color(widget.existing!.color);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = LocaleKeys.questionLists_nameRequired.tr());
      return;
    }
    Navigator.of(
      context,
    ).pop(QuestionListDraft(name: name, color: _color.toARGB32()));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEdit
            ? LocaleKeys.questionLists_editTitle.tr()
            : LocaleKeys.questionLists_createTitle.tr(),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: listNameMaxLen,
            inputFormatters: [
              LengthLimitingTextInputFormatter(listNameMaxLen),
              FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: LocaleKeys.questionLists_nameLabel.tr(),
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.questionLists_color.tr(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in kListColors)
                _ColorDot(
                  color: color,
                  selected: color.toARGB32() == _color.toARGB32(),
                  onTap: () => setState(() => _color = color),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.questionLists_cancel.tr()),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            isEdit
                ? LocaleKeys.questionLists_save.tr()
                : LocaleKeys.questionLists_createAction.tr(),
          ),
        ),
      ],
    );
  }
}

/// One swatch in the colour picker; the selected one is ringed and ticked.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
        ),
        // Галочка берёт on-цвет к выбранному цвету: белая на жёлтом swatch'е
        // была нечитаема.
        child: selected
            ? Icon(Icons.check, size: 18, color: onListColor(color))
            : null,
      ),
    );
  }
}
