import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
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
    // Широкое окно: раскладка по макету веб-версии — заголовок страницы,
    // списки и группы плиточными сетками во всю колонку контента.
    if (context.isExpandedScreen) {
      final withSidebar = context.isLargeScreen;
      return Scaffold(
        // С боковой колонкой шапка не нужна: навигация и аккаунт живут в ней,
        // а заголовок страницы стоит в самом контенте.
        appBar: withSidebar
            ? null
            : AppBar(
                title: Text(LocaleKeys.home_home.tr()),
                actions: const [AuthButton()],
              ),
        backgroundColor: widePageBackground(context),
        body: ListView(
          children: [
            WideContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (withSidebar)
                    PageHeading(
                      title: LocaleKeys.home_home.tr(),
                      subtitle: LocaleKeys.home_subtitle.tr(),
                    ),
                  const QuestionListsSection(wide: true),
                  const SizedBox(height: 38),
                  const GroupsSection(wide: true),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_home.tr()),
        actions: const [AuthButton()],
      ),
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
