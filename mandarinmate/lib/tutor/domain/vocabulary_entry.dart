import 'package:equatable/equatable.dart';

class TutorVocabularyEntry extends Equatable {
  final String id;
  final String word;
  final String meaning;
  final String pronunciation;
  final String listeningText;
  final String audioUrl;
  final String exampleSentence;
  final String exampleMeaning;
  final String quizQuestion;
  final List<String> quizOptions;
  final int correctAnswerIndex;
  final String source;

  const TutorVocabularyEntry({
    required this.id,
    required this.word,
    required this.meaning,
    required this.pronunciation,
    required this.listeningText,
    required this.audioUrl,
    required this.exampleSentence,
    required this.exampleMeaning,
    required this.quizQuestion,
    required this.quizOptions,
    required this.correctAnswerIndex,
    required this.source,
  });

  factory TutorVocabularyEntry.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return TutorVocabularyEntry(
      id: id,
      word: (data['word'] ?? '').toString(),
      meaning: (data['meaning'] ?? '').toString(),
      pronunciation: (data['pronunciation'] ?? '').toString(),
      listeningText: (data['listeningText'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      exampleSentence: (data['exampleSentence'] ?? '').toString(),
      exampleMeaning: (data['exampleMeaning'] ?? '').toString(),
      quizQuestion: (data['quizQuestion'] ?? '').toString(),
      quizOptions:
          (data['quizOptions'] as List?)
              ?.map((value) => (value ?? '').toString())
              .toList() ??
          <String>[],
      correctAnswerIndex: (data['correctAnswerIndex'] as num?)?.toInt() ?? 0,
      source: (data['source'] ?? 'manual').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'word': word,
      'meaning': meaning,
      'pronunciation': pronunciation,
      'listeningText': listeningText,
      'audioUrl': audioUrl,
      'exampleSentence': exampleSentence,
      'exampleMeaning': exampleMeaning,
      'quizQuestion': quizQuestion,
      'quizOptions': quizOptions,
      'correctAnswerIndex': correctAnswerIndex,
      'source': source,
    };
  }

  @override
  List<Object?> get props => [
    id,
    word,
    meaning,
    pronunciation,
    listeningText,
    audioUrl,
    exampleSentence,
    exampleMeaning,
    quizQuestion,
    quizOptions,
    correctAnswerIndex,
    source,
  ];
}
