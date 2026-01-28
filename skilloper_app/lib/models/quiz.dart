class Question {
  final int id;
  final String questionType;
  final String question;
  final String? code;
  final String? language;
  final List<String> options;
  final int? correctAnswer;
  final List<int>? correctAnswers;
  final String? explanation;
  final List<String>? alternativeQuestions;
  final List<String>? extraOptions;
  final List<List<String>>? optionVariants;

  const Question({
    required this.id,
    required this.questionType,
    required this.question,
    required this.options,
    this.code,
    this.language,
    this.correctAnswer,
    this.correctAnswers,
    this.explanation,
    this.alternativeQuestions,
    this.extraOptions,
    this.optionVariants,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final question = json['question'];

    if (id == null) {
      throw const FormatException('Question missing required field: id');
    }
    if (question == null) {
      throw const FormatException('Question missing required field: question');
    }

    return Question(
      id: id is int ? id : int.parse(id.toString()),
      questionType: json['question_type'] as String? ?? 'single_choice',
      question: question.toString(),
      code: json['code'] as String?,
      language: json['language'] as String?,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : <String>[],
      correctAnswer: json['correct_answer'] as int?,
      correctAnswers: json['correct_answers'] != null
          ? List<int>.from(json['correct_answers'] as List)
          : null,
      explanation: json['explanation'] as String?,
      alternativeQuestions: json['alternative_questions'] != null
          ? List<String>.from(json['alternative_questions'] as List)
          : null,
      extraOptions: json['extra_options'] != null
          ? List<String>.from(json['extra_options'] as List)
          : null,
      optionVariants: json['option_variants'] != null
          ? (json['option_variants'] as List)
                .map((v) => List<String>.from(v as List))
                .toList()
          : null,
    );
  }

  bool get isMultipleChoice => questionType == 'multiple_choice';
  bool get isSingleChoice => questionType == 'single_choice';
}

class QuizSummary {
  final int id;
  final String title;
  final String description;
  final String type; // 'practice' or 'exam'
  final int maxOptions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int questionCount;
  final int? collectionId;
  final String? collectionName;

  const QuizSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.maxOptions,
    required this.createdAt,
    required this.updatedAt,
    required this.questionCount,
    this.collectionId,
    this.collectionName,
  });

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];

    if (id == null) {
      throw const FormatException('QuizSummary missing required field: id');
    }
    if (title == null) {
      throw const FormatException('QuizSummary missing required field: title');
    }
    if (createdAt == null) {
      throw const FormatException(
        'QuizSummary missing required field: created_at',
      );
    }

    return QuizSummary(
      id: id is int ? id : int.parse(id.toString()),
      title: title.toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? 'practice').toString(),
      maxOptions: (json['max_options'] as int?) ?? 4,
      createdAt: DateTime.parse(createdAt.toString()),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt.toString())
          : DateTime.parse(createdAt.toString()),
      questionCount: (json['question_count'] as int?) ?? 0,
      collectionId: json['collection_id'] as int?,
      collectionName: json['collection_name'] as String?,
    );
  }

  bool get isPracticeMode => type == 'practice';

  int get estimatedMinutes => (questionCount * 1.5).ceil();
}

class Quiz {
  final int id;
  final String title;
  final String description;
  final String type; // 'practice' or 'exam'
  final int maxOptions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Question> questions;

  const Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.maxOptions,
    required this.createdAt,
    required this.updatedAt,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    final questions = json['questions'];

    if (id == null) {
      throw const FormatException('Quiz missing required field: id');
    }
    if (title == null) {
      throw const FormatException('Quiz missing required field: title');
    }
    if (createdAt == null) {
      throw const FormatException('Quiz missing required field: created_at');
    }
    if (questions == null) {
      throw const FormatException('Quiz missing required field: questions');
    }

    return Quiz(
      id: id is int ? id : int.parse(id.toString()),
      title: title.toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? 'practice').toString(),
      maxOptions: (json['max_options'] as int?) ?? 4,
      createdAt: DateTime.parse(createdAt.toString()),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt.toString())
          : DateTime.parse(createdAt.toString()),
      questions: (questions as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isPracticeMode => type == 'practice';

  int get estimatedMinutes => (questions.length * 1.5).ceil();
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
    required this.isCorrect,
    this.userAnswer,
    this.userAnswers,
  });
}
