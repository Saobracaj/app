// Скриншоты для сторов (не тест поведения):
//   flutter test tool/store_screenshots_test.dart
//   FRAMES=simulation,konspekt LOCALES=sr CANVASES=ios flutter test tool/store_screenshots_test.dart
// Вывод: build/store_screenshots/<холст>/<NN>-<кадр>-<язык>.png
//        build/store_screenshots/play-feature-graphic-<язык>.png
//
// Каждый кадр — цветной фон, заголовок с подзаголовком и корпус устройства, в
// котором живёт настоящий экран приложения на реальных вопросах и конспектах
// из ассетов. Экран рендерится сразу в целевом разрешении, не масштабируется.
//
// Холсты: App Store — iPhone 6.9" и iPad 13"; Google Play — телефон, планшеты
// 7" и 10" (в корпусах Android: Play не любит чужие устройства). Планшеты — в
// альбомной ориентации: так широкие раскладки приложения заполняют экран.
//
// Правила сторов, которые здесь соблюдаются: только реально доступные функции,
// без цен, рейтингов и упоминаний других платформ; сетевые данные (обсуждение,
// чат с AI, объяснение) подставлены локальными заглушками с реалистичным
// содержимым.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/models/viewer.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/question_chat_count_bloc.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/core/network/state_management/network_status_bloc.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/home/home_content_page.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_bloc.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/question_lists/presentation/question_list_page.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_state.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/practice/finalize_practice.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:saobracaj/test/quest/comment/state_management/comment_bloc.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/ask_ai_chat_repository.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/state_management/ask_ai_chat_bloc.dart';
import 'package:saobracaj/test/quest/question_features/data/question_analytics_repository.dart';
import 'package:saobracaj/test/quest/question_features/data/question_difficulty_repository.dart';
import 'package:saobracaj/test/quest/question_features/models/question_analytics.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_analytics_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_cues_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_bloc.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/state_management/theme_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Устройства, холсты и подписи
// ---------------------------------------------------------------------------

/// Корпус, в котором рисуется экран, и его логические размеры.
class _Device {
  const _Device({
    required this.screen,
    required this.padding,
    required this.outerRadius,
    required this.screenRadius,
    required this.bezel,
    required this.ios,
    required this.tablet,
  });

  final Size screen;
  final EdgeInsets padding;
  final double outerRadius;
  final double screenRadius;
  final double bezel;
  final bool ios;
  final bool tablet;

  static const rim = 4.0;

  double get outerWidth => screen.width + 2 * (bezel + rim);
  double get outerHeight => screen.height + 2 * (bezel + rim);

  static const iphone = _Device(
    screen: Size(393, 852),
    padding: EdgeInsets.only(top: 59, bottom: 34),
    outerRadius: 74,
    screenRadius: 56,
    bezel: 14,
    ios: true,
    tablet: false,
  );
  static const ipad = _Device(
    screen: Size(1376, 1032),
    padding: EdgeInsets.only(top: 24, bottom: 20),
    outerRadius: 60,
    screenRadius: 36,
    bezel: 30,
    ios: true,
    tablet: true,
  );
  static const android = _Device(
    screen: Size(412, 892),
    padding: EdgeInsets.only(top: 44, bottom: 24),
    outerRadius: 52,
    screenRadius: 36,
    bezel: 14,
    ios: false,
    tablet: false,
  );
  static const androidTablet10 = _Device(
    screen: Size(1280, 800),
    padding: EdgeInsets.only(top: 32, bottom: 24),
    outerRadius: 44,
    screenRadius: 24,
    bezel: 26,
    ios: false,
    tablet: true,
  );
  static const androidTablet7 = _Device(
    screen: Size(960, 600),
    padding: EdgeInsets.only(top: 32, bottom: 24),
    outerRadius: 40,
    screenRadius: 22,
    bezel: 22,
    ios: false,
    tablet: true,
  );
}

/// Целевые размеры холста. Логический размер = физический / dpr.
class _Canvas {
  const _Canvas(this.name, this.width, this.height, this.dpr, this.device);

  final String name;
  final int width;
  final int height;
  final double dpr;
  final _Device device;
}

const _canvases = [
  // App Store: iPhone 6.9" и iPad 13" (обязательные размеры).
  _Canvas('ios-phone', 1290, 2796, 3, _Device.iphone),
  _Canvas('ios-tablet', 2752, 2064, 2, _Device.ipad),
  // Google Play: телефон 9:16, планшеты 7" и 10".
  _Canvas('play-phone', 1080, 1920, 2.5, _Device.android),
  _Canvas('play-tablet-7', 1920, 1200, 2, _Device.androidTablet7),
  _Canvas('play-tablet-10', 2560, 1600, 2, _Device.androidTablet10),
];

