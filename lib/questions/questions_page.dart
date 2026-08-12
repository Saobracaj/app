import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/categories.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_bloc.dart';
import 'package:saobracaj/questions/search/presentation/searchable_questions.dart';

class QuestionsPage extends StatelessWidget {
  const QuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final searchEnabled = context.select(
      (FeatureFlagsBloc bloc) =>
          bloc.state.isEnabled(AppFeature.questionSearch),
    );
    // Широкое окно: подкатегории плитками, поиск — в закреплённой шапке
    // рядом с заголовком страницы (макет веб-версии).
    if (context.isExpandedScreen) {
      final withSidebar = context.isLargeScreen;
      return Scaffold(
        appBar: withSidebar
            ? null
            : AppBar(
                title: Text(LocaleKeys.home_questions.tr()),
                actions: const [AuthButton()],
              ),
        backgroundColor: widePageBackground(context),
        body: BlocProvider(
          create: (_) => getIt<KonspektCatalogBloc>(),
          child: searchEnabled
              ? SearchableQuestions(wide: true, showTitle: withSidebar)
              : Column(
                  children: [
                    if (withSidebar) const QuestionsWideHeader(),
                    const Expanded(child: Categories(wide: true)),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_questions.tr()),
        actions: const [AuthButton()],
      ),
      body: ReadableWidth(
        child: BlocProvider(
          create: (_) => getIt<KonspektCatalogBloc>(),
          child: searchEnabled
              ? const SearchableQuestions()
              : const Categories(),
        ),
      ),
    );
  }
}

/// Закреплённая шапка страницы «Вопросы» на широком экране: заголовок и, если
/// поиск включён, поле поиска справа от него. По макету шапка отделена от
/// контента линией и залита цветом полотна.
class QuestionsWideHeader extends StatelessWidget {
  const QuestionsWideHeader({super.key, this.trailing, this.showTitle = true});

  /// Поле поиска (живёт внутри [SearchableQuestions] — там же, где его блок).
  final Widget? trailing;

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!showTitle && trailing == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widePageBackground(context),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: WideContent(
        padding: const EdgeInsets.fromLTRB(
          kWidePageHorizontalPadding,
          20,
          kWidePageHorizontalPadding,
          16,
        ),
        child: Row(
          children: [
            if (showTitle)
              Text(
                LocaleKeys.home_questions.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            if (trailing != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
