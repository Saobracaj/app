import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/about/about_info.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('О приложении')),
      body: ListView(
        children: [
          AboutInfo(),
          SizedBox(height: 16),
          ListTile(title: Text(LocaleKeys.info_privacyPolicy.tr()), onTap: () {
            Routemaster.of(context).push('privacyPolicy');
          },),
        ],
      ),
    );
  }
}
