import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/road.dart';

class Mimoilazenje extends StatefulWidget {
  const Mimoilazenje({super.key});

  @override
  State<Mimoilazenje> createState() => _MimoilazenjeState();
}

class _MimoilazenjeState extends State<Mimoilazenje>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat();

    _animation = Tween<Offset>(
      begin: Offset(1.5, 0),  // за правым краем
      end: Offset(-1.5, 0),   // за левым краем
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
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
      // padding: EdgeInsets.all(16),
      child: ClipRRect(
        child: Stack(
          children: [
            RoadView(moving: true),
            Positioned.fill(child: RoadView(moving: true)),

            // Синяя машина (по центру, без анимации)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.only(bottom: 10),
                  height: 50,
                  child: AnimatedAutoWidget(color: Colors.blue),
                ),
              ),
            ),

            // Зелёная машина (сверху, двигается слева направо)
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: SlideTransition(
                  position: _animation,
                  child: Container(
                    padding: EdgeInsets.only(top: 10),
                    height: 50,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(3.1415926535),
                      child: AnimatedAutoWidget(color: Colors.green),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
