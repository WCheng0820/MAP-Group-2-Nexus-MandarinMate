import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mandarinmate/features/lessons/data/lesson_repository.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';

abstract class LessonEvent extends Equatable {
  const LessonEvent();
  @override
  List<Object?> get props => [];
}

class LessonLoadUnits extends LessonEvent {}

class LessonLoadVocab extends LessonEvent {
  final String unitDocId;
  const LessonLoadVocab(this.unitDocId);
  @override
  List<Object?> get props => [unitDocId];
}

class LessonSelectUnit extends LessonEvent {
  final LessonUnit unit;
  const LessonSelectUnit(this.unit);
  @override
  List<Object?> get props => [unit];
}

abstract class LessonState extends Equatable {
  const LessonState();
  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

class LessonUnitsLoaded extends LessonState {
  final List<LessonUnit> units;
  const LessonUnitsLoaded(this.units);
  @override
  List<Object?> get props => [units];
}

class LessonVocabLoaded extends LessonState {
  final List<LessonUnit> units;
  final LessonUnit unit;
  final List<VocabItem> vocabItems;
  const LessonVocabLoaded({
    required this.units,
    required this.unit,
    required this.vocabItems,
  });
  @override
  List<Object?> get props => [units, unit, vocabItems];
}

class LessonError extends LessonState {
  final String message;
  const LessonError(this.message);
  @override
  List<Object?> get props => [message];
}

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository repository;
  List<LessonUnit> _units = const [];

  LessonBloc({required this.repository}) : super(LessonInitial()) {
    on<LessonLoadUnits>(_onLessonLoadUnits);
    on<LessonLoadVocab>(_onLessonLoadVocab);
  }

  Future<void> _onLessonLoadUnits(
    LessonLoadUnits event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      _units = await repository.lessonUnits.first;
      emit(LessonUnitsLoaded(_units));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonLoadVocab(
    LessonLoadVocab event,
    Emitter<LessonState> emit,
  ) async {
    try {
      if (_units.isEmpty) {
        _units = await repository.lessonUnits.first;
      }
      LessonUnit? unit;
      for (final item in _units) {
        if (item.id == event.unitDocId) {
          unit = item;
          break;
        }
      }
      if (unit == null) {
        emit(const LessonError('Unit not found'));
        return;
      }
      final vocabItems = await repository.getVocabForUnit(event.unitDocId);
      emit(
        LessonVocabLoaded(units: _units, unit: unit, vocabItems: vocabItems),
      );
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }
}