/// Кадры в порядке показа в сторе: (имя, подписи по языку, цвет фона).
/// App Store берёт до 10 кадров, Google Play — до 8: первые восемь и есть
/// набор для Play.
const _frames = <(String, Map<String, (String, String)>, Color)>[
  (
    'official',
    {
      'sr': (
        'Zvanična pitanja',
        'Ista pitanja kao na ispitu: 1559 pitanja iz 13 oblasti',
      ),
      'ru': (
        'Официальные вопросы',
        'Те же вопросы, что на экзамене, с переводом на русский',
      ),
      'en': (
        'Official questions',
        'The same questions as on the real exam: 1559 in 13 topics',
      ),
    },
    Color(0xFFDCE9F7),
  ),
  (
    'simulation',
    {
      'sr': (
        'Simulacija',
        'Ispit kao pravi: 41 pitanje, 45 minuta, isti ekran',
      ),
      'ru': (
        'Симуляция',
        'Экзамен как настоящий: 41 вопрос, 45 минут, тот же экран',
      ),
      'en': (
        'Simulation',
        'A mock exam like the real one: 41 questions in 45 minutes',
      ),
    },
    Color(0xFFDAD7F6),
  ),
  (
    'explanation',
    {
      'sr': ('Objašnjenja', 'Objašnjenje za svako pitanje, uz vezu sa zakonom'),
      'ru': ('Объяснения', 'Разбор каждого вопроса со ссылкой на закон'),
      'en': (
        'Explanations',
        'Every question explained, with a link to the law',
      ),
    },
    Color(0xFFD3EEDF),
  ),
  (
    'askai',
    {
      'sr': (
        'Pitaj AI',
        'Razgovor o svakom pitanju: zašto je odgovor baš takav',
      ),
      'ru': ('Спросить AI', 'Чат по любому вопросу: почему ответ именно такой'),
      'en': ('Ask AI', 'Chat about any question: why the answer is what it is'),
    },
    Color(0xFFE8DCF5),
  ),
  (
    'analysis',
    {
      'sr': (
        'Analiza',
        'Koliko često pitanje pada na ispitu i koje su ključne fraze',
      ),
      'ru': (
        'Анализ',
        'Как часто вопрос попадается на экзамене и ключевые фразы',
      ),
      'en': ('Analysis', 'How often a question comes up, and its key phrases'),
    },
    Color(0xFFFBEFC8),
  ),
  (
    'discussion',
    {
      'sr': ('Diskusija', 'Razgovarajte o pitanju sa drugim kandidatima'),
      'ru': ('Обсуждение', 'Обсуждайте вопросы с другими кандидатами'),
      'en': ('Discussion', 'Talk the question over with other learners'),
    },
    Color(0xFFFBE3D1),
  ),
  (
    'konspekt',
    {
      'sr': ('Konspekti', 'Sažetak gradiva po kategorijama, sa ilustracijama'),
      'ru': (
        'Конспекты',
        'Краткий конспект по каждой категории с иллюстрациями',
      ),
      'en': (
        'Study notes',
        'Concise notes for every category, with illustrations',
      ),
    },
    Color(0xFFE3F0D6),
  ),
  (
    'training',
    {
      'sr': ('Trening', 'Vežbanje po kategorijama uz statistiku napretka'),
      'ru': ('Тренировка', 'Тренировка по категориям со статистикой прогресса'),
      'en': ('Practice', 'Train by category and track your progress'),
    },
    Color(0xFFF6DAE1),
  ),
  (
    'lists',
    {
      'sr': ('Liste pitanja', 'Vaše liste i automatske liste grešaka'),
      'ru': ('Списки вопросов', 'Свои списки и автосписки ошибок'),
      'en': (
        'Question lists',
        'Your own lists plus automatic lists of mistakes',
      ),
    },
    Color(0xFFD6E7EE),
  ),
  (
    'result',
    {
      'sr': ('Rezultat', 'Analiza grešaka posle svake simulacije'),
      'ru': ('Результат', 'Разбор ошибок после каждой симуляции'),
      'en': ('Results', 'Review your mistakes after every mock exam'),
    },
    Color(0xFFDDE4F5),
  ),
];

const _featureGraphicTagline = {
  'sr': 'Vozački ispit: pitanja, simulacija, objašnjenja',
  'ru': 'Экзамен на права в Сербии: вопросы, симуляция, объяснения',
  'en': 'Serbian driving test: questions, mock exams, explanations',
};

/// Вопрос с железничким прелазом — герой кадров «симуляция» и «объяснение».
const _heroQuestionId = 10289;

/// Подкатегория героя: тренировка «Саобраћај на прелазу пута преко пруге».
const _heroSubcategoryId = 146;

/// Полиция и хитна помоћ на раскрсници — кадры «официальные вопросы»,
/// «спросить AI» и «обсуждение».
const _priorityQuestionId = 10354;
const _prioritySubcategoryId = 148;

/// Вопрос со скоростью у пешачког прелаза: высокая вероятность на экзамене и
/// четыре ключевые фразы — кадр «анализ».
const _analysisQuestionId = 9869;

/// Опубликованное объяснение героя (снято с прода 2026-09-11 через
/// comments_cli, чтобы кадр не зависел от сети).
const _heroExplanationSr =
    '**Дужни сте да се зауставите испред браника.**\n\n'
    'Према [члану 101 закона](zakon?chapter=IV&chlan=101&paragraph=1) '
    'заустављање је обавезно када је браник спуштен или је почео да се '
    'спушта. Пролазак поред спуштеног браника, „ако испод њега има довољно '
    'простора”, забрањен је.';
const _heroExplanationRu =
    'Вы обязаны **остановиться перед шлагбаумом** (_браник_).\n\n'
    'По [статье 101 закона](zakon?chapter=IV&chlan=101&paragraph=1) остановка '
    'обязательна, если шлагбаум опущен или начал опускаться. Проезжать в '
    'обход опущенного шлагбаума, «если под ним достаточно места», запрещено.';

/// Переписка с AI о вопросе 10354 на языке витрины.
const _askAiDialogs = {
  'sr': [
    'Zašto prednost ima vozilo 3, a ne policija pod brojem 1?',
    'Na slici su **dva vozila pod pratnjom**: policijsko vozilo (1) i hitna '
        'pomoć (2) imaju uključena plava rotaciona svetla, a vozilo 3 je obično '
        'putničko vozilo.\n\n'
        'Prema članu 106 Zakona, vozila pod pratnjom imaju prvenstvo prolaza u '
        'odnosu na sva druga vozila, **osim** onih koja se kreću raskrsnicom '
        'koju regulišu policajac ili semafor. Između dva vozila pod pratnjom '
        'važe opšta pravila — desno pravilo. Hitna pomoć (2) dolazi policiji (1) '
        'sa desne strane, pa prolazi prva; policija je druga; vozilo 3 čeka oba.',
  ],
  'ru': [
    'Почему приоритет у машины 3, а не у полиции под номером 1?',
    'На фото **два автомобиля с сопровождением**: полицейская машина (1) и '
        'скорая (2) с включёнными синими маячками, а автомобиль 3 — обычная '
        'легковая машина.\n\n'
        'По статье 106 Закона автомобили с сопровождением имеют преимущество '
        'перед всеми остальными, **кроме** случаев, когда перекрёсток '
        'регулируется полицейским или светофором. Между двумя такими '
        'автомобилями действует общее правило — помеха справа. Скорая (2) '
        'подъезжает к полиции (1) справа, поэтому проезжает первой, полиция '
        'второй, а машина 3 пропускает обеих.',
  ],
  'en': [
    'Why does car 3 have priority over the police car marked 1?',
    'The photo shows **two escorted vehicles**: the police car (1) and the '
        'ambulance (2) both have their blue lights on, while vehicle 3 is an '
        'ordinary passenger car.\n\n'
        'Under Article 106 of the Law, escorted vehicles have priority over all '
        'others, **except** at intersections controlled by a police officer or '
        'traffic lights. Between two escorted vehicles the general rules apply, '
        'so the right-hand rule decides. The ambulance (2) approaches the police '
        'car (1) from the right, so it goes first, the police car second, and '
        'vehicle 3 waits for both.',
  ],
};

