import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';

import 'blokirana_raskrsnica.dart';
import 'decision_tree_widget.dart';
import 'klinc_raskrsnica.dart';
import 'mimoilazenje.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'pravilo_desne_strane.dart';

final _animations = {
  'pravilo-desne-strane': PraviloDesneStrane(),
  'klinc-raskrsnica': KlincRaskrsnica(),
  'blokirana-raskrsnica': BlokiranaRaskrsnica(),
  'mimoilazenje': Mimoilazenje(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  'rastojanje_odstojanje': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
