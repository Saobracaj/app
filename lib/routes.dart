import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/home_page.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/statistics/statistics_page.dart';

final routes = RouteMap(
  routes: {
    '/': (_) => IndexedPage(child: HomePage(), paths: ['/questions', '/statistics']),
    '/questions': (_) => MaterialPage(child: QuestionsPage()),
    '/statistics': (_) => MaterialPage(child: StatisticsPage()),
  },
);
