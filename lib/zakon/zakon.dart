import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/zakon_bloc.dart';
import 'package:flutter/services.dart';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class Zakon extends StatefulWidget {
  const Zakon({super.key, this.paragraph, this.chlan, this.chapter});

  final String? paragraph;
  final String? chlan;
  final String? chapter;

  @override
  State<Zakon> createState() => _ZakonState();
}

class _ZakonState extends State<Zakon> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ZakonBloc(widget.paragraph, widget.chlan, widget.chapter),
      child: Scaffold(
        appBar: AppBar(
          title: Text('ЗАКОН о безбедности саобраћаја на путевима'),
          actions: [
            BlocBuilder<ZakonBloc, ZakonState>(
              builder: (context, state) {
                return IconButton(
                  onPressed: () {
                    context.read<ZakonBloc>().add(ToggleLang());
                  },
                  icon: Icon(Icons.translate_outlined),
                );
              },
            ),
          ],
        ),
        floatingActionButton: BlocBuilder<ZakonBloc, ZakonState>(
          builder: (context, state) {
            return FloatingActionButton.extended(
              onPressed: () async {
                final res = await _showTableOfContents(context, state);
                if(res != null && context.mounted) {
                  context.read<ZakonBloc>().add(ScrollTo(res.$1, res.$2, res.$3));
                }
              },
              label: Icon(Icons.list_alt_outlined),
            );
          },
        ),
        body: BlocConsumer<ZakonBloc, ZakonState>(
          listener: (context, state) {
            if (state.scrollTo != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _itemScrollController.scrollTo(
                  index: state.scrollTo!,
                  duration: const Duration(milliseconds: 300),
                  alignment: 0.0, // 0.0 = элемент попадёт вверх
                );
              });
            }
          },
          builder: (context, state) {
            return ScrollablePositionedList.builder(
              itemCount: state.zakon.length,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              itemBuilder: (context, index) {
                return _Paragraph(paragraph: state.zakon[index], isSerbian: state.isSr);
              },
            );
          },
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({super.key, required this.paragraph, required this.isSerbian});

  final BezbParagraph paragraph;
  final bool isSerbian;

  @override
  Widget build(BuildContext context) {
    String text = isSerbian ? (paragraph.sr ?? '') : (paragraph.ru ?? paragraph.sr ?? '');

    if (paragraph.isTitle) {
      return InkWell(
        onTap: () => _onTap(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            text.split('<sup>').join('').split('</sup>').join(''),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (paragraph.isChapter) {
      text = '# $text';
    } else if (paragraph.isChlan) {
      text = '## $text';
    }
    return InkWell(
      onTap: () => _onTap(context),
      child: Markdown(
        data: text.split('<sup>').join('').split('</sup>').join(''),
        shrinkWrap: true,
        selectable: false,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final queryParameters = <String, String?>{};

    if (paragraph.chapter != null) {
      queryParameters['chapter'] = paragraph.chapter;
    }

    if (paragraph.chlan != null) {
      queryParameters['chlan'] = paragraph.chlan;
    }

    if (paragraph.paragraph != null) {
      queryParameters['paragraph'] = paragraph.paragraph;
    }

    final uri = Uri.https('saobracaj.app', '/zakon', queryParameters);

    Clipboard.setData(ClipboardData(text: uri.toString())).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link is copied to clipboard')));
    });
  }
}

Future<(String?, String?, String?)?> _showTableOfContents(BuildContext context, ZakonState state) async {
  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder:
        (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            final List<BezbParagraph> paragraphs = state.zakon.where((element) => element.isTitle || element.isChapter || element.isChlan).toList();
            List<List<BezbParagraph>> list = [];

            var i = 0;
            while (i < paragraphs.length) {
              final p = paragraphs[i];

              if (!p.isChlan) {
                list.add([p]);
                i++;
              } else {
                final chlans = <BezbParagraph>[];

                BezbParagraph chlan = p;

                while (chlan.isChlan && i < paragraphs.length) {
                  chlan = paragraphs[i];
                  if (chlan.isChlan) {
                    chlans.add(chlan);
                    i++;
                  }
                }
                list.add(chlans);
              }
            }

            return ListView.builder(
              controller: controller,
              itemCount: list.length,
              itemBuilder: (context, index) => _TableOfContentsItem(paragraphs: list[index], isSerbian: state.isSr),
            );
            /*
        final allQuestions = context.read<AllQuestionsBloc>().state.questionsData?.questions ?? [];
        List<TableEntry> entries = [];
        for (var i = 0; i < state.questions.length; i++) {
          final q = state.questions[i];
          final question = allQuestions.firstWhere((element) => element.id == q);
          final t = TableEntry(
            question: 'Питање ${i + 1}',
            points: question.points,
            answered: state.answers.containsKey(q),
            marked: state.markedQuestions.contains(i),
          );
          entries.add(t);
        }
        return SingleChildScrollView(controller: controller, child: QuestionsTable(entries: entries, onAnswerToggle: (index, value) {}));*/
          },
        ),
  );
  return res;
}

extension _ParagraphExt on BezbParagraph {
  bool get isChapter => chapter != null && chlan == null && paragraph == null;

  bool get isChlan => chapter != null && chlan != null && paragraph == '0';
}

class _TableOfContentsItem extends StatelessWidget {
  const _TableOfContentsItem({super.key, required this.paragraphs, required this.isSerbian});

  final List<BezbParagraph> paragraphs;
  final bool isSerbian;

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isNotEmpty && !paragraphs.first.isChlan) {
      final paragraph = paragraphs.first;
      String text = isSerbian ? (paragraph.sr ?? '') : (paragraph.ru ?? paragraph.sr ?? '');

      return InkWell(
        onTap: () => _onTap(context, paragraph),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text.fixMd,
            // textAlign: TextAlign.center,
            style: paragraph.isTitle ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Wrap(
          children:
              paragraphs.map((e) {
                var text = Text((isSerbian ? (e.sr ?? '') : (e.ru ?? e.sr ?? '')).fixMd);

                return TextButton(
                  onPressed: () {
                    _onTap(context, e);
                  },
                  child: text,
                );
              }).toList(),
        ),
      );
    }
  }

  void _onTap(BuildContext context, BezbParagraph p) {
    Navigator.pop(context, (p.paragraph, p.chlan, p.chapter));
  }
}

extension _FixChlan on String {
  String get fixMd => replaceAll('*', '').replaceAll('<sup>', '').replaceAll('</sup>', '').replaceAll('\\', '').replaceAll('_', '').trim();
}