/// Обсуждение вопроса 10354: три сообщения кандидатов.
const _discussionMessages = [
  (
    'Milica',
    'Ja sam mislila da policija uvek ima prednost, ali ovde i hitna pomoć '
        'ima rotaciju. Znači važi desno pravilo između njih?',
  ),
  (
    'Nikola',
    'Tako je. Oba su vozila pod pratnjom, pa se između njih primenjuju opšta '
        'pravila. Hitna dolazi policiji zdesna i prolazi prva.',
  ),
  ('Jovana', 'Hvala, sad mi je jasno. Pala sam na ovom pitanju dva puta.'),
];

// ---------------------------------------------------------------------------
// Заглушки
// ---------------------------------------------------------------------------

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data, {this.subStats = const {}});

  final QuestionsData _data;
  final Map<String, SubStats> subStats;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data, subStats: subStats);
}

/// Фича-флаги премиум-пользователя: русский контент по языку витрины; то, что
/// кадру не нужно, выключено локальными тумблерами (как может сделать и
/// настоящий пользователь на экране «Функции»), чтобы кадр не зависел от сети.
class _Flags extends FeatureFlagsRepository {
  _Flags({required this.russian, this.on = const {}})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russian;

  /// Сетевые вкладки вопроса, включённые в этом кадре.
  final Set<AppFeature> on;

  static const _optional = {
    AppFeature.publicQuestionComments,
    AppFeature.questionAnalysis,
    AppFeature.askAi,
  };

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in _optional)
        if (!on.contains(f)) f.key: false,
      AppFeature.questionSearch.key: false,
      AppFeature.groups.key: false,
      AppFeature.russianContent.key: russian,
    },
    grants: {
      'question_comments',
      'category_summaries',
      'question_analysis',
      'ask_ai',
      if (russian) 'russian_content',
    },
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

class _AuthedAuthBloc extends AuthBloc {
  _AuthedAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(
    status: AuthStatus.authenticated,
    viewer: Viewer(id: 'demo', email: 'marko@example.com', permissions: []),
  );
}

/// Сервер обсуждения: отвечает на запросы чата вопроса заранее заданной
/// перепиской. Клиент собран без батчинга, поэтому в документе ровно одна
/// операция.
class _ChatApi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final raw = options.data;
    final body = raw is String
        ? json.decode(raw) as Map<String, dynamic>
        : (raw as Map).cast<String, dynamic>();
    final query = body['query'].toString();
    final Map<String, dynamic> data;
    if (query.contains('questionChatMessageCount')) {
      data = {'questionChatMessageCount': _discussionMessages.length};
    } else if (query.contains('chatFor')) {
      data = {'chatFor': _chat};
    } else if (query.contains('chatMessages')) {
      data = {
        'chatMessages': {
          'totalCount': _discussionMessages.length,
          'hasNextPage': false,
          'nodes': [
            for (var i = 0; i < _discussionMessages.length; i++)
              {
                'id': 'm$i',
                'authorId': 'u$i',
                'authorDisplayName': _discussionMessages[i].$1,
                'fromStaff': false,
                'body': _discussionMessages[i].$2,
                'createdAt': DateTime.utc(
                  2026,
                  9,
                  10,
                  18,
                  4,
                ).add(Duration(minutes: 7 * i)).toIso8601String(),
              },
          ],
        },
      };
    } else if (query.contains('myProfile')) {
      data = {
        'myProfile': const {'displayName': 'Marko', 'commentBan': false},
      };
    } else if (query.contains('me')) {
      data = {
        'me': const {
          'id': 'demo',
          'email': 'marko@example.com',
          'permissions': [],
        },
      };
    } else {
      data = const {};
    }
    return ResponseBody.fromString(
      json.encode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static const _chat = {
    'id': 'c1',
    'entityType': 'QUESTION',
    'entityId': '$_priorityQuestionId',
    'entityName': '',
    'isGroup': true,
    'userId': '',
    'userDisplayName': '',
    'createdAt': '2026-09-10T18:00:00Z',
    'unreadCount': 0,
    'messagesCount': 3,
  };

  @override
  void close({bool force = false}) {}
}

/// Сокет подписки, который никуда не соединяется.
class _DeadSocket implements GraphqlSocket {
  final _controller = StreamController<dynamic>();

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Конспекты из авторских исходников `konspekt_content/`, без сети.
class _KonspektRepository extends KonspektRepository {
  _KonspektRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<Set<String>> availableCategories() async => {
    for (final f in Directory('konspekt_content').listSync())
      if (f.path.endsWith('.json'))
        f.path.split('/').last.replaceAll('.json', ''),
  };

  @override
  Future<Konspekt?> load(String categoryId) async {
    final file = File('konspekt_content/$categoryId.json');
    if (!file.existsSync()) return null;
    return Konspekt.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }
}

class _CommentRepository extends CommentRepository {
  _CommentRepository(this.russian)
    : super(GraphqlClient(TokenStorage()), _Flags(russian: russian));

  final bool russian;

