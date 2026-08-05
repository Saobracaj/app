import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/firebase_login/firebase_login_bloc.dart';
import '../state_management/login/login_bloc.dart';
import '../state_management/login/login_events.dart';
import '../state_management/login/login_state.dart';
import 'error_field.dart';
import 'social_login.dart';
import 'validators.dart';

/// Email + password login screen. On success the repository publishes the
/// session (picked up by the app-wide `AuthBloc`) and the page returns to where
/// the user came from.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginBloc>(),
      // Соц-вход живёт над всей формой: пока он идёт, поля и кнопки ниже
      // выключаются.
      child: SocialLoginScope(child: LoginView()),
    );
  }
}

class LoginView extends StatelessWidget {
  LoginView({super.key});

  final _formKey = GlobalKey<FormState>();

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      _formKey.currentState!.save();
      context.read<LoginBloc>().add(SubmitPressed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_loginTitle.tr())),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocConsumer<LoginBloc, LoginState>(
                  listenWhen: (p, c) =>
                      p.loggedIn != c.loggedIn ||
                      p.needsConfirmationFor != c.needsConfirmationFor,
                  listener: (context, state) {
                    if (state.loggedIn) {
                      Routemaster.of(context).pop();
                    } else if (state.needsConfirmationFor != null) {
                      final email =
                          Uri.encodeComponent(state.needsConfirmationFor!);
                      Routemaster.of(context).replace('/confirmCode?email=$email');
                    }
                  },
                  builder: (context, state) {
                    final bloc = context.read<LoginBloc>();
                    // Пока идёт любой вход (по паролю или через соцсеть) — вся
                    // форма недоступна: ни полей, ни кнопок, ни ссылок.
                    final socialBusy = context
                        .watch<FirebaseLoginBloc>()
                        .state
                        .isBusy;
                    final locked = state.inProgress || socialBusy;
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            enabled: !locked,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: LocaleKeys.auth_email.tr(),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: emailValidator,
                            onSaved: (v) => bloc.add(EmailChanged(v ?? '')),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            enabled: !locked,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: LocaleKeys.auth_password.tr(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: locked
                                    ? null
                                    : () => bloc.add(TogglePasswordVisibility()),
                                icon: Icon(
                                  state.obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            obscureText: state.obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            validator: passwordValidator,
                            onSaved: (v) => bloc.add(PasswordChanged(v ?? '')),
                            onFieldSubmitted: (_) => _submit(context),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: locked
                                  ? null
                                  : () => Routemaster.of(context)
                                      .push('/resetPassword'),
                              child: Text(LocaleKeys.auth_forgotPassword.tr()),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ErrorField(message: state.errorMessage),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: locked ? null : () => _submit(context),
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
                                : Text(LocaleKeys.auth_loginSubmit.tr()),
                          ),
                          const SizedBox(height: 24),
                          SocialLogin(enabled: !state.inProgress),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(LocaleKeys.auth_noAccount.tr()),
                              TextButton(
                                onPressed: locked
                                    ? null
                                    : () => Routemaster.of(context)
                                        .replace('/register'),
                                child: Text(LocaleKeys.auth_toRegister.tr()),
                              ),
                            ],
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
