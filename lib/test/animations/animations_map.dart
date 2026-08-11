import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';

import 'autoput_trake.dart';
import 'autoput_vs_motoput.dart';
import 'decision_tree_widget.dart';
import 'posebne_trake_autoput.dart';
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
  'autoput-trake': AutoputTrake(),
  'posebne-trake-autoput': PosebneTrakeAutoput(),
  'autoput-vs-motoput': AutoputVsMotoput(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
