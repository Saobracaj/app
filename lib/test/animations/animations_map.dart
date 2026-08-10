import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';

import 'decision_tree_widget.dart';
import 'dve_vrste_nezgode.dart';
import 'istureni_teret.dart';
import 'mimoilazenje.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'oznake_tereta.dart';
import 'postupak_teska_nezgoda.dart';
import 'uklanjanje_tok.dart';
import 'zabranjena_mesta_za_lica.dart';

final _animations = {
  'mimoilazenje': Mimoilazenje(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  'rastojanje_odstojanje': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
  // Конспект 33 «Превоз терета и лица»
  'istureni-teret': IstureniTeret(),
  'oznake-tereta': OznakeTereta(),
  'zabranjena-mesta-za-lica': ZabranjenaMestaZaLica(),
  // Конспект 35 «Обязанности участников при ДТП»
  'dve-vrste-nezgode': DveVrsteNezgode(),
  'postupak-teska-nezgoda': PostupakTeskaNezgoda(),
  // Конспект 36 «Специальные меры и полномочия»
  'uklanjanje-tok': UklanjanjeTok(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