  @override
  Future<QuestionCommentDetails?> fetchComment(
    int questionId, {
    String? categoryId,
  }) async {
    if (questionId != _heroQuestionId) return null;
    return QuestionCommentDetails(
      status: 'READY',
      text: russian ? _heroExplanationRu : _heroExplanationSr,
    );
  }
}

class _AskAiRepository extends AskAiChatRepository {
  _AskAiRepository(this.locale)
    : super(
        GraphqlClient(TokenStorage()),
        GraphqlSubscriptionClient(
          GraphqlClient(TokenStorage()),
          TokenStorage(),
        ),
      );

  final String locale;

  @override
  Future<List<AskAiChatMessage>> history(
    AskAiChatScope scope,
    String scopeId,
  ) async {
    final dialog = _askAiDialogs[locale]!;
    final at = DateTime(2026, 9, 10, 18, 40);
    return [
      AskAiChatMessage(
        id: '1',
        role: AskAiChatRole.user,
        content: dialog[0],
        createdAt: at,
      ),
      AskAiChatMessage(
        id: '2',
        role: AskAiChatRole.assistant,
        content: dialog[1],
        createdAt: at.add(const Duration(seconds: 9)),
      ),
    ];
  }

  @override
  Stream<AskAiStreamUpdate> replyStream(AskAiChatScope scope, String scopeId) =>
      const Stream.empty();

  @override
  Future<AskAiQuota> quota() async =>
      const AskAiQuota(limit: 40, used: 3, remaining: 37);
}

/// Сложность вопроса «по толпе» — единственная цифра анализа с бэкенда.
class _DifficultyRepository extends QuestionDifficultyRepository {
  _DifficultyRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<QuestionDifficulty?> forQuestion(int questionId) async =>
      const QuestionDifficulty(
        attempts: 1284,
        wrongAttempts: 402,
        learners: 517,
        wrongRate: 0.313,
        difficulty: 0.31,
        baseline: 0.18,
      );
}

/// Списки вопросов на главной: три своих и автосписки ошибок.
class _ListsBloc extends QuestionListsBloc {
  _ListsBloc(
    super.lists,
    super.shares,
    super.auth,
    super.analytics,
    super.difficulty,
    super.network, {
    required this.data,
    required this.russian,
  });

  final QuestionsData data;
  final bool russian;

  @override
  void add(QuestionListsEvent event) {}

  List<int> _of(int subcategoryId, int count) => [
    for (final q in data.questions)
      if (q.subcategoryId == subcategoryId && q.hasImage) q.id,
  ].take(count).toList();

  @override
  QuestionListsState get state => QuestionListsState(
    customLists: [
      QuestionList(
        id: 'l1',
        name: russian ? 'Знаки' : 'Znakovi',
        color: 0xFFFDD835,
        questionIds: _of(159, 14),
      ),
      QuestionList(
        id: 'l2',
        name: russian ? 'Перекрёстки' : 'Raskrsnice',
        color: 0xFF3949AB,
        questionIds: _of(_prioritySubcategoryId, 9),
      ),
      QuestionList(
        id: 'l3',
        name: russian ? 'Повторить перед экзаменом' : 'Ponoviti pred ispit',
        color: 0xFF43A047,
        questionIds: _of(_heroSubcategoryId, 6),
      ),
    ],
    recentMistakes: _of(_prioritySubcategoryId, 5),
    lastExamMistakes: _of(_heroSubcategoryId, 2),
    chronicMistakes: _of(146, 3),
    personalWeakSpots: _of(148, 4),
  );
}

/// Экзамен, только что завершённый: две ошибки, вопросы с фотографиями.
class _ResultPracticeBloc extends PracticeBloc {
  _ResultPracticeBloc(super.data, super.params, this._ticket);

  final List<int> _ticket;

