import 'package:flutter/material.dart';
import 'package:saobracaj/test/practice/exam_strings.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';
import 'package:saobracaj/theme/exam_theme.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

class TableEntry {
  final String question;
  final int points;
  final bool answered;
  final bool marked;

  TableEntry({required this.question, required this.points, required this.answered, required this.marked});
}

class QuestionsTable extends StatelessWidget {
  final List<TableEntry> entries;
  final Function(int index, bool? value) onAnswerToggle;

  const QuestionsTable({super.key, required this.entries, required this.onAnswerToggle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(7), // Питање
              1: FlexColumnWidth(4), // Број поена
              2: FlexColumnWidth(4), // Одговорено
              3: FlexColumnWidth(4), // Обележено
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,

            border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(ExamStrings.reportColumnQuestion, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1, textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text(ExamStrings.reportColumnPoints, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text(ExamStrings.reportColumnAnswered, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text(ExamStrings.reportColumnMarked, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
                  ),
                ],
              ),
              // Rows
              for (int i = 0; i < entries.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(i);
                        },
                        child: Text(entries[i].question),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(8.0), child: Center(child: Text('${entries[i].points}'))),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Checkbox(value: entries[i].answered, onChanged: (val) => onAnswerToggle(i, val)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: entries[i].marked ? Icon(Icons.bookmark, color: Theme.of(context).quiz.warning) : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16),
          CustomIconButton(onPressed: () {
            Navigator.of(context).pop();
          }, icon: Icons.arrow_back, label: ExamStrings.back, color: ExamPalette.report, textColor: ExamPalette.onReport),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
