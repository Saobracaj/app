import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../generated/locale_keys.g.dart';

/// A pill-shaped text field that reveals a round send button beside it once
/// focused. A focus toggle is the sanctioned use of local widget state.
///
/// [focusRequestId] lets the parent move focus into this composer: whenever it
/// changes to a new non-null value (bumped on each "Ответить" tap) the field
/// requests focus.
///
/// Tapping anywhere outside the composer drops the focus (and hides the
/// keyboard). Flutter only does that by itself on desktop and on the web, so
/// the behaviour is wired explicitly through [TextField.onTapOutside]; the
/// whole composer — the field *and* the send button — sits inside a
/// [TextFieldTapRegion] so that pressing "Отправить" does not count as a tap
/// outside (which would unfocus the field and make the button disappear from
/// under the finger before the tap completes).
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.hint,
    required this.onSubmit,
    this.submitting = false,
    this.dense = false,
    this.focusRequestId,
  });

  final String hint;

  /// Returns `true` when the text was accepted (so the field can be cleared);
  /// `false` when the submission was aborted (e.g. the display-name dialog was
  /// cancelled), keeping the user's text.
  final Future<bool> Function(String) onSubmit;
  final bool submitting;
  final bool dense;
  final int? focusRequestId;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void didUpdateWidget(covariant CommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new focus request arrived (the user tapped "Ответить" on this thread) —
    // move focus into the field.
    if (widget.focusRequestId != null &&
        widget.focusRequestId != oldWidget.focusRequestId) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.submitting) return;
    final accepted = await widget.onSubmit(text);
    if (!accepted || !mounted) return;
    _controller.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showSend = _focused || _controller.text.trim().isNotEmpty;
    return TextFieldTapRegion(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    maxLength,
                    required isFocused,
                  }) => null,
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
              onChanged: (_) => setState(() {}),
              // Any tap outside the composer closes the keyboard and releases
              // the field, on every platform.
              onTapOutside: (_) => _focus.unfocus(),
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(21),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (showSend)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: widget.submitting
                  ? const SizedBox(
                      height: 42,
                      width: 42,
                      child: Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        fixedSize: const Size(42, 42),
                        minimumSize: const Size(42, 42),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _submit,
                      child: Tooltip(
                        message: LocaleKeys.comments_send.tr(),
                        child: const Icon(Icons.send, size: 18),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