  @override
  PracticeState get state {
    final wrong = [
      for (final id in _ticket.skip(2))
        if (data.questions.firstWhere((q) => q.id == id).hasImage) id,
    ].take(2).toList();
    var possible = 0;
    var points = 0;
    for (final id in _ticket) {
      final q = data.questions.firstWhere((q) => q.id == id);
      possible += q.points;
      if (!wrong.contains(id)) points += q.points;
    }
    return PracticeState(
      questions: _ticket,
      finalizeTest: true,
      attemptSaved: true,
      possibleScore: possible,
      finalPoints: points,
      finalWrongQuestions: wrong,
      elapsedSeconds: 27 * 60 + 14,
      attemptUuid: 'store-screenshot',
    );
  }
}

// ---------------------------------------------------------------------------
// Данные и шрифты
// ---------------------------------------------------------------------------

/// Реальные вопросы из ассетов, как их собирает AllQuestionsBloc (парсер там
/// приватный). Билет один: тот из practice.json, где есть нужный вопрос, с
/// этим вопросом на второй позиции.
Future<QuestionsData> _loadData() async {
  final categories =
      (jsonDecode(await rootBundle.loadString('assets/categories.json'))
              as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
  final questions =
      (jsonDecode(await rootBundle.loadString('assets/allQuestions.json'))
              as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .map((e) => e.copyWith(id: e.imageId))
          .toList();
  final practice =
      (jsonDecode(await rootBundle.loadString('assets/practice.json')) as List)
          .map((e) => (e as List).cast<int>().toList())
          .toList();
  final translations =
      (jsonDecode(await rootBundle.loadString('assets/allQuestions_ru.json'))
              as List)
          .map((e) => Translation.fromJson(e as Map<String, dynamic>))
          .toList();
  final translationsById = {for (final t in translations) t.imageId: t};
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final t = translationsById[q.id];
    if (t == null || t.choices.length != q.choices.length) continue;
    questions[i] = q.copyWith(
      translation: t.text,
      choices: [
        for (var j = 0; j < q.choices.length; j++)
          q.choices[j].copyWith(translationRu: t.choices[j].text),
      ],
    );
  }

  final ticket = practice.firstWhere((t) => t.contains(_heroQuestionId));
  final ordered = [...ticket]..remove(_heroQuestionId);
  ordered.insert(1, _heroQuestionId);
  return QuestionsData(
    categories: categories,
    questions: questions,
    practice: [ordered],
  );
}

/// Правдоподобная статистика тренировок: три подхода к каждой подкатегории
/// категории «Саобраћајна сигнализација», от 70 % к почти полному.
Map<String, SubStats> _trainingStats(QuestionsData data) {
  final counts = <int, int>{};
  for (final q in data.questions) {
    counts[q.subcategoryId] = (counts[q.subcategoryId] ?? 0) + 1;
  }
  final signs = data.categories.firstWhere((c) => c.id == '32');
  return {
    for (final sub in signs.subcategories)
      if (counts[sub.id] case final n? when n > 0)
        '${sub.id}': SubStats(
          answers: [(n * 0.7).round(), (n * 0.85).round(), (n * 0.96).round()],
          allAnswers: n,
        ),
  };
}

Future<void> _loadFonts() async {
  // Шрифт иконок Material лежит в кэше Flutter SDK; без него иконки —
  // квадратики. Исполняемый файл теста — dart из bin/cache/dart-sdk внутри
  // SDK, идём вверх до корня Flutter.
  var dir = File(Platform.resolvedExecutable).parent;
  const rel = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  var icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/$rel');
  while (!icons.existsSync() && dir.parent.path != dir.path) {
    dir = dir.parent;
    icons = File('${dir.path}/$rel');
  }
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  final weights = [
    for (final w in ['400', '500', '600', '700'])
      File('assets/fonts/Inter-$w.ttf').readAsBytesSync(),
  ];
  for (final family in ['Inter', 'Roboto', 'FlutterTest', 'Ahem']) {
    final loader = FontLoader(family);
    for (final data in weights) {
      loader.addFont(Future.value(ByteData.sublistView(data)));
    }
    await loader.load();
  }
}

// ---------------------------------------------------------------------------
// Корпус устройства и кадр
// ---------------------------------------------------------------------------

/// Корпус устройства. iPhone: титановая кромка, «островок», полоска Home.
/// iPad: ровная рамка, без выреза. Android: тёмный корпус, отверстие камеры,
/// жестовая полоска. Экран приложения живёт в логических размерах устройства
/// с системными отступами, как на настоящем.
class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({required this.child, required this.device});

  final Widget child;
  final _Device device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    const onScreen = Color(0xFF111111);
    final statusFont = d.tablet ? 15.0 : (d.ios ? 17.0 : 15.0);
    final statusTop = d.ios ? (d.tablet ? 6.0 : 18.0) : 12.0;
    final sideInset = d.ios ? (d.tablet ? 28.0 : 48.0) : 26.0;

    return Container(
      width: d.outerWidth,
      height: d.outerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(d.outerRadius),
        gradient: d.ios
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD9D9DC),
                  Color(0xFF8E8E93),
                  Color(0xFFD1D1D4),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A3A3E), Color(0xFF1C1C1F)],
              ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_Device.rim),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0C),
          borderRadius: BorderRadius.circular(d.outerRadius - _Device.rim),
        ),
        padding: EdgeInsets.all(d.bezel),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(d.screenRadius),
          child: Stack(
            children: [
              SizedBox(
                width: d.screen.width,
                height: d.screen.height,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: d.screen,
                    devicePixelRatio: d.ios ? 3 : 2.75,
                    padding: d.padding,
                    viewPadding: d.padding,
                  ),
                  child: child,
                ),
              ),
              // Статус-бар.
              Positioned(
                top: statusTop,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(width: sideInset),
                    Text(
                      '9:41',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: statusFont,
                        fontWeight: d.ios ? FontWeight.w600 : FontWeight.w500,
                        color: onScreen,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.wifi, size: 17, color: onScreen),
                    const SizedBox(width: 6),
                    if (!d.tablet) ...[
                      const Icon(
                        Icons.signal_cellular_4_bar,
                        size: 16,
                        color: onScreen,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Transform.rotate(
                      angle: d.ios ? 1.5708 : 0,
                      child: const Icon(
                        Icons.battery_full,
                        size: 19,
                        color: onScreen,
                      ),
                    ),
                    SizedBox(width: sideInset - 8),
                  ],
                ),
              ),
              if (d.ios && !d.tablet)
                // Dynamic Island.
                Positioned(
                  top: 11,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 126,
                      height: 37,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0B0C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                )
              else if (!d.ios)
                // Отверстие фронтальной камеры.
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B0B0C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Полоска жестовой навигации.
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: d.tablet ? 240 : (d.ios ? 140 : 110),
                    height: d.ios ? 5 : 4,
                    decoration: BoxDecoration(
                      color: onScreen.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Целый кадр: фон, подпись и устройство. Телефон занимает ~72 % ширины,
/// планшет — ~84 %; при нехватке высоты устройство подрезается снизу.
class _StoreFrame extends StatelessWidget {
  const _StoreFrame({
    required this.title,
    required this.subtitle,
    required this.background,
    required this.device,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color background;
  final _Device device;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final t = device.tablet;
        final scale = w * (t ? 0.78 : 0.72) / device.outerWidth;
        return Container(
          color: background,
          child: Column(
            children: [
              SizedBox(height: w * (t ? 0.04 : 0.085)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: w * (t ? 0.046 : 0.082),
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -w * 0.002,
                    color: const Color(0xFF1B1B1F),
                  ),
                ),
              ),
              SizedBox(height: w * (t ? 0.016 : 0.03)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.1),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: w * (t ? 0.026 : 0.046),
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF2E2E33),
                  ),
                ),
              ),
              SizedBox(height: w * (t ? 0.032 : 0.075)),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: _DeviceFrame(device: device, child: child),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Графика для витрины Google Play (1024×500): иконка, имя, слоган.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDAD7F6), Color(0xFFD3EEDF)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.file(
              File(
                'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
                'AppIcon~ios-marketing.png',
              ),
              width: 140,
              height: 140,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saobraćaj',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 46,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: Color(0xFF1B1B1F),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tagline,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 19,
                    height: 1.3,
                    color: Color(0xFF2E2E33),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Приложение внутри устройства
// ---------------------------------------------------------------------------

Widget _app({
  required Locale locale,
  required Widget home,
  required List<BlocProvider> providers,
}) {
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: locale,
    saveLocale: false,
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) {
        Intl.defaultLocale = context.locale.toLanguageTag();
        final app = MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: buildAppTheme(
            ColorScheme.fromSeed(seedColor: kDefaultSeedColor),
          ),
          home: home,
        );
        // MultiBlocProvider не терпит пустого списка.
        return providers.isEmpty
            ? app
            : MultiBlocProvider(providers: providers, child: app);
      },
    ),
  );
}

