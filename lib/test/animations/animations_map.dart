import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';

import 'decision_tree_widget.dart';
import 'katadiopteri_na_prikolici.dart';
import 'mimoilazenje.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'prikolica_b_vs_be.dart';
import 'raskinuta_veza_prikolice.dart';

final _animations = {
  'mimoilazenje': Mimoilazenje(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  'rastojanje_odstojanje': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
  'prikolica-b-vs-be': PrikolicaBvsBe(),
  'katadiopteri-na-prikolici': KatadiopteriNaPrikolici(),
  'raskinuta-veza-prikolice': RaskinutaVezaPrikolice(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
