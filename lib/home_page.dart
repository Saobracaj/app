import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';

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
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          destinations: [
            NavigationDestination(label: 'Вопросы', icon: const Icon(Icons.question_answer)),
            NavigationDestination(label: 'История', icon: const Icon(Icons.graphic_eq)),
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
