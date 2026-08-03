import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/question_lists/presentation/question_lists_section.dart';

/// Главная страница приложения. Пока содержит только раздел со списками
/// вопросов (автоматические + пользовательские).
class HomeContentPage extends StatelessWidget {
  const HomeContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_home.tr()),
        actions: const [AuthButton()],
      ),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          QuestionListsSection(),
        ],
      ),
    );
  }
}
