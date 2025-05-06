import 'package:flutter/material.dart';

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final double width;

  const CustomCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.width = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 30,
      // padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 1), borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: () {
          onChanged.call(!value);
        },
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: FittedBox(
                child: Checkbox(
                  value: value,
                  onChanged: (value) {
                    onChanged.call(value);
                  },
                  visualDensity: VisualDensity(horizontal: 0, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
