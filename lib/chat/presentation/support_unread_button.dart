import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/presentation/auth_button.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/support_unread_bloc.dart';
import '../state_management/support_unread_state.dart';

/// Место аватара в шапке главной.
///
/// Пока в чате с разработчиком есть непрочитанное — кнопка со счётчиком,
/// ведущая прямо в разговор (свой чат, обращение или тред — решает
/// [SupportUnreadState.destination]); иначе обычный [AuthButton] с аватаром
/// или «Войти».
class SupportUnreadButton extends StatelessWidget {
  const SupportUnreadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportUnreadBloc, SupportUnreadState>(
      builder: (context, state) {
        final destination = state.destination;
        if (destination == null) return const AuthButton();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // Значок — снаружи кнопки: внутри её круглая форма срезала бы цифру.
          child: Badge.count(
            count: state.total,
            child: IconButton.filledTonal(
              tooltip: LocaleKeys.support_unreadTooltip.tr(),
              onPressed: () => Routemaster.of(context).push(destination),
              icon: const Icon(Icons.forum_outlined),
            ),
          ),
        );
      },
    );
  }
}
