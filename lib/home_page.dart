import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final pageState = IndexedPage.of(context);
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => AllQuestionsBloc()..add(Load()))],
      child: Scaffold(
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            destinations: [
              NavigationDestination(label: 'Questions', icon: const Icon(Icons.question_answer)),
              NavigationDestination(label: 'Statistics', icon: const Icon(Icons.graphic_eq)),
            ],
            selectedIndex: pageState.index,
            onDestinationSelected: (index) {
              setState(() => pageState.index = index);
            },
          ),
        ),
        body: PageStackNavigator(key: ValueKey(pageState.index), stack: pageState.stacks[pageState.index]),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
