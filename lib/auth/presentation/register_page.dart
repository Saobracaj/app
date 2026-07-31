import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/register/register_bloc.dart';
import '../state_management/register/register_events.dart';
import '../state_management/register/register_state.dart';
import 'error_field.dart';
import 'social_login.dart';
import 'validators.dart';

/// Email + password registration. When the back-end requires email confirmation
/// the user is forwarded to the code-confirmation screen (driven by
/// [RegisterBloc]).
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RegisterBloc>(),
      child: RegisterView(),
    );
  }
}

class RegisterView extends StatelessWidget {
  RegisterView({super.key});

  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      _formKey.currentState!.save();
      context
          .read<RegisterBloc>()
          .add(SubmitPressed(context.locale.languageCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_registerTitle.tr())),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocConsumer<RegisterBloc, RegisterState>(
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
                    final bloc = context.read<RegisterBloc>();
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
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
                            controller: _password,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: LocaleKeys.auth_password.tr(),
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
                            onSaved: (v) => bloc.add(PasswordChanged(v ?? '')),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: LocaleKeys.auth_passwordRepeat.tr(),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: state.obscurePassword,
                            validator: repeatPasswordValidator(_password),
                            onFieldSubmitted: (_) => _submit(context),
                          ),
                          const SizedBox(height: 8),
                          ErrorField(message: state.errorMessage),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed:
                                state.inProgress ? null : () => _submit(context),
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
                                : Text(LocaleKeys.auth_registerSubmit.tr()),
                          ),
                          const SizedBox(height: 24),
                          const SocialLogin(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(LocaleKeys.auth_haveAccount.tr()),
                              TextButton(
                                onPressed: () =>
                                    Routemaster.of(context).replace('/login'),
                                child: Text(LocaleKeys.auth_toLogin.tr()),
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
