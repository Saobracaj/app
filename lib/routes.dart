import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/confirm_code_page.dart';
import 'package:saobracaj/auth/presentation/login_page.dart';
import 'package:saobracaj/auth/presentation/profile_page.dart';
import 'package:saobracaj/auth/presentation/register_page.dart';
import 'package:saobracaj/auth/presentation/reset_password_page.dart';
import 'package:saobracaj/feature_flags/presentation/feature_flags_page.dart';
import 'package:saobracaj/theme/presentation/appearance_page.dart';
import 'package:saobracaj/notifications/presentation/notifications_page.dart';
import 'package:saobracaj/profile/presentation/display_name_page.dart';
import 'package:saobracaj/public_comments/presentation/moderation_page.dart';
import 'package:saobracaj/groups/presentation/group_feed_page.dart';
import 'package:saobracaj/groups/presentation/invite_page.dart';
import 'package:saobracaj/groups/presentation/group_page.dart';
import 'package:saobracaj/home/home_content_page.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/question_lists/presentation/question_list_page.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/statistics/statistics_page.dart';
import 'package:saobracaj/support_chat/presentation/support_chat_page.dart';
import 'package:saobracaj/support_chat/presentation/support_threads_page.dart';
import 'package:saobracaj/test/about/about_page.dart';
import 'package:saobracaj/test/about/privacy_policy.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/practice_page.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/quest/comment/editor/presentation/comment_editor_page.dart';
import 'package:saobracaj/core/presentation/not_found_page.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/start_test.dart';
import 'package:saobracaj/zakon/zakon.dart';

/// The screens a question can be opened on: every one of them hosts the same
/// set of child screens (law, konspekt, the admin draft editor), because the
/// question screen's own links have to open *on top of it* — Routemaster builds
/// the page stack from the URL, so "on top of" has to exist as a path.
const _questionHosts = [
  '/quest',
  '/quest/q',
  '/statistics/q',
  '/lists/:id/q',
  '/groups/:id/feed/q',
  '/questPractice/q',
  '/question/:id',
  '/konspekt/question/:id',
];

final routes = RouteMap(
  // A mistyped or outdated address gets a designed screen with a way home
  // instead of routemaster's bare default one.
  onUnknownRoute: (path) => MaterialPage(child: NotFoundPage(path: path)),
  routes: {
    // «История» ('/statistics') временно скрыта из нижней навигации; сам
    // маршрут ниже остаётся рабочим для прямых ссылок.
    '/': (_) => IndexedPage(child: HomePage(), paths: ['/home', '/questions', '/practice', '/settings']),
    '/home': (_) => MaterialPage(child: HomeContentPage()),
    '/questions': (_) => MaterialPage(child: QuestionsPage()),
    '/statistics': (_) => MaterialPage(child: StatisticsPage()),
    '/practice': (_) => MaterialPage(child: PracticePage()),
    '/start': (data) {
      final ids = _questionIdsParam(data.queryParameters['q']);
      if (ids.isEmpty) return const Redirect('/home');
      return MaterialPage(
        child: StartTest(
          questionIds: ids,
          subcategory: data.queryParameters['subcategory'],
        ),
      );
    },
    '/quest': questPage,
    // Deep link to a single question's discussion:
    // saobracaj://question/{id}?comments=1&thread={topCommentId}
    '/question/:id': questCommentsPage,
    '/question/:id/zakon': zakonPage,
    '/quest/zakon': zakonPage,
    '/quest/q': questPage,
    '/quest/q/zakon': zakonPage,
    '/statistics/q': questPage,
    '/statistics/q/zakon': zakonPage,
    // A single question list (automatic or custom) and the questions opened from it.
    '/lists/:id': (data) => MaterialPage(
      child: QuestionListPage(
        listId: Uri.decodeComponent(data.pathParameters['id'] ?? ''),
      ),
    ),
    // One group: its members, the owner's tools and the invite code.
    '/groups/:id': (data) => MaterialPage(
      child: GroupPage(groupId: Uri.decodeComponent(data.pathParameters['id'] ?? '')),
    ),
    // Where an invite link lands: https://saobracaj.gleb.at/invite/ABC-DEF-GHI
    '/invite/:token': (data) => MaterialPage(
      child: InvitePage(token: Uri.decodeComponent(data.pathParameters['token'] ?? '')),
    ),
    // Its activity feed: paged history, live while the screen is open.
    '/groups/:id/feed': (data) => MaterialPage(
      child: GroupFeedPage(groupId: Uri.decodeComponent(data.pathParameters['id'] ?? '')),
    ),
    // Questions opened from a feed event sit under the feed, so finishing the
    // run (or pressing back) returns to the feed rather than to the home tab.
    '/groups/:id/feed/q': questPage,
    '/groups/:id/feed/q/zakon': zakonPage,
    '/lists/:id/q': questPage,
    '/lists/:id/q/zakon': zakonPage,
    '/questPractice/q': questPage,
    '/questPractice/q/zakon': zakonPage,
    '/questPractice':
        (data) => MaterialPage(
          child: Practice(
            params: PracticeParams(
              showRightAnswers: data.queryParameters['showRightAnswers'] == 'true',
              showStats: data.queryParameters['showStats'] == 'true',
              buttonsLikeInExam: data.queryParameters['buttonsLikeInExam'] == 'true',
            ),
          ),
        ),
    '/about': (_) => MaterialPage(child: AboutPage()),
    '/about/privacyPolicy': (_) => MaterialPage(child: PrivacyPolicyWidget()),
    '/zakon': zakonPage,
    // Deep link to a category konspekt, optionally straight to one section:
    // /konspekt?category=25&section=manevri
    '/konspekt': konspektPage,
    // Law links inside a konspekt open as its children, so "back" returns to
    // the konspekt (same pattern as '/quest/zakon'). A question link opens the
    // preview sheet over the text instead — the full-screen route stays for the
    // links that are already out there.
    '/konspekt/question/:id': questCommentsPage,
    '/konspekt/question/:id/zakon': zakonPage,
    '/konspekt/zakon': zakonPage,
    // Everything a question screen can open sits under it, so "back" (and the
    // pop after saving a draft) returns to the question instead of dropping the
    // stack: the admin draft editor with its own '/zakon' child for law links
    // in the preview, and the full konspekt reached from the konspekt tab.
    for (final host in _questionHosts) ...{
      '$host/commentEdit': commentEditPage,
      '$host/commentEdit/zakon': zakonPage,
      '$host/konspekt': konspektPage,
      '$host/konspekt/zakon': zakonPage,
    },
    '/login': (_) => const MaterialPage(child: LoginPage()),
    '/register': (_) => const MaterialPage(child: RegisterPage()),
    '/resetPassword': (_) => const MaterialPage(child: ResetPasswordPage()),
    '/confirmCode':
        (data) => MaterialPage(
          child: ConfirmCodePage(
            email: data.queryParameters['email'] ?? '',
          ),
        ),
    '/settings': (_) => const MaterialPage(child: ProfilePage()),
    '/profile': (_) => const MaterialPage(child: ProfilePage()),
    '/appearance': (_) => const MaterialPage(child: AppearancePage()),
    '/features': (_) => const MaterialPage(child: FeatureFlagsPage()),
    '/notifications': (_) => const MaterialPage(child: NotificationsPage()),
    '/displayName': (_) => const MaterialPage(child: DisplayNamePage()),
    '/moderation': (_) => const MaterialPage(child: ModerationPage()),
    // The support chat ("чат с разработчиком"). The user's own conversation
    // needs no id — the backend resolves it from the token; the moderator's
    // list and the conversations opened from it sit under it, so "back" from a
    // conversation returns to the list.
    '/support': (_) => const MaterialPage(child: SupportChatPage()),
    '/support/threads': (_) => const MaterialPage(child: SupportThreadsPage()),
    '/support/threads/:id': (data) => MaterialPage(
      child: SupportChatPage(
        threadId: Uri.decodeComponent(data.pathParameters['id'] ?? ''),
      ),
    ),
  },
);

