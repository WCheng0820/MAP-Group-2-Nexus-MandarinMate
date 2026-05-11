import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/lesson_model.dart';
import '../../../models/user_model.dart';

// EVENTS
abstract class LessonEvent {}

class StartLesson extends LessonEvent {
  final Lesson lesson;
  StartLesson(this.lesson);
}

class NextItem extends LessonEvent {}

class SubmitAnswer extends LessonEvent {
  final bool isCorrect;
  SubmitAnswer(this.isCorrect);
}

class FinishLesson extends LessonEvent {
  final String userId;
  final UserProfile userProfile;
  FinishLesson(this.userId, this.userProfile);
}

// STATES
abstract class LessonState {}

class LessonInitial extends LessonState {}

class LessonActive extends LessonState {
  final Lesson lesson;
  final int currentIndex;
  final int correctAnswers;
  final bool? lastAnswerCorrect;
  final bool showFeedback;

  LessonActive({
    required this.lesson,
    required this.currentIndex,
    required this.correctAnswers,
    this.lastAnswerCorrect,
    this.showFeedback = false,
  });

  LessonItem get currentItem => lesson.items[currentIndex];
  double get progress => currentIndex / lesson.items.length;

  LessonActive copyWith({
    int? currentIndex,
    int? correctAnswers,
    bool? lastAnswerCorrect,
    bool? showFeedback,
  }) {
    return LessonActive(
      lesson: lesson,
      currentIndex: currentIndex ?? this.currentIndex,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      lastAnswerCorrect: lastAnswerCorrect,
      showFeedback: showFeedback ?? this.showFeedback,
    );
  }
}

class LessonCompleted extends LessonState {
  final Lesson lesson;
  final int correctAnswers;
  final int xpEarned;
  
  LessonCompleted({
    required this.lesson,
    required this.correctAnswers,
    required this.xpEarned,
  });
}

// BLOC
class LessonBloc extends Bloc<LessonEvent, LessonState> {
  LessonBloc() : super(LessonInitial()) {
    on<StartLesson>((event, emit) {
      emit(LessonActive(
        lesson: event.lesson,
        currentIndex: 0,
        correctAnswers: 0,
      ));
    });

    on<SubmitAnswer>((event, emit) {
      if (state is LessonActive) {
        final currentState = state as LessonActive;
        emit(currentState.copyWith(
          lastAnswerCorrect: event.isCorrect,
          correctAnswers: currentState.correctAnswers + (event.isCorrect ? 1 : 0),
          showFeedback: true,
        ));
      }
    });

    on<NextItem>((event, emit) {
      if (state is LessonActive) {
        final currentState = state as LessonActive;
        if (currentState.currentIndex < currentState.lesson.items.length - 1) {
          emit(LessonActive(
            lesson: currentState.lesson,
            currentIndex: currentState.currentIndex + 1,
            correctAnswers: currentState.correctAnswers,
          ));
        } else {
          emit(LessonCompleted(
            lesson: currentState.lesson,
            correctAnswers: currentState.correctAnswers,
            xpEarned: currentState.lesson.xpReward,
          ));
        }
      }
    });
  }
}
