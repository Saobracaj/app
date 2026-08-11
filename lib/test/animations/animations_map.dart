import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/probna_brzine.dart';
import 'package:saobracaj/test/animations/probna_ogranicenja.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';
import 'package:saobracaj/test/animations/vozac_vs_vozilo.dart';

import 'decision_tree_widget.dart';
import 'mimoilazenje.dart';
import 'obgon.dart';
import 'obilazenje1.dart';

final _animations = {
  'mimoilazenje': Mimoilazenje(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  'rastojanje_odstojanje': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
  'probna-ogranicenja': ProbnaOgranicenja(),
  'probna-brzine': ProbnaBrzine(),
  'vozac-vs-vozilo': VozacVsVozilo(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
