import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class ConfettiDemo extends StatefulWidget {
  const ConfettiDemo({super.key});

  @override
  State<ConfettiDemo> createState() => _ConfettiDemoState();
}

class _ConfettiDemoState extends State<ConfettiDemo> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 5));
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: - pi / 2,
            emissionFrequency: 0.3,
            numberOfParticles: 10,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.1,
            shouldLoop: true,
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: - pi / 2,
            emissionFrequency: 0.3,
            numberOfParticles: 10,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.1,
            shouldLoop: true,
          ),
        ),Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: - pi / 2,
            emissionFrequency: 0.3,
            numberOfParticles: 10,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.1,
            shouldLoop: true,
          ),
        ),
      ],
    );
  }
}