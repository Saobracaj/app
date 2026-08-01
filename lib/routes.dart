import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/confirm_code_page.dart';
import 'package:saobracaj/auth/presentation/login_page.dart';
import 'package:saobracaj/auth/presentation/profile_page.dart';
import 'package:saobracaj/auth/presentation/register_page.dart';
import 'package:saobracaj/auth/presentation/reset_password_page.dart';
import 'package:saobracaj/theme/presentation/appearance_page.dart';
import 'package:saobracaj/notifications/presentation/notifications_page.dart';
import 'package:saobracaj/home/home_content_page.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/statistics/statistics_page.dart';
import 'package:saobracaj/test/about/about_page.dart';
import 'package:saobracaj/test/about/privacy_policy.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/practice_page.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
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
    '/quest/zakon': zakonPage,
    '/quest/q': questPage,
    '/quest/q/zakon': zakonPage,
    '/statistics/q': questPage,
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
    '/notifications': (_) => const MaterialPage(child: NotificationsPage()),
  },
);

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

MaterialPage zakonPage(dynamic params) => MaterialPage(
  child: Zakon(
    paragraph: params.queryParameters['paragraph'],
    chapter: params.queryParameters['chapter'],
    chlan: params.queryParameters['chlan'],
  ),
);
