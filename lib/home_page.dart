import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'core/responsive.dart';
import 'generated/locale_keys.g.dart';

/// One destination of the home shell, rendered either as a [NavigationBar]
/// item (phones) or a [NavigationRail] one (tablet/web).
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final pageState = IndexedPage.of(context);
    // Each destination carries the Material 3 pair of a filled icon for the
    // selected state and an outlined one for the rest.
    final destinations = [
      _Destination(LocaleKeys.home_home.tr(), Icons.home_outlined, Icons.home),
      _Destination(
        LocaleKeys.home_questions.tr(),
        Icons.question_answer_outlined,
        Icons.question_answer,
      ),
      _Destination(
        LocaleKeys.home_simulation.tr(),
        Icons.car_crash_outlined,
        Icons.car_crash,
      ),
      _Destination(
        LocaleKeys.home_history.tr(),
        Icons.insights_outlined,
        Icons.insights,
      ),
      _Destination(
        LocaleKeys.home_settings.tr(),
        Icons.settings_outlined,
        Icons.settings,
      ),
    ];
    final body = PageStackNavigator(
      key: ValueKey(pageState.index),
      stack: pageState.stacks[pageState.index],
    );

    // On tablets and web the tabs live in a rail on the left — a bottom bar
    // under a wide window is a long mouse trip away from the content. The
    // rail grows labels once there is comfortably room for them.
    if (context.isMediumScreen) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: context.isLargeScreen,
                labelType: context.isLargeScreen
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                groupAlignment: -0.9,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      label: Text(d.label),
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                    ),
                ],
                selectedIndex: pageState.index,
                onDestinationSelected: (index) {
                  setState(() => pageState.index = index);
                },
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      );
    }

    return Scaffold(
      // A NavigationBar is a bottom bar in its own right — nesting it inside a
      // BottomAppBar stacked two surfaces and reserved a FAB notch that nothing
      // ever filled.
      bottomNavigationBar: NavigationBar(
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              label: d.label,
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
            ),
        ],
        selectedIndex: pageState.index,
        onDestinationSelected: (index) {
          setState(() => pageState.index = index);
        },
      ),
      body: body,
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
