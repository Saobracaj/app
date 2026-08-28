import 'package:flutter/cupertino.dart';
import 'package:saobracaj/test/animations/alkohol_prag_skala.dart';
import 'package:saobracaj/test/animations/interactive_animation.dart';
import 'package:saobracaj/test/animations/kruzni_tok.dart';
import 'package:saobracaj/test/animations/manevri.dart';
import 'package:saobracaj/test/animations/nula_promila.dart';
import 'package:saobracaj/test/animations/obilazenje2.dart';
import 'package:saobracaj/test/animations/oznaka_pneumatika.dart';
import 'package:saobracaj/test/animations/oznake_sporo_dugo_tesko.dart';
import 'package:saobracaj/test/animations/posebni_signali.dart';
import 'package:saobracaj/test/animations/pravilno_sedenje.dart';
import 'package:saobracaj/test/animations/presek_puta.dart';
import 'package:saobracaj/test/animations/preticanje_sekvenca.dart';
import 'package:saobracaj/test/animations/preticanje_strane.dart';
import 'package:saobracaj/test/animations/probna_brzine.dart';
import 'package:saobracaj/test/animations/probna_ogranicenja.dart';
import 'package:saobracaj/test/animations/propustanje.dart';
import 'package:saobracaj/test/animations/propustanje_vozila_s_prvenstvom.dart';
import 'package:saobracaj/test/animations/pruzni_prelaz.dart';
import 'package:saobracaj/test/animations/rastojanje_odstojanje.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/test/animations/skala_alkohola.dart';
import 'package:saobracaj/test/animations/sta_sme_kategorija_b.dart';
import 'package:saobracaj/test/animations/trake_pred_prugom.dart';
import 'package:saobracaj/test/animations/vozac_vs_vozilo.dart';
import 'package:saobracaj/test/animations/znak_naselje.dart';
import 'package:saobracaj/test/animations/zone_uporedno.dart';

import 'autoput_trake.dart';
import 'autoput_vs_motoput.dart';
import 'blokirana_raskrsnica.dart';
import 'boje_svetala_napred_nazad.dart';
import 'decision_tree_widget.dart';
import 'dimenzije_vozila.dart';
import 'dometi_svetlosnih_snopova.dart';
import 'dopunske_table_parkiranje.dart';
import 'dve_vrste_nezgode.dart';
import 'hijerarhija_piramida.dart';
import 'istureni_teret.dart';
import 'katadiopteri_na_prikolici.dart';
import 'klinc_raskrsnica.dart';
import 'mase_vozila.dart';
import 'mimoilazenje.dart';
import 'mimoilazenje_nagib.dart';
import 'obgon.dart';
import 'obilazenje1.dart';
import 'obilazenje_prepreke.dart';
import 'opterecenje_vs_dimenzije.dart';
import 'oznake_tereta.dart';
import 'posebne_trake_autoput.dart';
import 'postupak_teska_nezgoda.dart';
import 'pozicija_pred_skretanje.dart';
import 'pravilo_desne_strane.dart';
import 'pravilo_jednog_vozila.dart';
import 'prikolica_b_vs_be.dart';
import 'raskinuta_veza_prikolice.dart';
import 'skretanje_pesaci.dart';
import 'tri_vrste_znakova.dart';
import 'trougao_i_prsluk.dart';
import 'uklanjanje_tok.dart';
import 'upotreba_svetala_matrica.dart';
import 'uzduzne_linije.dart';
import 'zabrana_zaustavljanja_parkiranja.dart';
import 'zabranjena_mesta_za_lica.dart';
import 'zaustavljeno_vs_parkirano.dart';
import 'zaustavni_put.dart';
import 'znaci_policajca.dart';

