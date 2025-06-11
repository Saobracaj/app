import 'package:flutter/material.dart';

enum IconPosition { left, right }

class CustomIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final IconPosition iconPosition;

  const CustomIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.iconPosition = IconPosition.right,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: textColor ?? Colors.white);
    final textWidget = Text(label, style: TextStyle(color: textColor ?? Colors.white));

    final children =
        iconPosition == IconPosition.left ? [iconWidget, const SizedBox(width: 8), textWidget] : [textWidget, const SizedBox(width: 8), iconWidget];

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
      child: FittedBox(child: Row(mainAxisSize: MainAxisSize.min, children: children)),
    );
  }
}
