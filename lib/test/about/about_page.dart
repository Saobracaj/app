import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/legal_documents.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/about/about_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_info.tr()),
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
        const AboutInfo(),
        const SizedBox(height: 16),
        LegalDocumentTile(
          document: LegalDocument.privacyPolicy,
          title: LocaleKeys.info_privacyPolicy.tr(),
        ),
        LegalDocumentTile(
          document: LegalDocument.termsOfUse,
          title: LocaleKeys.info_termsOfUse.tr(),
        ),
        ListTile(
          title: const Text('ЗАКОН О БЕЗБЕДНОСТИ САОБРАЋАЈА НА ПУТЕВИМА'),
          onTap: () {
            Routemaster.of(context).push('/zakon');
          },
        ),
      ],
    );
  }
}

/// Пункт списка, открывающий юридический документ во внешнем браузере.
///
/// Документы не встраиваются в приложение (см. [legalDocumentUri]): в
/// подзаголовке показан адрес, чтобы было видно, куда ведёт ссылка, а иконка
/// подсказывает, что откроется браузер. Язык документа — язык интерфейса.
class LegalDocumentTile extends StatelessWidget {
  const LegalDocumentTile({
    super.key,
    required this.document,
    required this.title,
  });

  final LegalDocument document;
  final String title;

  @override
  Widget build(BuildContext context) {
    final uri = legalDocumentUri(document, context.locale.languageCode);
    return ListTile(
      title: Text(title),
      subtitle: Text('${uri.host}${uri.path}'),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  }
}
