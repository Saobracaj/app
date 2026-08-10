# Что уже нарисовано

Всё лежит в `app/lib/test/animations/`. Перед тем как рисовать новое —
посмотри, не собирается ли сцена из этого.

## Строительные блоки

| Файл | Публичный API | Что рисует |
| --- | --- | --- |
| `road.dart` | `RoadView({bool moving = false})` | Дорога вид сверху во всю ширину родителя: серый асфальт + белая прерывистая осевая. `moving: true` гонит разметку справа налево (иллюзия движения камеры). Растягивается на `Positioned.fill`. |
| `auto.dart` | `AnimatedAutoWidget({required Color color, bool leftIndicatorOn, bool rightIndicatorOn})` | Легковая машина вид сверху, **носом вправо**. Холст 190×100 в `FittedBox(scaleDown)` — задавай размер через `SizedBox(height: 50)`. Мигалки поворотников моргают сами (`Timer.periodic` 500 мс); обе разом = аварийка. |
| `road_obstacle.dart` | `RoadObstacleWidget({double size = 50})` | Яма/препятствие на дороге. |
| `trafic_cone.dart` | `TrafficConeWidget({double height})` | Дорожный конус. |
| `emergency_triangle.dart` | `EmergencyTriangle({double size = 20, double rotationDegrees = 30})` | Знак аварийной остановки, наклонён «лёжа на дороге» (перспектива через `Matrix4`). |
| `rastojanje_odstojanje.dart` | `HorizontalDistanceLine({required String text})`, `VerticalDistanceLine({required String text})` | Двусторонняя стрелка-размер с подписью — горизонтальная и вертикальная. Готовая выноска для любых схем «расстояние между X и Y». |

Развернуть машину носом влево:

```dart
Transform(
  alignment: Alignment.center,
  transform: Matrix4.rotationY(math.pi),
  child: AnimatedAutoWidget(color: Colors.green),
)
```

## Готовые сцены (образцы для копирования приёмов)

| Файл | Класс | Слаг в карте | Приём, который стоит подсмотреть |
| --- | --- | --- | --- |
| `decision_tree_widget.dart` | `ThemedCompactDecisionTree` | `kategorije-stablo` | **Эталон статичной схемы:** фиксированный холст 400×600 в `FittedBox`, все цвета из `ColorScheme`, подписи через `LocaleKeys` в объекте `_TreeLabels` с `==`/`hashCode`, вспомогательные `_drawBox` / `_drawDiamond` / `_drawArrow` / `_drawText` и пунктир через `computeMetrics()`. |
| `mimoilazenje.dart` | `Mimoilazenje` | `mimoilazenje` | Простейшая сцена: `Stack` + `RoadView` + `SlideTransition` встречной машины. |
| `obgon.dart` | `Obgon` | `preticanje` | Обгон: движение по X плюс смещение по Y через `TweenSequence`. |
| `obilazenje1.dart` / `obilazenje2.dart` | `ObyezdAnimacija`, `ObyezdAnimacija2` | `obilazenje`, `obilazenje2` | Объезд стоящей машины, знак аварийной остановки в сцене. |
| `propustanje.dart` | `BlockedRoadScene` | `propustanje` | Поток из нескольких машин: одна `AnimationController` + сдвиг фазы на машину. |
| `preticanje.dart` | — | не зарегистрирован | Черновой вариант обгона. |
| `rastojanje_odstojanje.dart` | `RastojanjeOndsojanje` | `rastojanje_odstojanje` | Статичная схема с размерными линиями. |
| `manevri.dart` | `Manevri` | `manevri-animacija` | Как собрать сводную сцену из нескольких готовых (`Column` из пяти сцен). |

## Приёмы, которых в репозитории пока нет

Если понадобилось — рисуй в своём файле, но сразу выноси в отдельный
публичный виджет, если это пригодится ещё где-то (перекрёсток, светофор,
пешеход, знак — почти наверняка пригодятся):

- перекрёсток вид сверху (две пересекающиеся `RoadView` в `Stack`);
- светофор, знак в круге/треугольнике, разметка «зебра»;
- пиктограмма человека (силуэт из окружности и линий — этого достаточно);
- шкала/линейка со значениями (алкоголь, скорость, промилле);
- таблица-матрица «ситуация → что включено» (обычные `Table`/`Row`, а не
  `CustomPainter`: текстовую матрицу проще собрать виджетами).

## Что не переиспользовать

- `preticanje.dart` — не зарегистрирован в карте, оставлен как черновик.
- Литеральные `Colors.grey.shade800` из `road.dart` — для новых схем бери
  цвет асфальта из темы (`reference/style-guide.md`, раздел «Цвета»).