// Зацикленные сцены со своими контроллерами обёрнуты здесь в
// InteractiveAnimation.pauseOnly — пауза по тапу и кнопке. Пошаговые сцены
// (postupak-teska-nezgoda и подобные) оборачиваются основным конструктором
// InteractiveAnimation у себя в файле — там доступно и переключение кадров.
final _animations = {
  'pravilo-desne-strane': PraviloDesneStrane(),
  'klinc-raskrsnica': KlincRaskrsnica(),
  'blokirana-raskrsnica': BlokiranaRaskrsnica(),
  'mimoilazenje': InteractiveAnimation.pauseOnly(child: Mimoilazenje()),
  'mimoilazenje-nagib': InteractiveAnimation.pauseOnly(child: MimoilazenjeNagib()),
  'pravilo-jednog-vozila': InteractiveAnimation.pauseOnly(child: PraviloJednogVozila()),
  'preticanje': InteractiveAnimation.pauseOnly(child: Obgon()),
  'obilazenje': InteractiveAnimation.pauseOnly(child: ObyezdAnimacija()),
  'obilazenje2': InteractiveAnimation.pauseOnly(child: ObyezdAnimacija2()),
  'propustanje': InteractiveAnimation.pauseOnly(child: BlockedRoadScene()),
  // Слаг из ТЗ; старый ключ 'rastojanje_odstojanje' убран — по текстам
  // комментариев и объяснений в БД бэкенда он нигде не встречается.
  'odstojanje-rastojanje-shema': RastojanjeOndsojanje(),
  'manevri-animacija': Manevri(),
  'preticanje-sekvenca': InteractiveAnimation.pauseOnly(child: PreticanjeSekvenca()),
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
  'obilazenje-prepreke': InteractiveAnimation.pauseOnly(child: ObilazenjePrepreke()),
  'zaustavni-put': ZaustavniPut(),
  // Конспект 32 «Саобраћајна сигнализација»
  'tri-vrste-znakova': TriVrsteZnakova(),
  'uzduzne-linije': UzduzneLinije(),
  'hijerarhija-piramida': HijerarhijaPiramida(),
  'znaci-policajca': ZnaciPolicajca(),
  'pruzni-prelaz': InteractiveAnimation.pauseOnly(child: PruzniPrelaz()),
  'trake-pred-prugom': TrakePredPrugom(),
  'pozicija-pred-skretanje': PozicijaPredSkretanje(),
  'skretanje-pesaci': InteractiveAnimation.pauseOnly(child: SkretanjePesaci()),
  'kruzni-tok': InteractiveAnimation.pauseOnly(child: KruzniTok()),
  'zaustavljeno-vs-parkirano': ZaustavljenoVsParkirano(),
  'zabrana-zaustavljanja-parkiranja': ZabranaZaustavljanjaParkiranja(),
  'dopunske-table-parkiranje': DopunskeTableParkiranje(),
  'prikolica-b-vs-be': PrikolicaBvsBe(),
  'katadiopteri-na-prikolici': KatadiopteriNaPrikolici(),
  'raskinuta-veza-prikolice': InteractiveAnimation.pauseOnly(child: RaskinutaVezaPrikolice()),
  'sta-sme-kategorija-b': StaSmeKategorijaB(),
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
  'propustanje-vozila-s-prvenstvom': InteractiveAnimation.pauseOnly(child: PropustanjeVozilaSPrvenstvom()),
  'autoput-trake': AutoputTrake(),
  'posebne-trake-autoput': PosebneTrakeAutoput(),
  'autoput-vs-motoput': AutoputVsMotoput(),
};

Widget getAnimation(String animationName) {
  // `sign-<номер>` — официальный SVG знака из assets/signs/ (см.
  // road_sign.dart); конспекты вставляют их маркером `anim/sign-ii-2`.
  if (animationName.startsWith('sign-')) {
    final sign = animationName.substring('sign-'.length);
    // Дополнительные таблички (группа IV) масштабируются по ширине: их SVG —
    // либо широкая табличка, либо высокая композиция «знак + табличка», и при
    // общей высоте 48 сама табличка выходит нечитаемо мелкой.
    if (sign.startsWith('iv-')) {
      return RoadSignSvg(sign, width: 110);
    }
    return RoadSignSvg(sign, height: 48);
  }
  return _animations[animationName] ?? Text('Animation not found');
}
