import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/confirm_code/confirm_code_bloc.dart';
import '../state_management/confirm_code/confirm_code_events.dart';
import '../state_management/confirm_code/confirm_code_state.dart';

/// Confirms the 6-digit email code sent after registration. Auto-verifies once
/// all six characters are entered; on success the user is logged in and returned
/// to the app (driven by [ConfirmCodeBloc]).
class ConfirmCodePage extends StatelessWidget {
  const ConfirmCodePage({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ConfirmCodeBloc>(param1: email),
      child: ConfirmCodeView(email: email),
    );
  }
}

class ConfirmCodeView extends StatelessWidget {
  const ConfirmCodeView({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_confirmTitle.tr())),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocConsumer<ConfirmCodeBloc, ConfirmCodeState>(
                  listenWhen: (p, c) =>
                      p.loggedIn != c.loggedIn || p.resentTick != c.resentTick,
                  listener: (context, state) {
                    if (state.loggedIn) {
                      Routemaster.of(context).replace('/');
                    } else if (state.resentTick > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(LocaleKeys.auth_codeResent.tr())),
                      );
                    }
                  },
                  builder: (context, state) {
                    final bloc = context.read<ConfirmCodeBloc>();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          LocaleKeys.auth_confirmSubtitle.tr(args: [email]),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          autofocus: true,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: LocaleKeys.auth_code.tr(),
                            prefixIcon: const Icon(Icons.pin_outlined),
                            errorText: state.errorMessage,
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          enabled: !state.inProgress,
                          onChanged: (v) => bloc.add(CodeChanged(v)),
                          onFieldSubmitted: (_) => bloc.add(SubmitPressed()),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: state.inProgress
                              ? null
                              : () => bloc.add(SubmitPressed()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: state.inProgress
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(LocaleKeys.auth_confirmSubmit.tr()),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: state.inProgress
                              ? null
                              : () => bloc.add(ResendPressed()),
                          child: Text(LocaleKeys.auth_resendCode.tr()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
