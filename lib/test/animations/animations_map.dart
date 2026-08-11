import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/pravilno_sedenje.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/oznaka_pneumatika.dart';
import 'package:saobracaj/test/animations/oznake_sporo_dugo_tesko.dart';
import 'package:saobracaj/test/animations/presek_puta.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';
import 'package:saobracaj/test/animations/znak_naselje.dart';
import 'package:saobracaj/test/animations/zone_uporedno.dart';

import 'decision_tree_widget.dart';
import 'dve_vrste_nezgode.dart';
import 'istureni_teret.dart';
import 'mimoilazenje.dart';
import 'mimoilazenje_nagib.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'oznake_tereta.dart';
import 'postupak_teska_nezgoda.dart';
import 'uklanjanje_tok.dart';
import 'zabranjena_mesta_za_lica.dart';
import 'obilazenje_prepreke.dart';
import 'trougao_i_prsluk.dart';
import 'pravilo_jednog_vozila.dart';

final _animations = {
  'mimoilazenje': Mimoilazenje(),
  'mimoilazenje-nagib': MimoilazenjeNagib(),
  'pravilo-jednog-vozila': PraviloJednogVozila(),
  'preticanje': Obgon(),
  'obilazenje': ObyezdAnimacija(),
  'obilazenje2': ObyezdAnimacija2(),
  'propustanje': BlockedRoadScene(),
  // Слаг из ТЗ; старый ключ 'rastojanje_odstojanje' убран — по текстам
  // комментариев и объяснений в БД бэкенда он нигде не встречается.
  'odstojanje-rastojanje-shema': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'kategorije-stablo': ThemedCompactDecisionTree(),
  'oznaka-pneumatika': OznakaPneumatika(),
  'oznake-sporo-dugo-tesko': OznakeSporoDugoTesko(),
  'presek-puta': PresekPuta(),
  'znak-naselje': ZnakNaselje(),
  'zone-uporedno': ZoneUporedno(),
  'pravilno-sedenje': PravilnoSedenje(),
  // Конспект 33 «Превоз терета и лица»
  'istureni-teret': IstureniTeret(),
  'oznake-tereta': OznakeTereta(),
  'zabranjena-mesta-za-lica': ZabranjenaMestaZaLica(),
  // Конспект 35 «Обязанности участников при ДТП»
  'dve-vrste-nezgode': DveVrsteNezgode(),
  'postupak-teska-nezgoda': PostupakTeskaNezgoda(),
  // Конспект 36 «Специальные меры и полномочия»
  'uklanjanje-tok': UklanjanjeTok(),
  // Конспект 30 «Правила дорожного движения»
  'trougao-i-prsluk': TrougaoIPrsluk(),
  'obilazenje-prepreke': ObilazenjePrepreke(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
