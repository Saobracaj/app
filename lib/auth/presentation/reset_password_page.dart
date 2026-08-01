import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/reset_password/reset_password_bloc.dart';
import '../state_management/reset_password/reset_password_events.dart';
import '../state_management/reset_password/reset_password_state.dart';
import 'error_field.dart';
import 'validators.dart';

/// Two-step password reset: request a code by email, then set a new password
/// with that code. On success the user is logged in (driven by
/// [ResetPasswordBloc]).
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ResetPasswordBloc>(),
      child: ResetPasswordView(),
    );
  }
}

class ResetPasswordView extends StatelessWidget {
  ResetPasswordView({super.key});

  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();

  void _sendCode(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      _formKey.currentState!.save();
      context.read<ResetPasswordBloc>().add(SendCodePressed());
    }
  }

  void _confirm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      _formKey.currentState!.save();
      context.read<ResetPasswordBloc>().add(ConfirmPressed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_resetTitle.tr())),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
                  listenWhen: (p, c) => p.loggedIn != c.loggedIn,
                  listener: (context, state) {
                    if (state.loggedIn) Routemaster.of(context).replace('/');
                  },
                  builder: (context, state) {
                    final bloc = context.read<ResetPasswordBloc>();
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            LocaleKeys.auth_resetSubtitle.tr(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            enabled: !state.codeSent,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: LocaleKeys.auth_email.tr(),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: emailValidator,
                            onSaved: (v) => bloc.add(EmailChanged(v ?? '')),
                          ),
                          if (state.codeSent) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: LocaleKeys.auth_code.tr(),
                                prefixIcon: const Icon(Icons.pin_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: codeValidator,
                              onSaved: (v) => bloc.add(CodeChanged(v ?? '')),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPassword,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: LocaleKeys.auth_newPassword.tr(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      bloc.add(TogglePasswordVisibility()),
                                  icon: Icon(
                                    state.obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              obscureText: state.obscurePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: passwordValidator,
                              onSaved: (v) =>
                                  bloc.add(NewPasswordChanged(v ?? '')),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: LocaleKeys.auth_passwordRepeat.tr(),
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              obscureText: state.obscurePassword,
                              validator: repeatPasswordValidator(_newPassword),
                              onFieldSubmitted: (_) => _confirm(context),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ErrorField(message: state.errorMessage),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: state.inProgress
                                ? null
                                : () => state.codeSent
                                    ? _confirm(context)
                                    : _sendCode(context),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: state.inProgress
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    state.codeSent
                                        ? LocaleKeys.auth_resetSubmit.tr()
                                        : LocaleKeys.auth_sendCode.tr(),
                                  ),
                          ),
                        ],
                      ),
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
