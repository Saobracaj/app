import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'generated/locale_keys.g.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final pageState = IndexedPage.of(context);
    return Scaffold(
      // A NavigationBar is a bottom bar in its own right — nesting it inside a
      // BottomAppBar stacked two surfaces and reserved a FAB notch that nothing
      // ever filled. Each destination carries the Material 3 pair of a filled
      // icon for the selected state and an outlined one for the rest.
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            label: LocaleKeys.home_home.tr(),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
          ),
          NavigationDestination(
            label: LocaleKeys.home_questions.tr(),
            icon: const Icon(Icons.question_answer_outlined),
            selectedIcon: const Icon(Icons.question_answer),
          ),
          NavigationDestination(
            label: LocaleKeys.home_simulation.tr(),
            icon: const Icon(Icons.car_crash_outlined),
            selectedIcon: const Icon(Icons.car_crash),
          ),
          NavigationDestination(
            label: LocaleKeys.home_history.tr(),
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
          ),
          NavigationDestination(
            label: LocaleKeys.home_settings.tr(),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
          ),
        ],
        selectedIndex: pageState.index,
        onDestinationSelected: (index) {
          setState(() => pageState.index = index);
        },
      ),
      body: PageStackNavigator(key: ValueKey(pageState.index), stack: pageState.stacks[pageState.index]),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
