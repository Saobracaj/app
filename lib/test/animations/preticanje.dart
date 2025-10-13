import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/road.dart';

class ObgonAnimacija extends StatefulWidget {
  const ObgonAnimacija({super.key});

  @override
  State<ObgonAnimacija> createState() => _ObgonAnimacijaState();
}

class _ObgonAnimacijaState extends State<ObgonAnimacija>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _verticalAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Горизонтальное движение — машина проезжает слева направо
    _horizontalAnimation = Tween<double>(
      begin: -1.2,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    final anim = 0.3;
    // Вертикальное смещение — для обгона
    _verticalAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -anim), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: anim, end: -anim), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -anim, end: 0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: anim), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: ClipRect(
        child: Stack(
          children: [
            RoadView(moving: true),
            Positioned.fill(child: RoadView(moving: true)),

            // Медленная (обгоняемая) машина — синяя, по центру
            Positioned(
              // left: MediaQuery.of(context).size.width * 0.4,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.only(bottom: 10),
                  height: 70,
                  child: AnimatedAutoWidget(color: Colors.blue),
                ),
              ),
            ),

            // Обгоняющая машина — зелёная, двигается по дуге
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      (0.5 + _horizontalAnimation.value),
                  bottom: 30 +
                      200 * -_verticalAnimation.value, // вверх на 80 пикселей
                  child: Container(
                    padding: EdgeInsets.only(top: 10),
                    height: 70,
                    child: AnimatedAutoWidget(color: Colors.green, leftIndicatorOn: true,),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
