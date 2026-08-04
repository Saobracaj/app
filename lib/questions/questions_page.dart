import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/categories.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_bloc.dart';
import 'package:saobracaj/questions/search/presentation/searchable_questions.dart';

class QuestionsPage extends StatelessWidget {
  const QuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final searchEnabled = context.select((FeatureFlagsBloc bloc) => bloc.state.isEnabled(AppFeature.questionSearch));
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_questions.tr()),
        actions: const [AuthButton()],
      ),
      body: BlocProvider(
        create: (_) => getIt<KonspektCatalogBloc>(),
        child: searchEnabled ? const SearchableQuestions() : const Categories(),
      ),
    );
  }
}
