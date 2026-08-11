import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/mimoilazenje.dart';
import 'package:saobracaj/test/animations/obilazenje1.dart';
import 'package:saobracaj/test/animations/propustanje.dart';

import 'obgon.dart';

class Manevri extends StatelessWidget {
  const Manevri({super.key});

  @override
  Widget build(BuildContext context) {
    // Ровно четыре сцены — по одной на каждую строку таблицы манёвров в
    // конспекте. Вторая сцена объезда (ObyezdAnimacija2, конусы) отсюда убрана:
    // она подписана тем же словом «Обилажење», и подряд идущие одинаковые
    // подписи читались как повтор. Сцена осталась в карте под слагом
    // 'obilazenje2' — её можно вставить отдельным маркером.
    return Column(
      children: [
        Mimoilazenje(),
        SizedBox(height: 4),
        Obgon(),
        SizedBox(height: 4),
        ObyezdAnimacija(),
        SizedBox(height: 4),
        BlockedRoadScene(),
      ],
    );
  }
}
