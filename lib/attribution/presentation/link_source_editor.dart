import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';
import '../models/link_source.dart';

/// Что ввели в форме источника.
typedef LinkSourceDraft = ({
  String name,
  String description,
  String code,
  String targetPath,
});

/// Форма источника: создание ([source] == null) или правка. Код задаётся
/// только при создании — ссылка с ним могла уже уйти в печать. `null` —
/// форму закрыли.
Future<LinkSourceDraft?> showLinkSourceEditor(
  BuildContext context, {
  LinkSource? source,
}) => showDialog<LinkSourceDraft>(
  context: context,
  builder: (_) => _LinkSourceEditor(source: source),
);

final _codePattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,38}[a-z0-9])?$');

class _LinkSourceEditor extends StatefulWidget {
  const _LinkSourceEditor({this.source});

  final LinkSource? source;

  @override
  State<_LinkSourceEditor> createState() => _LinkSourceEditorState();
}

class _LinkSourceEditorState extends State<_LinkSourceEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.name);
  late final _description = TextEditingController(
    text: widget.source?.description,
  );
  final _code = TextEditingController();
  late final _target = TextEditingController(
    text: widget.source == null || widget.source!.targetPath == '/'
        ? ''
        : widget.source!.targetPath,
  );

  bool get _creating => widget.source == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _code.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      description: _description.text.trim(),
      code: _code.text.trim().toLowerCase(),
      targetPath: _target.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _creating
            ? LocaleKeys.linkSources_editorCreateTitle.tr()
            : LocaleKeys.linkSources_editorEditTitle.tr(),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.linkSources_fieldName.tr(),
                    hintText: LocaleKeys.linkSources_fieldNameHint.tr(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? LocaleKeys.linkSources_nameRequired.tr()
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.linkSources_fieldDescription.tr(),
                  ),
                ),
                if (_creating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.linkSources_fieldCode.tr(),
                      helperText: LocaleKeys.linkSources_fieldCodeHelper.tr(),
                      helperMaxLines: 3,
                      prefixText: '/go/',
                    ),
                    validator: (v) {
                      final code = (v ?? '').trim().toLowerCase();
                      if (code.isEmpty || _codePattern.hasMatch(code)) {
                        return null;
                      }
                      return LocaleKeys.linkSources_codeInvalid.tr();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _target,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.linkSources_fieldTarget.tr(),
                    hintText: '/',
                    helperText: LocaleKeys.linkSources_fieldTargetHelper.tr(),
                    helperMaxLines: 3,
                  ),
                  validator: (v) {
                    final path = (v ?? '').trim();
                    if (path.isEmpty) return null;
                    if (!path.startsWith('/') ||
                        path.startsWith('//') ||
                        path.contains(' ')) {
                      return LocaleKeys.linkSources_targetInvalid.tr();
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.linkSources_cancel.tr()),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            _creating
                ? LocaleKeys.linkSources_create.tr()
                : LocaleKeys.linkSources_save.tr(),
          ),
        ),
      ],
    );
  }
}
