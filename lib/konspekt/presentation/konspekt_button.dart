import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_bloc.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_state.dart';

/// "Open konspekt" button for a category header. Renders nothing when the
/// `category_summaries` flag is off or the category has no bundled konspekt.
/// Requires a [KonspektCatalogBloc] above in the tree.
class KonspektButton extends StatelessWidget {
  const KonspektButton({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: AppFeature.categorySummaries,
      categoryId: categoryId,
      child: BlocBuilder<KonspektCatalogBloc, KonspektCatalogState>(
        buildWhen: (prev, curr) => prev.categories.contains(categoryId) != curr.categories.contains(categoryId),
        builder: (context, state) {
          if (!state.categories.contains(categoryId)) return const SizedBox.shrink();
          return IconButton(
            tooltip: LocaleKeys.konspekt_open.tr(),
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Routemaster.of(context).push('/konspekt', queryParameters: {'category': categoryId}),
          );
        },
      ),
    );
  }
}
