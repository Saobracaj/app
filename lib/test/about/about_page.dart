import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/about/about_info.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('О приложении'),
        actions: const [AuthButton()],
      ),
      body: ListView(children: const [AboutContent()]),
    );
  }
}

/// Содержимое раздела «О приложении» без собственного скролла — встраивается и
/// в отдельный экран, и в правую панель настроек на широком экране. Ссылки
/// абсолютные, чтобы работали с любого хост-экрана.
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AboutInfo(),
        SizedBox(height: 16),
        ListTile(
          title: Text(LocaleKeys.info_privacyPolicy.tr()),
          onTap: () {
            Routemaster.of(context).push('/about/privacyPolicy');
          },
        ),
        ListTile(
          title: Text('ЗАКОН О БЕЗБЕДНОСТИ САОБРАЋАЈА НА ПУТЕВИМА'),
          onTap: () {
            Routemaster.of(context).push('/zakon');
          },
        ),
      ],
    );
  }
}