/// Общие для кадра клиенты и блоки: авторизованный пользователь, флаги,
/// списки вопросов.
class _Session {
  _Session({required this.russian, required this.locale}) {
    storage = TokenStorage();
    client = _FakeClient(storage);
    auth = _AuthedAuthBloc(
      AuthRepository(client, storage, AnalyticsService()),
      GraphqlSubscriptionClient(client, storage),
    );
  }

  final bool russian;
  final String locale;
  late final TokenStorage storage;
  late final _FakeClient client;
  late final AuthBloc auth;

  BlocProvider<AuthBloc> get authProvider =>
      BlocProvider<AuthBloc>.value(value: auth);

  BlocProvider<FeatureFlagsBloc> flags({Set<AppFeature> on = const {}}) =>
      BlocProvider<FeatureFlagsBloc>(
        create: (_) => FeatureFlagsBloc(_Flags(russian: russian, on: on)),
      );

  BlocProvider<QuestionListsBloc> get lists => BlocProvider<QuestionListsBloc>(
    create: (_) => QuestionListsBloc(
      QuestionListsRepository(client),
      SharedListsRepository(client),
      auth,
      AnalyticsService(),
      QuestionDifficultyRepository(client),
      NetworkStatus(),
    ),
  );

  BlocProvider<QuestionListsBloc> demoLists(QuestionsData data) =>
      BlocProvider<QuestionListsBloc>(
        create: (_) => _ListsBloc(
          QuestionListsRepository(client),
          SharedListsRepository(client),
          auth,
          AnalyticsService(),
          QuestionDifficultyRepository(client),
          NetworkStatus(),
          data: data,
          russian: russian,
        ),
      );

  /// Экран вопроса в тренировке по подкатегории [subcategoryId], где [first]
  /// открыт первым.
  Widget quest(
    QuestionsData data, {
    required int first,
    required int subcategoryId,
    Set<AppFeature> on = const {},
  }) {
    final ids = [
      first,
      for (final q in data.questions)
        if (q.subcategoryId == subcategoryId && q.id != first) q.id,
    ];
    return MultiBlocProvider(
      providers: [
        BlocProvider<AllQuestionsBloc>(
          create: (_) => _StubAllQuestionsBloc(data),
        ),
        flags(on: on),
        authProvider,
        lists,
      ],
      child: Quest(
        questions: ids,
        options: const StartTestState(random: false, randomOptionsOrder: false),
      ),
    );
  }

  /// Регистрирует в getIt всё, что нужно вкладкам под вопросом.
  void registerQuestDi(QuestionAnalyticsRepository analytics) {
    getIt.registerLazySingleton<TokenStorage>(() => storage);
    getIt.registerLazySingleton<QuizPreferencesRepository>(
      QuizPreferencesRepository.new,
    );
    getIt.registerFactoryParam<CommentBloc, int, String?>(
      (questionId, categoryId) => CommentBloc(
        _CommentRepository(russian),
        NetworkStatus(),
        questionId,
        categoryId,
      ),
    );
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, int?>(
      (initial, questionId) =>
          QuestionFeaturesBloc(getIt(), initial, questionId),
    );
    getIt.registerFactoryParam<QuestionKonspektBloc, int, String>(
      (questionId, categoryId) => QuestionKonspektBloc(
        _KonspektRepository(),
        NetworkStatus(),
        questionId,
        categoryId,
      ),
    );

    // Анализ: офлайн-аналитика из ассета плюс сложность «по толпе».
    getIt.registerLazySingleton<QuestionAnalyticsRepository>(() => analytics);
    getIt.registerLazySingleton<QuestionDifficultyRepository>(
      _DifficultyRepository.new,
    );
    getIt.registerFactoryParam<QuestionAnalyticsBloc, int, dynamic>(
      (questionId, _) =>
          QuestionAnalyticsBloc(getIt(), getIt(), auth, questionId),
    );
    getIt.registerFactoryParam<QuestionCuesBloc, int, dynamic>(
      (questionId, _) => QuestionCuesBloc(getIt(), questionId),
    );

    // Спросить AI.
    getIt.registerLazySingleton<AskAiChatRepository>(
      () => _AskAiRepository(locale),
    );
    getIt.registerFactoryParam<AskAiChatBloc, AskAiChatScope, String>(
      (scope, scopeId) => AskAiChatBloc(getIt(), scope, scopeId),
    );

    // Обсуждение: настоящий чат поверх фейкового сервера.
    final chatClient = GraphqlClient(
      storage,
      dio: Dio()..httpClientAdapter = _ChatApi(),
      batchQueries: false,
    );
    final chatRepository = ChatRepository(
      chatClient,
      GraphqlSubscriptionClient(
        chatClient,
        storage,
        connector: (_) async => _DeadSocket(),
        endpoint: Uri.parse('ws://localhost:8080/ws'),
        retryDelay: (_) => Duration.zero,
      ),
    );
    getIt.registerFactoryParam<QuestionChatCountBloc, int, dynamic>(
      (questionId, _) => QuestionChatCountBloc(chatRepository, questionId),
    );
    getIt.registerFactoryParam<ChatBloc, ChatTarget?, dynamic>(
      (target, _) => ChatBloc(
        chatRepository,
        const NotificationPermissions(),
        AuthRepository(chatClient, storage, AnalyticsService()),
        SharedListsRepository(chatClient),
        ProfileRepository(chatClient),
        target,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Рендер
// ---------------------------------------------------------------------------

/// Таймеры и декодирование картинок не дают `pumpAndSettle` сойтись; ждём
/// явными кадрами, картинки и сеть — в реальной зоне через runAsync.
Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, double pixelRatio, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  final image = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: pixelRatio);
    return img.toByteData(format: ui.ImageByteFormat.png);
  });
  File(path).writeAsBytesSync(image!.buffer.asUint8List(), flush: true);
  // ignore: avoid_print
  print('SHOT $path');
}

