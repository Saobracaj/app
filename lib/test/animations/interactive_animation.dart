import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// Обёртка вокруг зацикленной анимации: пауза/продолжение по тапу на сцену и
/// по кнопке под холстом, а для пошаговых сцен — ещё и переключение кадров по
/// номерам рядом с кнопкой.
///
/// Нажатие на номер проигрывает выбранный кадр с обычной скоростью и
/// останавливается в его конце: кадр можно читать сколько угодно, при этом
/// движение внутри кадра сохраняется — порядок действий виден анимацией, а не
/// мгновенной сменой стоп-кадров. Кнопка ▶ возвращает обычный цикл с того же
/// места.
///
/// Основной конструктор забирает `AnimationController` сцены себе: сцена
/// строится в [builder] от выданной [Animation]. Для сцен, которые крутят
/// собственные контроллеры внутри (старые составные анимации), есть
/// [InteractiveAnimation.pauseOnly]: она ничего не знает про их время и
/// останавливает всё разом через [TickerMode] — кадры там переключать нельзя,
/// только пауза.
class InteractiveAnimation extends StatefulWidget {
  const InteractiveAnimation({
    super.key,
    required Duration this.cycle,
    required Widget Function(BuildContext, Animation<double>) this.builder,
    this.stepStarts,
  }) : child = null;

  const InteractiveAnimation.pauseOnly({super.key, required Widget this.child})
      : cycle = null,
        builder = null,
        stepStarts = null;

  /// Длительность полного цикла — та же, что была у самой анимации.
  final Duration? cycle;

  /// Начала кадров в долях цикла, по возрастанию; первый всегда `0.0`.
  /// `null` — у анимации нет выделенных кадров, доступна только пауза.
  final List<double>? stepStarts;

  /// Строит сцену. [Animation] бежит 0…1 за [cycle] — то же самое, что раньше
  /// делал собственный `AnimationController` сцены.
  final Widget Function(BuildContext context, Animation<double> animation)?
      builder;

  /// Сцена со своими контроллерами — режим [InteractiveAnimation.pauseOnly].
  final Widget? child;

  @override
  State<InteractiveAnimation> createState() => _InteractiveAnimationState();
}

class _InteractiveAnimationState extends State<InteractiveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController? _controller = widget.builder == null
      ? null
      : (AnimationController(duration: widget.cycle, vsync: this)..repeat());

  bool _playing = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      final controller = _controller;
      if (controller != null) {
        if (_playing) {
          controller.stop();
        } else {
          controller.repeat();
        }
      }
      _playing = !_playing;
    });
  }

  /// Проигрывает кадр [index] от начала и замирает в его конце. Останавливаемся
  /// чуть раньше границы, чтобы подсветка номера не перескочила на следующий
  /// кадр, когда значение сравняется с его началом.
  void _showStep(int index) {
    final starts = widget.stepStarts!;
    final start = starts[index];
    final end = (index + 1 < starts.length ? starts[index + 1] : 1.0) - 0.001;
    setState(() => _playing = false);
    final controller = _controller!;
    controller.stop();
    controller.value = start;
    controller.animateTo(end, duration: widget.cycle! * (end - start));
  }

  int get _currentStep {
    final starts = widget.stepStarts!;
    var index = 0;
    for (var i = 0; i < starts.length; i++) {
      if (_controller!.value >= starts[i]) index = i;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scene = controller != null
        ? widget.builder!(context, controller)
        // Пауза для сцены с собственными контроллерами: TickerMode глушит все
        // тикеры в поддереве, при включении время продолжает идти с того же
        // места.
        : TickerMode(enabled: _playing, child: widget.child!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: scene,
        ),
        if (controller != null && widget.stepStarts != null)
          // Управление перестраивается каждый тик ради подсветки текущего
          // кадра — это одна строка мелких виджетов, сцена сюда не входит.
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _controls(context),
          )
        else
          _controls(context),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final starts = widget.stepStarts;
    final current = starts == null ? -1 : _currentStep;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        IconButton(
          onPressed: _togglePlay,
          tooltip: context.tr(
            _playing
                ? LocaleKeys.interactiveAnimation_pause
                : LocaleKeys.interactiveAnimation_play,
          ),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        if (starts != null)
          for (var i = 0; i < starts.length; i++)
            _StepChip(
              number: i + 1,
              current: i == current,
              onTap: () => _showStep(i),
            ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context
          .tr(LocaleKeys.interactiveAnimation_step, args: ['$number']),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Material(
          shape: const CircleBorder(),
          color: current ? scheme.primary : scheme.surfaceContainerHighest,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: current ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
