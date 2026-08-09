import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/mimoilazenje.dart';
import 'package:saobracaj/test/animations/obilazenje1.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';

import 'obgon.dart';

class Manevri extends StatelessWidget {
  const Manevri({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(
      children: [
        Mimoilazenje(),
        SizedBox(height: 4),
        Obgon(),
        SizedBox(height: 4),
        ObyezdAnimacija(),
        SizedBox(height: 4),
        ObyezdAnimacija2(),
        SizedBox(height: 4),
        BlockedRoadScene(),
      ],
    );
  }
}
