import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_time_ago/get_time_ago.dart';
import 'package:routemaster/routemaster.dart';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/test/practice/finalize_practice.dart';
import 'package:saobracaj/test/practice/practice.dart' show formatDuration;
import 'package:saobracaj/test/practice/widgets/quest_button.dart';

import '../../db/db.dart' show PracticeRecord;
import '../../db/dependencies.dart' show repository;

part 'practice_page.freezed.dart';

class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PracticePageBloc(),
      child: BlocBuilder<PracticePageBloc, PracticeParams>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text('Симуляция экзамена')),
            body: ListView(
              children: [
                CheckboxListTile(
                  title: Text('Показывать ошибки сразу'),
                  value: state.showRightAnswers,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleRightAnswers()),
                ),
                CheckboxListTile(
                  title: Text('Показывать статистику по предыдущим попыткам'),
                  value: state.showStats,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleShowStats()),
                ),
                CheckboxListTile(
                  title: Text('Кнопки как на экзамене'),
                  // subtitle: Text('Менее удобно, но ближе к реальности'),
                  value: state.buttonsLikeInExam,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleButtonsLikeInExam()),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child:
                      state.buttonsLikeInExam
                          ? CustomIconButton(
                            onPressed: () => onPressed(context, state),
                            icon: Icons.arrow_forward,
                            label: 'Потврдите почетак симулације испита',
                            color: const Color(0xFF2C6AA0),
                          )
                          : ElevatedButton(onPressed: () => onPressed(context, state), child: Text('Начать симуляцию')),
                ),
                if (state.records.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Предыдущие попытки (${state.records.length}):', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (var record in state.records)
                    ListTile(
                      title: Text(
                        'Балов: ${record.points}, ошибок: ${record.mistakes}, время: ${formatDuration(Duration(seconds: record.durationSeconds))}',
                      ),
                      subtitle: Text(GetTimeAgo.parse(record.time)),
                      leading: record.points < kMinPoints ? Icon(Icons.close, color: Colors.red) : Icon(Icons.check, color: Colors.green),
                      onTap: record.wrongAnswers.isEmpty ? null : () {
                        Routemaster.of(context).push('/start?q=${record.wrongAnswers.join(',')}');
                      },
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void onPressed(BuildContext context, PracticeParams state) async {
    await Routemaster.of(context)
        .push(
          '/questPractice?'
          'showRightAnswers=${state.showRightAnswers}'
          '&showStats=${state.showStats}'
          '&buttonsLikeInExam=${state.buttonsLikeInExam}',
        )
        .result;
    if (context.mounted) {
      context.read<PracticePageBloc>().add(LoadPrevTries());
    }
  }
}

@freezed
sealed class PracticeParams with _$PracticeParams {
  const factory PracticeParams({
    @Default(false) bool showRightAnswers,
    @Default(false) bool showStats,
    @Default(false) bool buttonsLikeInExam,
    @Default([]) List<PracticeResult> records,
  }) = _PracticeParams;
}

class PracticePageBloc extends Bloc<PracticePageEvent, PracticeParams> {
  PracticePageBloc() : super(PracticeParams()) {
    on<ToggleRightAnswers>(_onToggleRightAnswers);
    on<ToggleShowStats>(_onToggleShowStats);
    on<ToggleButtonsLikeInExam>(_onToggleButtonsLikeInExam);
    on<LoadPrevTries>(_onLoadPrevTries);
    add(LoadPrevTries());
  }

  void _onToggleRightAnswers(ToggleRightAnswers event, Emitter<PracticeParams> emit) {
    emit(state.copyWith(showRightAnswers: !state.showRightAnswers));
  }

  void _onToggleShowStats(ToggleShowStats event, Emitter<PracticeParams> emit) {
    emit(state.copyWith(showStats: !state.showStats));
  }

  void _onToggleButtonsLikeInExam(ToggleButtonsLikeInExam event, Emitter<PracticeParams> emit) {
    emit(state.copyWith(buttonsLikeInExam: !state.buttonsLikeInExam));
  }

  void _onLoadPrevTries(LoadPrevTries event, Emitter<PracticeParams> emit) async {
    final List<PracticeRecord> records = await repository.getPracticeRecords();
    emit(
      state.copyWith(
        records:
            records
                .map(
                  (e) => PracticeResult(
                    points: e.points,
                    time: e.time,
                    mistakes: e.mistakes,
                    durationSeconds: e.durationSeconds,
                    wrongAnswers: e.wrongAnswers ?? [],
                  ),
                )
                .toList(),
      ),
    );
  }
}

sealed class PracticePageEvent {}

class ToggleRightAnswers extends PracticePageEvent {}

class ToggleShowStats extends PracticePageEvent {}

class ToggleButtonsLikeInExam extends PracticePageEvent {}

class LoadPrevTries extends PracticePageEvent {}

@freezed
sealed class PracticeResult with _$PracticeResult {
  const factory PracticeResult({
    required int points,
    required DateTime time,
    required int mistakes,
    required int durationSeconds,
    @Default([]) List<int> wrongAnswers,
  }) = _PracticeResult;
}
