import 'package:flutter/material.dart';
import 'package:saobracaj/models/models.dart';

/// A single question row: the question text (truncated) with the question's
/// image as a trailing thumbnail. Reused by the "recent mistakes" list on the
/// statistics screen and by the question-search results on the questions page.
class QuestionListTile extends StatelessWidget {
  const QuestionListTile({super.key, required this.question, this.onTap});

  final Question question;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(question.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: SizedBox(
        width: 60,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/img/${question.id}.jpeg',
            width: 48,
            height: 48,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.car_crash, size: 48, color: Theme.of(context).colorScheme.secondary.withAlpha(50));
            },
          ),
        ),
      ),
    );
  }
}
