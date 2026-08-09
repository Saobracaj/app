import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/groups/presentation/groups_section.dart';
import 'package:saobracaj/question_lists/presentation/question_lists_section.dart';

/// Главная страница приложения: раздел со списками вопросов (автоматические +
/// пользовательские) и карточки групп пользователя.
class HomeContentPage extends StatelessWidget {
  const HomeContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.home_home.tr()), actions: const [AuthButton()]),
      // Карточки групп и лента списков шире читабельной колонки смотрятся
      // разъехавшимися — на широких экранах контент собран по центру.
      body: ReadableWidth(
        maxWidth: 840,
        child: ListView(
          children: [
            SizedBox(height: 8),
            QuestionListsSection(),
            SizedBox(height: 8),
            GroupsSection(),
          ],
        ),
      ),
    );
  }
}
