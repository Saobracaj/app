import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/state_management/about_bloc.dart';
import 'package:saobracaj/util/nav_to_url.dart';

class AboutInfo extends StatelessWidget {
  const AboutInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AboutBloc(),
      child: BlocBuilder<AboutBloc, String?>(
        builder: (context, state) {
          return Markdown(
            shrinkWrap: true, selectable: false,
            data: (state ?? '') + _aboutText,
            onTapLink: (text, href, title) => navigateToUri(context, Uri.parse(href!)),
          );
        },
      ),
    );
  }
}

const _aboutText = '''#### Контакты для связи:
Email: [info@gleb.at](mailto:info@gleb.at)

Telegram: [GlebKl](https://t.me/GlebKl)
''';