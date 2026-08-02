import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// Главная страница приложения. Пока пустая заготовка.
class HomeContentPage extends StatelessWidget {
  const HomeContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_home.tr()),
        actions: const [AuthButton()],
      ),
      body: const Center(
        child: Text('Home'),
      ),
    );
  }
}
