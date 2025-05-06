import 'package:flutter/material.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';

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

            border: TableBorder.all(color: Colors.grey.shade400),
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Питање', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1, textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text('Број поена', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text('Одговорено', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: FittedBox(child: Text('Обележено', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), maxLines: 1)),
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
                      child: entries[i].marked ? const Icon(Icons.bookmark, color: Colors.orange) : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16),
          CustomIconButton(onPressed: () {
            Navigator.of(context).pop();
          }, icon: Icons.arrow_back, label: 'Назад', color: Color(0xfffee188), textColor: const Color(0xff946331)),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
