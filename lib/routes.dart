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
import 'package:saobracaj/test/about/about_page.dart';
import 'package:saobracaj/test/about/privacy_policy.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/practice_page.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/quest/comment/editor/presentation/comment_editor_page.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/start_test.dart';
import 'package:saobracaj/zakon/zakon.dart';

final routes = RouteMap(
  routes: {
    '/': (_) => IndexedPage(child: HomePage(), paths: ['/home', '/questions', '/practice', '/statistics', '/settings']),
    '/home': (_) => MaterialPage(child: HomeContentPage()),
    '/questions': (_) => MaterialPage(child: QuestionsPage()),
    '/statistics': (_) => MaterialPage(child: StatisticsPage()),
    '/practice': (_) => MaterialPage(child: PracticePage()),
    '/start':
        (data) => MaterialPage(
          child: StartTest(
            questionIds: data.queryParameters['q']!.split(',').map(int.parse).toList(),
            subcategory: data.queryParameters['subcategory'],
          ),
        ),
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
    // Question and law links inside a konspekt open as children of the
    // konspekt page, so "back" returns to the konspekt (same pattern as
    // '/quest/zakon').
    '/konspekt/question/:id': questCommentsPage,
    '/konspekt/question/:id/zakon': zakonPage,
    '/konspekt/zakon': zakonPage,
    // The admin draft editor opens as a child of whichever question screen it
    // was launched from, so "back" (and the pop after saving) returns there;
    // its own '/zakon' child keeps law links working from the preview.
    for (final host in [
      '/quest',
      '/quest/q',
      '/statistics/q',
      '/lists/:id/q',
      '/questPractice/q',
      '/question/:id',
      '/konspekt/question/:id',
    ]) ...{
      '$host/commentEdit': commentEditPage,
      '$host/commentEdit/zakon': zakonPage,
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

var questPage = (data) {
  return MaterialPage(
    child: Quest(
      options: StartTestState(
        random: data.queryParameters['random'] == 'true',
        randomOptionsOrder: data.queryParameters['randomOptionsOrder'] == 'true',
      ),
      questions: data.queryParameters['q']!.split(',').map<int>(int.parse).toList(),
      subcategory: data.queryParameters['subcategory'],
    ),
  );
};

MaterialPage konspektPage(dynamic params) => MaterialPage(
  child: KonspektPage(
    categoryId: params.queryParameters['category'] ?? '',
    section: params.queryParameters['section'],
  ),
);

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
