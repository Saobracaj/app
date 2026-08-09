import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/responsive.dart';
import '../models/test_push_result.dart';
import '../state_management/test_push_bloc.dart';
import '../state_management/test_push_events.dart';
import '../state_management/test_push_state.dart';

/// Экран «Тестовый пуш» из настроек: форма, которая ставит одно уведомление в
/// очередь бэкенда для указанной **почты**.
///
/// Виден только держателям права `send_test_push` (см. `ProfilePage`), но
/// настоящая проверка права — на бэкенде: сюда можно прийти и по прямой ссылке.
class TestPushPage extends StatelessWidget {
  const TestPushPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('testPush.title'.tr())),
      body: SafeArea(
        child: BlocProvider(
          create: (_) => getIt<TestPushBloc>()..add(TestPushOpened()),
          child: const _TestPushView(),
        ),
      ),
    );
  }
}

class _TestPushView extends StatelessWidget {
  const _TestPushView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestPushBloc, TestPushState>(
      builder: (context, state) {
        final bloc = context.read<TestPushBloc>();
        final scheme = Theme.of(context).colorScheme;
        return ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'testPush.hint'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _Field(
                // Значение приходит из блока (при открытии — своя почта), а
                // такое поле контроллером не удержать: initialValue у TextField
                // нет, поэтому здесь TextFormField с ключом на значении блока.
                key: ValueKey('email:${state.email}'),
                initialValue: state.email,
                label: 'testPush.email'.tr(),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onChanged: (v) => bloc.add(TestPushEmailChanged(v)),
              ),
              const SizedBox(height: 12),
              _Field(
                initialValue: state.title,
                label: 'testPush.pushTitle'.tr(),
                helperText: 'testPush.optional'.tr(),
                onChanged: (v) => bloc.add(TestPushTitleChanged(v)),
              ),
              const SizedBox(height: 12),
              _Field(
                initialValue: state.body,
                label: 'testPush.body'.tr(),
                helperText: 'testPush.optional'.tr(),
                maxLines: 3,
                onChanged: (v) => bloc.add(TestPushBodyChanged(v)),
              ),
              const SizedBox(height: 12),
              _Field(
                initialValue: state.link,
                label: 'testPush.link'.tr(),
                helperText: 'testPush.linkHint'.tr(),
                onChanged: (v) => bloc.add(TestPushLinkChanged(v)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.canSend
                    ? () => bloc.add(TestPushSubmitted())
                    : null,
                icon: state.sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text('testPush.send'.tr()),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                _Banner(
                  icon: Icons.error_outline,
                  color: scheme.error,
                  text: state.errorMessage!,
                ),
              ],
              if (state.result != null) ...[
                const SizedBox(height: 16),
                _ResultBanner(result: state.result!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
    this.helperText,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

/// Итог отправки. Отдельная плашка от ошибки: главное здесь — число пригодных
/// устройств, и ноль (уведомление принято, но доставлять некуда) выглядит как
/// предупреждение, а не как успех.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final TestPushResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final devices = 'testPush.devices'.plural(result.devices);
    return _Banner(
      icon: result.hasDevices
          ? Icons.check_circle_outline
          : Icons.warning_amber,
      color: result.hasDevices ? scheme.primary : scheme.tertiary,
      text: result.hasDevices
          ? '${'testPush.queued'.tr(args: [result.email])}\n$devices'
          : '${'testPush.queued'.tr(args: [result.email])}\n'
                '${'testPush.noDevices'.tr()}',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
