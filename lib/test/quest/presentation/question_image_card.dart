import 'package:flutter/material.dart';

/// Hero tag of the photo of the question with [imageId]. Shared by the preview
/// sheet and the full question screen, so expanding the preview flies the photo
/// into place instead of cutting to it.
String questionImageHeroTag(int imageId) => 'question-image-$imageId';

/// The situation photo in a fixed-proportion rounded card, so the layout does
/// not jump between questions. Most assets are 4:3 (with a 10:7 minority);
/// anything wider letterboxes on a tinted background instead of cropping —
/// road-sign details at the edges must stay visible.
class QuestionImageCard extends StatelessWidget {
  const QuestionImageCard({super.key, required this.imageId});

  final int imageId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Hero(
            tag: questionImageHeroTag(imageId),
            // The photo is the one thing both the preview and the full screen
            // show, so it is what carries the eye between them.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.asset(
                    'assets/img/$imageId.jpeg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
