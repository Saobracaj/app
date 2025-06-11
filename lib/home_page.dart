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
      appBar: AppBar(
        title: TextFormField(decoration: const InputDecoration(border: UnderlineInputBorder(), labelText: 'Enter your username')),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.person))],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          destinations: [
            NavigationDestination(label: LocaleKeys.home_questions.tr(), icon: const Icon(Icons.question_answer)),
            NavigationDestination(label: LocaleKeys.home_simulation.tr(), icon: const Icon(Icons.car_crash_outlined)),
            NavigationDestination(label: LocaleKeys.home_history.tr(), icon: const Icon(Icons.graphic_eq)),
            NavigationDestination(label: LocaleKeys.home_info.tr(), icon: const Icon(Icons.info_outline_rounded)),
          ],
          selectedIndex: pageState.index,
          onDestinationSelected: (index) {
            setState(() => pageState.index = index);
          },
        ),
      ),
      body: PageStackNavigator(key: ValueKey(pageState.index), stack: pageState.stacks[pageState.index]),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
