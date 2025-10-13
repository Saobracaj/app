import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/road.dart';
import 'package:saobracaj/test/animations/road_obstacle.dart';
import 'package:saobracaj/test/animations/trafic_cone.dart';

import 'emergency_triangle.dart';

class ObyezdAnimacija2 extends StatefulWidget {
  const ObyezdAnimacija2({super.key});

  @override
  State<ObyezdAnimacija2> createState() => _ObyezdAnimacija2State();
}

class _ObyezdAnimacija2State extends State<ObyezdAnimacija2> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnimation;
  late Animation<num> _yAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat();

    _xAnimation = Tween<double>(begin: -1.2, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _yAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -0.3), weight: 20),
      TweenSequenceItem(tween: ConstantTween(-0.3), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -0.3, end: 0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      height: 200,
      // padding: const EdgeInsets.all(16),
      child: ClipRect(
        child: Stack(
          children: [
            const RoadView(moving: true),
            Positioned.fill(child: const RoadView(moving: false)),

            // Неподвижная машина — синяя, стоит посередине экрана

            Positioned(
              left: width * 0.5,
              bottom: 10,
              child: Row(
                children: [
                  Column(
                    children: [
                      TrafficConeWidget(height: 25),
                      TrafficConeWidget(height: 25),
                      TrafficConeWidget(height: 25),

                    ],
                  ),
                  RoadObstacleWidget()
                ],
              ),
            ),

            // Машина, объезжающая — зелёная, анимированная
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                double dx = width * (0.5 + _xAnimation.value / 2);
                double dy = 30 - _yAnimation.value * 200; // подъём на 60px

                return Positioned(
                  left: dx,
                  bottom: dy,
                  child: SizedBox(height: 50, child: AnimatedAutoWidget(color: Colors.green, leftIndicatorOn: true)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
