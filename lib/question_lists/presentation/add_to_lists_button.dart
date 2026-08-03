import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_gate.dart';
import '../../generated/locale_keys.g.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import '../state_management/question_lists_bloc.dart';
import '../state_management/question_lists_events.dart';
import '../state_management/question_lists_state.dart';
import 'list_editor_dialog.dart';
import 'question_lists_section.dart';

/// The "add to list" action of the question screen's app bar (next to the
/// translate button), shown only while `custom_question_lists` is on.
///
/// Tapping it opens a **non-modal** menu of the user's custom lists, each row a
/// checkbox: tapping a row adds/removes the current question and the menu stays
/// open, so several lists can be ticked in a row. The menu closes only when the
/// user deliberately taps somewhere else — and because the backdrop only
/// *listens* for that tap instead of swallowing it, whatever is underneath (the
/// "next question" button, say) still receives it.
class AddToListsButton extends StatelessWidget {
  const AddToListsButton({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: AppFeature.customQuestionLists,
      child: _AddToListsMenuButton(questionId: questionId),
    );
  }
}

/// Owns the overlay's open/closed flag — purely visual state, hence a
/// [StatefulWidget]; every piece of data still comes from [QuestionListsBloc].
class _AddToListsMenuButton extends StatefulWidget {
  const _AddToListsMenuButton({required this.questionId});

  final int questionId;

  @override
  State<_AddToListsMenuButton> createState() => _AddToListsMenuButtonState();
}

class _AddToListsMenuButtonState extends State<_AddToListsMenuButton> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _buttonKey = GlobalKey();

  void _toggleMenu() {
    if (_controller.isShowing) {
      _controller.hide();
    } else {
      _controller.show();
    }
  }

  /// Closes the menu unless the pointer went down inside it (its rows handle
  /// their own taps and must not dismiss it) or on the button itself (whose
  /// `onPressed` toggles the menu closed a moment later).
  void _onPointerDown(PointerDownEvent event) {
    for (final key in [_menuKey, _buttonKey]) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(event.position)) {
        return;
      }
    }
    _controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (overlayContext) => Stack(
          children: [
            // Behind the menu, so a tap on the menu never reaches it; translucent
            // so a tap anywhere else still goes through to the page below.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              // Sized by the menu itself, so `followerAnchor` lines its
              // right edge up with the button's.
              child: _ListsMenu(key: _menuKey, questionId: widget.questionId),
            ),
          ],
        ),
        child: IconButton(
          key: _buttonKey,
          onPressed: _toggleMenu,
          tooltip: LocaleKeys.questionLists_addToList.tr(),
          icon: const Icon(Icons.playlist_add),
        ),
      ),
    );
  }
}

/// The menu body: one checkbox row per custom list plus a "create a new list"
/// row at the bottom.
class _ListsMenu extends StatelessWidget {
  const _ListsMenu({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 280,
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: BlocBuilder<QuestionListsBloc, QuestionListsState>(
          builder: (context, state) {
            final signedIn = context.select(
              (AuthBloc b) => b.state.isAuthenticated,
            );
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!signedIn)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        LocaleKeys.questionLists_signInRequired.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else ...[
                    for (final list in state.customLists)
                      _ListCheckboxRow(list: list, questionId: questionId),
                    if (state.customLists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          LocaleKeys.questionLists_noCustomLists.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add),
                      title: Text(LocaleKeys.questionLists_addNewList.tr()),
                      // The dialog opens on top of the menu; the menu stays put,
                      // so the freshly created list (already holding this
                      // question) simply appears in it.
                      onTap: () async {
                        final bloc = context.read<QuestionListsBloc>();
                        final draft = await showListEditorDialog(context);
                        if (draft == null) return;
                        bloc.add(
                          QuestionListCreated(
                            name: draft.name,
                            color: draft.color,
                            questionId: questionId,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One list row: ticking it adds the question to that list, unticking removes
/// it. The menu deliberately stays open after the tap.
class _ListCheckboxRow extends StatelessWidget {
  const _ListCheckboxRow({required this.list, required this.questionId});

  final QuestionList list;
  final int questionId;

  @override
  Widget build(BuildContext context) {
    final included = list.questionIds.contains(questionId);
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.trailing,
      value: included,
      secondary: QuestionListAvatar(list: list, size: 24),
      title: Text(
        list.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: (value) => context.read<QuestionListsBloc>().add(
        QuestionInListToggled(
          listId: list.id,
          questionId: questionId,
          included: value ?? !included,
        ),
      ),
    );
  }
}
