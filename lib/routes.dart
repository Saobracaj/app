import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/state_management/start_test_bloc.dart';
import 'package:saobracaj/statistics/statistics_page.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/start_test.dart';

final routes = RouteMap(
  routes: {
    '/': (_) => IndexedPage(child: HomePage(), paths: ['/questions', '/statistics']),
    '/questions': (_) => MaterialPage(child: QuestionsPage()),
    '/statistics': (_) => MaterialPage(child: StatisticsPage()),
    '/start': (data) => MaterialPage(child: StartTest(questionIds: data.queryParameters['q']!.split(',').map(int.parse).toList())),
    '/quest':
        (data) => MaterialPage(
          child: Quest(
            options: StartTestState(
              random: data.queryParameters['random']?.isNotEmpty ?? false,
              randomOptionsOrder: data.queryParameters['randomOptionsOrder']?.isNotEmpty ?? false,
            ),
            questions: data.queryParameters['q']!.split(',').map(int.parse).toList(),
          ),
        ),
  },
);
