import 'package:flutter/material.dart';

/// Inline, fade-in error line shown next to the form it belongs to (copied from
/// the owncup design). Renders empty space when [message] is null so the layout
/// doesn't jump when an error appears or clears.
class ErrorField extends StatelessWidget {
  const ErrorField({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        );
    const duration = Duration(milliseconds: 200);

    return AnimatedOpacity(
      opacity: message == null ? 0 : 1,
      duration: duration,
      child: Text(
        message ?? '',
        style: textStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}