void _setCanvas(WidgetTester tester, int width, int height, double dpr) {
  tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Подпись кнопки «Прикажи одговор» на трёх языках интерфейса.
final _revealButton = find.byWidgetPredicate(
  (w) =>
      w is Text &&
      const {
        'Прикажи одговор',
        'Показать ответ',
        'Show answer',
      }.contains(w.data),
);

/// Вертикальный Scrollable с наибольшим запасом прокрутки — основной список
/// экрана (а не полоса прогресса или листалка вкладок).
({Finder finder, ScrollPosition position})? _mainScrollable(
  WidgetTester tester,
) {
  ({Finder finder, ScrollPosition position})? best;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final position = state.position;
    if (position.axis != Axis.vertical) continue;
    if (best == null ||
        position.maxScrollExtent > best.position.maxScrollExtent) {
      best = (finder: find.byWidget(element.widget), position: position);
    }
  }
  return best;
}

/// Прокручивает основной список так, чтобы [target] оказался на [offset]
/// логических пикселей ниже верха экрана устройства. Молча пропускает
/// раскладки, где прокручивать нечего (широкие экраны).
Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  required _Device device,
  double offset = 120,
}) async {
  final main = _mainScrollable(tester);
  if (main == null || main.position.maxScrollExtent <= 0) return;
  try {
    // Цель может быть ещё не построена (ленивый список) — scrollUntilVisible
    // докрутит до неё сам.
    await tester.scrollUntilVisible(target, 200, scrollable: main.finder);
  } on Object {
    return;
  }
  if (target.evaluate().isEmpty) return;
  await tester.pump();
  final frame = tester.getRect(find.byType(_DeviceFrame));
  final scale = frame.width / device.outerWidth;
  final rect = tester.getRect(target.first);
  final delta = (rect.top - frame.top) / scale - offset;
  final position = main.position;
  position.jumpTo((position.pixels + delta).clamp(0, position.maxScrollExtent));
  await tester.pump();
}

/// Выбирает верный ответ и раскрывает его, чтобы появились вкладки.
Future<void> _reveal(WidgetTester tester, Question question) async {
  final correct = question.choices.firstWhere((c) => c.isCorrect);
  final card = find.descendant(
    of: find.byType(AnswerOptionCard),
    matching: find.textContaining(correct.text.trim(), findRichText: true),
  );
  if (card.evaluate().isNotEmpty) {
    await tester.ensureVisible(card.first);
    await tester.tap(card.first, warnIfMissed: false);
    await _settle(tester, rounds: 2);
  }
  // На невысоком планшете кнопка стоит ниже видимой части левой колонки.
  await tester.ensureVisible(_revealButton);
  await tester.tap(_revealButton, warnIfMissed: false);
  await _settle(tester);
}

