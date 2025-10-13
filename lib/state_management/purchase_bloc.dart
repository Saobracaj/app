import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_bloc.freezed.dart';

class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  PurchaseBloc() : super(PurchaseState()) {
    on<PurchaseEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}

sealed class PurchaseEvent {}

@freezed
abstract class PurchaseState with _$PurchaseState {
  const factory PurchaseState({
    @Default(false) bool premiumAvailable,
  }) = _PurchaseState;
}