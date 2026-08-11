import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';

import 'decision_tree_widget.dart';
import 'dimenzije_vozila.dart';
import 'mase_vozila.dart';
import 'mimoilazenje.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'opterecenje_vs_dimenzije.dart';

final _animations = {
  'mimoilazenje': Mimoilazenje(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  'rastojanje_odstojanje': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
  'mase-vozila': MaseVozila(),
  'opterecenje-vs-dimenzije': OpterecenjeVsDimenzije(),
  'dimenzije-vozila': DimenzijeVozila(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
