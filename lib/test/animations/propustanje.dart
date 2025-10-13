import 'dart:math';
import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/road.dart';
import 'package:saobracaj/test/animations/road_obstacle.dart';
import 'package:saobracaj/test/animations/trafic_cone.dart';
import 'emergency_triangle.dart';

class BlockedRoadScene extends StatefulWidget {
  const BlockedRoadScene({super.key});

  @override
  State<BlockedRoadScene> createState() => _BlockedRoadSceneState();
}

class _BlockedRoadSceneState extends State<BlockedRoadScene> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final int carCount = 3;
  final List<Color> _carColors = [];
  final List<double> _startDelays = [];

  final availableColors = [
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: const Duration(seconds: 6), vsync: this)..repeat();

    _animation = Tween<double>(begin: -1.5, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _generateCars();
  }

  void _generateCars() {
    final random = Random();
    _carColors.clear();
    _startDelays.clear();
    for (int i = 0; i < carCount; i++) {
      _carColors.add(availableColors[random.nextInt(availableColors.length)]);
      _startDelays.add(i * 0.5); // интервал между машинами
    }
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

            // Неподвижная машина + конусы + препятствие
            Positioned(
              bottom: 10,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  children: [
                    SizedBox(
                      height: 50,
                      child: AnimatedAutoWidget(color: Colors.blue, leftIndicatorOn: true),
                    ),
                    Column(children: [
                      TrafficConeWidget(height: 25),
                      TrafficConeWidget(height: 25),
                      TrafficConeWidget(height: 25),
                    ]),
                    RoadObstacleWidget(),
                  ],
                ),
              ),
            ),

            // Едущие машины
            ...List.generate(carCount, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double progress = (_animation.value + _startDelays[index]) % 2.7;
                  double dxNorm = progress - 1.5; // от -1.5 до 1.2
                  double dx = width * (0.5 - dxNorm);
                  double dy = 10.0;

                  return Positioned(
                    left: dx,
                    top: dy,
                    child: SizedBox(
                      height: 50,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.1415926535),
                        child: AnimatedAutoWidget(color: _carColors[index]),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
