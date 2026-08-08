import 'package:flutter/material.dart';
import 'package:saobracaj/models/models.dart';

/// A single question row: the question's image as a leading thumbnail with the
/// question text (truncated). Reused by the "recent mistakes" list on the
/// statistics screen, custom question lists and the question-search results.
class QuestionListTile extends StatelessWidget {
  const QuestionListTile({super.key, required this.question, this.onTap, this.trailing});

  final Question question;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(question.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      leading: QuestionThumbnail(question: question),
      trailing: trailing,
    );
  }
}

/// 48x48 question thumbnail; a placeholder icon when the question has no
/// image, so image-less questions never request a missing asset.
class QuestionThumbnail extends StatelessWidget {
  const QuestionThumbnail({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: question.hasImage
            ? Image.asset(
                'assets/img/${question.imageId}.jpeg',
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.car_crash, size: 48, color: Theme.of(context).colorScheme.secondary.withAlpha(50));
                },
              )
            : Icon(Icons.quiz_outlined, size: 32, color: Theme.of(context).colorScheme.secondary.withAlpha(50)),
      ),
    );
  }
}
