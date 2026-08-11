import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/kruzni_tok.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/pravilno_sedenje.dart';
import 'package:saobracaj/test/animations/alkohol_prag_skala.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/nula_promila.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/oznaka_pneumatika.dart';
import 'package:saobracaj/test/animations/oznake_sporo_dugo_tesko.dart';
import 'package:saobracaj/test/animations/presek_puta.dart';
import 'package:saobracaj/test/animations/preticanje_sekvenca.dart';
import 'package:saobracaj/test/animations/preticanje_strane.dart';
import 'package:saobracaj/test/animations/posebni_signali.dart';
import 'package:saobracaj/test/animations/propustanje_vozila_s_prvenstvom.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/pruzni_prelaz.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';
import 'package:saobracaj/test/animations/znak_naselje.dart';
import 'package:saobracaj/test/animations/zone_uporedno.dart';
import 'package:saobracaj/test/animations/trake_pred_prugom.dart';
import 'package:saobracaj/test/animations/probna_brzine.dart';
import 'package:saobracaj/test/animations/probna_ogranicenja.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';
import 'package:saobracaj/test/animations/vozac_vs_vozilo.dart';
import 'package:saobracaj/test/animations/skala_alkohola.dart';

import 'blokirana_raskrsnica.dart';
import 'decision_tree_widget.dart';
import 'dve_vrste_nezgode.dart';
import 'istureni_teret.dart';
import 'hijerarhija_piramida.dart';
import 'klinc_raskrsnica.dart';
import 'dopunske_table_parkiranje.dart';
import 'katadiopteri_na_prikolici.dart';
import 'dimenzije_vozila.dart';
import 'mase_vozila.dart';
import 'boje_svetala_napred_nazad.dart';
import 'decision_tree_widget.dart';
import 'dometi_svetlosnih_snopova.dart';
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
import 'zaustavni_put.dart';
import 'tri_vrste_znakova.dart';
import 'uzduzne_linije.dart';
import 'znaci_policajca.dart';
import 'pozicija_pred_skretanje.dart';
import 'skretanje_pesaci.dart';
import 'pravilo_desne_strane.dart';
import 'zabrana_zaustavljanja_parkiranja.dart';
import 'zaustavljeno_vs_parkirano.dart';
import 'prikolica_b_vs_be.dart';
import 'raskinuta_veza_prikolice.dart';
import 'opterecenje_vs_dimenzije.dart';
import 'upotreba_svetala_matrica.dart';

final _animations = {
  'pravilo-desne-strane': PraviloDesneStrane(),
  'klinc-raskrsnica': KlincRaskrsnica(),
  'blokirana-raskrsnica': BlokiranaRaskrsnica(),
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
  'preticanje-sekvenca': PreticanjeSekvenca(),
  'preticanje-strane': PreticanjeStrane(),
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
  'zaustavni-put': ZaustavniPut(),
  // Конспект 32 «Саобраћајна сигнализација»
  'tri-vrste-znakova': TriVrsteZnakova(),
  'uzduzne-linije': UzduzneLinije(),
  'hijerarhija-piramida': HijerarhijaPiramida(),
  'znaci-policajca': ZnaciPolicajca(),
  'pruzni-prelaz': PruzniPrelaz(),
  'trake-pred-prugom': TrakePredPrugom(),
  'pozicija-pred-skretanje': PozicijaPredSkretanje(),
  'skretanje-pesaci': SkretanjePesaci(),
  'kruzni-tok': KruzniTok(),
  'zaustavljeno-vs-parkirano': ZaustavljenoVsParkirano(),
  'zabrana-zaustavljanja-parkiranja': ZabranaZaustavljanjaParkiranja(),
  'dopunske-table-parkiranje': DopunskeTableParkiranje(),
  'prikolica-b-vs-be': PrikolicaBvsBe(),
  'katadiopteri-na-prikolici': KatadiopteriNaPrikolici(),
  'raskinuta-veza-prikolice': RaskinutaVezaPrikolice(),
  'probna-ogranicenja': ProbnaOgranicenja(),
  'probna-brzine': ProbnaBrzine(),
  'vozac-vs-vozilo': VozacVsVozilo(),
  'alkohol-prag-skala': AlkoholPragSkala(),
  'skala-alkohola': SkalaAlkohola(),
  'nula-promila': NulaPromila(),
  'mase-vozila': MaseVozila(),
  'opterecenje-vs-dimenzije': OpterecenjeVsDimenzije(),
  'dimenzije-vozila': DimenzijeVozila(),
  'boje-svetala-napred-nazad': BojeSvetalaNapredNazad(),
  'dometi-svetlosnih-snopova': DometiSvetlosnihSnopova(),
  'upotreba-svetala-matrica': UpotrebaSvetalaMatrica(),
  'posebni-signali': PosebniSignali(),
  'propustanje-vozila-s-prvenstvom': PropustanjeVozilaSPrvenstvom(),
};

Widget getAnimation(String animationName) {
  return _animations[animationName] ?? Text('Animation not found');
}
