import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_service.dart';

/// Отвечает на вопрос оператора «домотал ли человек до вкладок под вопросом»
/// (мобильная вёрстка — на широком экране вкладки видны всегда и обёртка не
/// используется): одно событие `question_tabs_viewed` на показ вопроса, когда
/// верх блока вкладок впервые оказался на экране — сразу после ответа на
/// коротком вопросе или после прокрутки на длинном.
///
/// StatefulWidget вместо Bloc сознательно: здесь нет ни состояния интерфейса,
/// ни бизнес-логики — только слушатель прокрутки и одноразовый флаг (тот же
/// класс исключения, что `_EnsureVisibleOnce` в question_features_tabs.dart).
class TabsSeenReporter extends StatefulWidget {
  const TabsSeenReporter({
    super.key,
    required this.questionId,
    required this.child,
  });

  final int questionId;
  final Widget child;

  @override
  State<TabsSeenReporter> createState() => _TabsSeenReporterState();
}

class _TabsSeenReporterState extends State<TabsSeenReporter> {
  ScrollPosition? _position;
  bool _reported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_check);
      _position = position;
      _position?.addListener(_check);
    }
    // Вкладки могут быть видны и без прокрутки — короткий вопрос на высоком
    // экране; проверка после первого кадра, когда размеры уже известны.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_reported || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // «Домотал» — когда от блока вкладок видно хотя бы заголовки-пилюли, а не
    // один пиксель верхней кромки.
    if (box.localToGlobal(Offset.zero).dy < viewportHeight - 48) {
      _reported = true;
      analytics.logQuestionTabsViewed(questionId: widget.questionId);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
