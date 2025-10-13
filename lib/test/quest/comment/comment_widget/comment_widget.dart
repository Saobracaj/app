import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/test/quest/quest.dart';
import '../state_management/comment_bloc.dart';

class CommentWidget extends StatelessWidget {
  final int questionId;

  const CommentWidget({super.key, required this.questionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommentBloc(questionId: questionId),
      child: BlocBuilder<CommentBloc, CommentState>(
        builder: (context, state) {
          if (state.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Text('Error: \\${state.errorMessage}');
          }
          if (state.text == null || state.text!.isEmpty) {
            return const SizedBox.shrink();
          }
          return QuestMarkdown(text: state.text!, padding: EdgeInsets.all(16), useLargeText: false);
        },
      ),
    );
  }
}
