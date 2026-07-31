import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../generated/locale_keys.g.dart';
import '../data/graphql_client.dart';
import '../state_management/auth_cubit.dart';
import 'validators.dart';

/// Two-step password reset: request a code by email, then set a new password
/// with that code. On success the user is logged in.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (emailValidator(_email.text) != null) {
      _formKey.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cubit.repository.requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
    } on GraphqlException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final cubit = context.read<AuthCubit>();
    final router = Routemaster.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cubit.repository.confirmPasswordReset(
        _email.text.trim(),
        _code.text.trim(),
        _newPassword.text,
      );
      await cubit.onAuthenticated();
      if (!mounted) return;
      router.replace('/');
    } on GraphqlException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_resetTitle.tr())),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
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
                      controller: _email,
                      enabled: !_codeSent,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: LocaleKeys.auth_email.tr(),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: emailValidator,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _code,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: LocaleKeys.auth_code.tr(),
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: codeValidator,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPassword,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: LocaleKeys.auth_newPassword.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: passwordValidator,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : (_codeSent ? _confirm : _sendCode),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _codeSent
                                  ? LocaleKeys.auth_resetSubmit.tr()
                                  : LocaleKeys.auth_sendCode.tr(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
