import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/core/environment/presentation/environment_dialog.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/about/state_management/about_bloc.dart';
import 'package:saobracaj/util/nav_to_url.dart';

class AboutInfo extends StatelessWidget {
  const AboutInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AboutBloc(),
      child: BlocBuilder<AboutBloc, String?>(
        builder: (context, state) {
          return GestureDetector(
            // Секретный вход в переключатель окружения (prod/dev): долгое
            // нажатие на блок версии. Только не на вебе — там окружение
            // выбирается автоматически по домену (saobracaj-dev.gleb.at).
            onLongPress: kIsWeb ? null : () => showEnvironmentDialog(context),
            child: Markdown(
              shrinkWrap: true, selectable: false,
              data: (state ?? '') + LocaleKeys.info_contactsMarkdown.tr(),
              onTapLink: (text, href, title) => navigateToUri(context, Uri.parse(href!)),
            ),
          );
        },
      ),
    );
  }
}