/// Deep link into a single question opened straight on its discussion tab.
/// Path: `/question/{id}`; query `comments=1` opens the comments tab and
/// scrolls to it, `thread={topCommentId}` expands that thread.
MaterialPage questCommentsPage(dynamic data) {
  final id = int.tryParse(data.pathParameters['id'] as String? ?? '');
  final comments = data.queryParameters['comments'];
  return MaterialPage(
    child: Quest(
      options: StartTestState(random: false, randomOptionsOrder: false),
      questions: id != null ? [id] : const <int>[],
      openComments: comments == '1' || comments == 'true',
      commentThreadId: data.queryParameters['thread'],
    ),
  );
}

/// The question ids of a `q=1,2,3` query parameter. A URL typed or mangled by
/// hand can miss the parameter or hold garbage — those ids are simply dropped,
/// and the routes above redirect instead of crashing the first frame into a
/// grey screen when nothing is left.
List<int> _questionIdsParam(String? q) =>
    (q ?? '').split(',').map(int.tryParse).whereType<int>().toList();

RouteSettings questPage(RouteData data) {
  final ids = _questionIdsParam(data.queryParameters['q']);
  if (ids.isEmpty) return const Redirect('/home');
  return MaterialPage(
    child: Quest(
      options: StartTestState(
        random: data.queryParameters['random'] == 'true',
        randomOptionsOrder: data.queryParameters['randomOptionsOrder'] == 'true',
      ),
      questions: ids,
      subcategory: data.queryParameters['subcategory'],
    ),
  );
}

/// A konspekt page; `category` says which one.
///
/// Without a category there is nothing to show. That happens when the path is
/// built as the *parent* of a deep link like `/konspekt/question/7921`:
/// Routemaster instantiates every segment of the path, so the konspekt below
/// the question used to be created with an empty category and greeted the user
/// with "Не удалось загрузить конспект" as soon as they pressed back. A
/// [Redirect] on a parent route drops it from the stack entirely, which is
/// exactly what should happen here.
RouteSettings konspektPage(RouteData params) {
  final categoryId = params.queryParameters['category'] ?? '';
  if (categoryId.isEmpty) return const Redirect('/questions');
  return MaterialPage(
    child: KonspektPage(
      categoryId: categoryId,
      section: params.queryParameters['section'],
    ),
  );
}

/// The admin-only comment draft editor; `id` is the question id.
MaterialPage commentEditPage(dynamic data) => MaterialPage(
  child: CommentEditorPage(
    questionId: int.tryParse(data.queryParameters['id'] ?? '') ?? 0,
  ),
);

MaterialPage zakonPage(dynamic params) => MaterialPage(
  child: Zakon(
    paragraph: params.queryParameters['paragraph'],
    chapter: params.queryParameters['chapter'],
    chlan: params.queryParameters['chlan'],
  ),
);
