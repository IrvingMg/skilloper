class Question {
  final int id;
  final String questionType;
  final String question;
  final String? code;
  final String? language;
  final List<String> options;
  final int? correctAnswer; // For single_choice
  final List<int>? correctAnswers; // For multiple_choice
  final String? explanation;

  const Question({
    required this.id,
    required this.questionType,
    required this.question,
    this.code,
    this.language,
    required this.options,
    this.correctAnswer,
    this.correctAnswers,
    this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      questionType: json['question_type'] as String? ?? 'single_choice',
      question: json['question'] as String,
      code: json['code'] as String?,
      language: json['language'] as String?,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'] as int?,
      correctAnswers: json['correct_answers'] != null
          ? List<int>.from(json['correct_answers'] as List)
          : null,
      explanation: json['explanation'] as String?,
    );
  }


  bool get isMultipleChoice => questionType == 'multiple_choice';
  bool get isSingleChoice => questionType == 'single_choice';
}

class QuestionnaireSummary {
  final int id;
  final String title;
  final String description;
  final String type; // 'practice' or 'exam'
  final int maxOptions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int questionCount;

  const QuestionnaireSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.maxOptions,
    required this.createdAt,
    required this.updatedAt,
    required this.questionCount,
  });

  factory QuestionnaireSummary.fromJson(Map<String, dynamic> json) {
    return QuestionnaireSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      maxOptions: json['max_options'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      questionCount: json['question_count'] as int,
    );
  }

  bool get isPracticeMode => type == 'practice';

  int get estimatedMinutes => (questionCount * 1.5).ceil();
}

class Questionnaire {
  final int id;
  final String title;
  final String description;
  final String type; // 'practice' or 'exam'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Question> questions;

  const Questionnaire({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.questions,
  });

  factory Questionnaire.fromJson(Map<String, dynamic> json) {
    return Questionnaire(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }


  bool get isPracticeMode => type == 'practice';
  
  int get estimatedMinutes => (questions.length * 1.5).ceil();
}

class ImportResponse {
  final String message;
  final QuestionnaireSummary questionnaire;

  const ImportResponse({
    required this.message,
    required this.questionnaire,
  });

  factory ImportResponse.fromJson(Map<String, dynamic> json) {
    return ImportResponse(
      message: json['message'] as String,
      questionnaire: QuestionnaireSummary.fromJson(json['questionnaire'] as Map<String, dynamic>),
    );
  }
}

class QuizResult {
  final int score;
  final int correct;
  final int total;
  final List<QuestionResult> questionResults;

  const QuizResult({
    required this.score,
    required this.correct,
    required this.total,
    required this.questionResults,
  });

  double get percentage => (correct / total) * 100;
}

class QuestionResult {
  final Question question;
  final int? userAnswer; // For single_choice
  final List<int>? userAnswers; // For multiple_choice
  final bool isCorrect;

  const QuestionResult({
    required this.question,
    this.userAnswer,
    this.userAnswers,
    required this.isCorrect,
  });
}