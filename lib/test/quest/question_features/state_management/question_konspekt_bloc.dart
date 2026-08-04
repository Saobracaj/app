import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_events.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_state.dart';

/// Loads the konspekt of the question's category and keeps only the sections
/// whose `questionIds` include this question — the excerpts shown on the
/// "Конспект" tab. Sections that carry `blocks` are narrowed further, to just
/// the blocks mapped to this question. An empty result (no konspekt for the
/// category, none of its sections reference the question, or the document
/// could not be fetched) hides the tab.
@injectable
class QuestionKonspektBloc extends Bloc<QuestionKonspektEvent, QuestionKonspektState> {
  QuestionKonspektBloc(
    this._repository,
    @factoryParam this.questionId,
    @factoryParam this.categoryId,
  ) : super(const QuestionKonspektState()) {
    on<QuestionKonspektRequested>(_onRequested);
    add(QuestionKonspektRequested());
  }

  final KonspektRepository _repository;

  final int questionId;

  /// The category the question belongs to — the konspekt to excerpt from.
  final String categoryId;

  Future<void> _onRequested(QuestionKonspektRequested event, Emitter<QuestionKonspektState> emit) async {
    try {
      // Consult the catalog first: most categories have no konspekt, and this
      // avoids a doomed document query for them.
      final available = await _repository.availableCategories();
      if (!available.contains(categoryId)) {
        emit(state.copyWith(inProgress: false));
        return;
      }
      final konspekt = await _repository.load(categoryId);
      final sections = konspekt?.sections
              .where((s) => s.questionIds.contains(questionId))
              .map(_excerpt)
              .toList() ??
          const [];
      emit(state.copyWith(inProgress: false, sections: sections));
    } catch (_) {
      // Offline with nothing cached, or no premium entitlement: the tab just
      // stays hidden — the full konspekt page is where failures are explained.
      emit(state.copyWith(inProgress: false));
    }
  }

  /// Narrows a section to the blocks mapped to this question. Documents
  /// published before blocks existed (and sections whose mapping is broken —
  /// no block mentions the question) keep the whole section content.
  KonspektSection _excerpt(KonspektSection section) {
    final blocks = section.blocks.where((b) => b.questionIds.contains(questionId)).toList();
    if (blocks.isEmpty) return section;
    String? join(String? Function(KonspektText) pick) {
      final parts = blocks.map((b) => pick(b.content)).whereType<String>().toList();
      return parts.isEmpty ? null : parts.join('\n\n');
    }

    return section.copyWith(content: KonspektText(ru: join((t) => t.ru), sr: join((t) => t.sr)));
  }
}
