import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/state_management/start_test_bloc.dart';
import 'package:saobracaj/statistics/statistics_page.dart';
import 'package:saobracaj/test/about/about_page.dart';
import 'package:saobracaj/test/about/privacy_policy.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/practice_page.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/start_test.dart';

final routes = RouteMap(
  routes: {
    '/': (_) => IndexedPage(child: HomePage(), paths: ['/questions', '/practice',  '/statistics', '/about']),
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
    '/quest/q': questPage,
    '/statistics/q': questPage,
    '/questPractice/q': questPage,
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