void main() {
  late QuestionsData data;
  // Аналитика разбирается в фоновом изоляте: будущее, заведённое в одной
  // FakeAsync-зоне, в следующем тесте не завершается (второй кадр «анализ» в
  // процессе вис на спиннере). Прогреваем один экземпляр заранее, в реальной
  // зоне, и отдаём его всем кадрам.
  final analytics = QuestionAnalyticsRepository();

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
    data = await _loadData();
    await analytics.summary();
    for (final canvas in _canvases) {
      Directory(
        'build/store_screenshots/${canvas.name}',
      ).createSync(recursive: true);
    }
  });

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // Ответ пишется в Drift, а Drift спрашивает у path_provider каталог.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_shots').path,
        );
  });

  tearDown(getIt.reset);

  final locales = (Platform.environment['LOCALES'] ?? 'sr,ru,en').split(',');
  final canvasFilter = Platform.environment['CANVASES']?.split(',');
  final frameFilter = Platform.environment['FRAMES']?.split(',');

  Question question(int id) => data.questions.firstWhere((q) => q.id == id);

  for (final locale in locales) {
    final russian = locale == 'ru';
    for (final canvas in _canvases) {
      if (canvasFilter != null && !canvasFilter.contains(canvas.name)) continue;
      final device = canvas.device;
      for (var i = 0; i < _frames.length; i++) {
        final (frame, captions, background) = _frames[i];
        if (frameFilter != null && !frameFilter.contains(frame)) continue;
        final index = (i + 1).toString().padLeft(2, '0');
        final name = '$index-$frame-$locale';

        testWidgets('${canvas.name}/$name', (tester) async {
          _setCanvas(tester, canvas.width, canvas.height, canvas.dpr);
          final session = _Session(russian: russian, locale: locale);
          final (title, subtitle) = captions[locale]!;

          Future<void> frameWith(
            Widget home, {
            List<BlocProvider> providers = const [],
          }) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: RepaintBoundary(
                  key: const ValueKey('shot'),
                  child: _StoreFrame(
                    title: title,
                    subtitle: subtitle,
                    background: background,
                    device: device,
                    child: _app(
                      locale: Locale(locale),
                      providers: providers,
                      home: home,
                    ),
                  ),
                ),
              ),
            );
            await _settle(tester);
          }

          /// Экран вопроса с открытой вкладкой [tab] под раскрытым ответом.
          Future<void> questWithTab(
            int questionId,
            AppFeature tab, {
            double offset = 130,
          }) async {
            session.registerQuestDi(analytics);
            await tester.runAsync(
              () => getIt<QuizPreferencesRepository>().setQuestionTab(tab),
            );
            await frameWith(
              session.quest(
                data,
                first: questionId,
                subcategoryId: question(questionId).subcategoryId,
                on: {tab},
              ),
            );
            await _reveal(tester, question(questionId));
            // Содержимое вкладки грузится в реальной зоне (анализ — в фоновом
            // изоляте): ждём, пока пропадёт спиннер.
            for (var i = 0; i < 60; i++) {
              await _settle(tester, rounds: 1);
              if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
                break;
              }
            }
            await _settle(tester, rounds: 4);
            if (device.screen.width < 840) {
              await _scrollTo(
                tester,
                find.byType(QuestionFeaturesTabs),
                device: device,
                offset: offset,
              );
            } else {
              // На широком экране вкладки живут в правой колонке и видны
              // сразу; левую колонку, сдвинутую ради кнопки, возвращаем.
              _mainScrollable(tester)?.position.jumpTo(0);
              await tester.pump();
            }
            await _settle(tester, rounds: 4);
          }

          switch (frame) {
            case 'official':
              session.registerQuestDi(analytics);
              await frameWith(
                session.quest(
                  data,
                  first: _priorityQuestionId,
                  subcategoryId: _prioritySubcategoryId,
                ),
              );
              if (russian) {
                // TranslationsBloc живёт внутри Quest — читаем из-под него.
                tester
                    .element(find.byType(QuestionContent).first)
                    .read<TranslationsBloc>()
                    .add(ToggleShowTranslation());
                await _settle(tester);
              }

            case 'simulation':
              await frameWith(
                Practice(
                  params: PracticeParams(
                    showRightAnswers: false,
                    buttonsLikeInExam: true,
                  ),
                ),
                providers: [
                  BlocProvider<AllQuestionsBloc>(
                    create: (_) => _StubAllQuestionsBloc(data),
                  ),
                  session.flags(),
                ],
              );
              // Ко второму вопросу — тому, что с переездом, — и отмечаем ответ.
              await tester.tap(
                find.textContaining('Следеће', findRichText: true).first,
              );
              await _settle(tester);
              final tiles = tester.widgetList<RadioListTile<Choice>>(
                find.byType(RadioListTile<Choice>),
              );
              final correct = tiles.where((t) => t.value.isCorrect).firstOrNull;
              if (correct != null) {
                await tester.tap(find.byWidget(correct), warnIfMissed: false);
                await _settle(tester, rounds: 3);
              }
              // Пусть таймер покажет, что экзамен идёт.
              await tester.pump(const Duration(seconds: 12));

            case 'explanation':
              await questWithTab(_heroQuestionId, AppFeature.questionComments);

            case 'askai':
              await questWithTab(
                _priorityQuestionId,
                AppFeature.askAi,
                offset: 250,
              );

            case 'analysis':
              await questWithTab(
                _analysisQuestionId,
                AppFeature.questionAnalysis,
              );

            case 'discussion':
              await questWithTab(
                _priorityQuestionId,
                AppFeature.publicQuestionComments,
                offset: 250,
              );

            case 'training':
              getIt.registerFactory<KonspektCatalogBloc>(
                () => KonspektCatalogBloc(_KonspektRepository()),
              );
              await frameWith(
                const QuestionsPage(),
                providers: [
                  BlocProvider<AllQuestionsBloc>(
                    create: (_) => _StubAllQuestionsBloc(
                      data,
                      subStats: _trainingStats(data),
                    ),
                  ),
                  session.flags(),
                  session.authProvider,
                ],
              );
              await _scrollTo(
                tester,
                find.text('Саобраћајна сигнализација'),
                device: device,
                offset: 150,
              );
              await _settle(tester, rounds: 4);

            case 'konspekt':
              getIt.registerLazySingleton<KonspektRepository>(
                _KonspektRepository.new,
              );
              getIt.registerFactoryParam<KonspektBloc, String, String?>(
                (categoryId, section) =>
                    KonspektBloc(getIt(), NetworkStatus(), categoryId, section),
              );
              await frameWith(
                const KonspektPage(
                  categoryId: '32',
                  section: 'znakovi-opasnosti-put',
                ),
                providers: [session.flags()],
              );
              await _settle(tester, rounds: 12);

            case 'lists':
              // На телефоне главная показывает списки узкой каруселью, поэтому
              // там открыт сам список; на планшете — главная с сеткой своих
              // списков и автосписков.
              await frameWith(
                device.tablet
                    ? const HomeContentPage()
                    : const QuestionListPage(listId: 'l2'),
                providers: [
                  BlocProvider<AllQuestionsBloc>(
                    create: (_) => _StubAllQuestionsBloc(data),
                  ),
                  BlocProvider<NetworkStatusBloc>(
                    create: (_) => NetworkStatusBloc(NetworkStatus()),
                  ),
                  session.flags(),
                  session.authProvider,
                  session.demoLists(data),
                ],
              );
              await _settle(tester, rounds: 4);

            case 'result':
              await frameWith(
                BlocProvider<PracticeBloc>(
                  create: (_) => _ResultPracticeBloc(
                    data,
                    PracticeParams(
                      showRightAnswers: false,
                      buttonsLikeInExam: false,
                    ),
                    data.practice.first,
                  ),
                  child: const FinalizePracticeWidget(),
                ),
                providers: [
                  BlocProvider<AllQuestionsBloc>(
                    create: (_) => _StubAllQuestionsBloc(data),
                  ),
                  session.flags(),
                  session.authProvider,
                  session.lists,
                ],
              );
              // Кольцо результата доигрывает за секунду, а конфетти с малой
              // гравитацией висят в воздухе очень долго — ждём, пока улетят.
              await tester.pump(const Duration(seconds: 90));
              await _settle(tester, rounds: 2);
          }

          await _shoot(
            tester,
            canvas.dpr,
            'build/store_screenshots/${canvas.name}/$name.png',
          );
        });
      }
    }

    if (canvasFilter == null || canvasFilter.contains('play-phone')) {
      testWidgets('play-feature-graphic-$locale', (tester) async {
        if (frameFilter != null && !frameFilter.contains('feature')) return;
        _setCanvas(tester, 1024, 500, 2);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('shot'),
              child: _FeatureGraphic(tagline: _featureGraphicTagline[locale]!),
            ),
          ),
        );
        await _settle(tester, rounds: 6);
        await _shoot(
          tester,
          2,
          'build/store_screenshots/play-feature-graphic-$locale.png',
        );
      });
    }
  }
}
