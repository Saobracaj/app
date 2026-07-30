import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../generated/locale_keys.g.dart';
import '../data/graphql_client.dart';
import '../state_management/auth_cubit.dart';
import 'validators.dart';

/// Confirms the 6-digit email code sent after registration. On success the user
/// is logged in and returned to the app.
class ConfirmCodePage extends StatefulWidget {
  const ConfirmCodePage({super.key, required this.email});

  final String email;

  @override
  State<ConfirmCodePage> createState() => _ConfirmCodePageState();
}

class _ConfirmCodePageState extends State<ConfirmCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final cubit = context.read<AuthCubit>();
    final router = Routemaster.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cubit.repository.confirmEmail(widget.email, _code.text.trim());
      await cubit.onAuthenticated();
      if (!mounted) return;
      router.replace('/');
    } on GraphqlException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cubit.repository.resendConfirmationCode(widget.email);
      messenger.showSnackBar(
        SnackBar(content: Text(LocaleKeys.auth_codeResent.tr())),
      );
    } on GraphqlException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.auth_confirmTitle.tr())),
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
                      LocaleKeys.auth_confirmSubtitle.tr(args: [widget.email]),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _code,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: LocaleKeys.auth_code.tr(),
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      validator: codeValidator,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(LocaleKeys.auth_confirmSubmit.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _resend,
                      child: Text(LocaleKeys.auth_resendCode.tr()),
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
