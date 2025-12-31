/// Attempt status enum
enum AttemptStatus {
  inProgress,
  completed;

  static AttemptStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return AttemptStatus.inProgress;
      case 'completed':
        return AttemptStatus.completed;
      default:
        return AttemptStatus.inProgress;
    }
  }

  String toJson() {
    switch (this) {
      case AttemptStatus.inProgress:
        return 'in_progress';
      case AttemptStatus.completed:
        return 'completed';
    }
  }
}

/// Represents a summary of a quiz attempt (for history list)
class AttemptSummary {
  final int id;
  final String deviceId;
  final int questionnaireId;
  final String questionnaireTitle;
  final String questionnaireType;
  final int attemptNumber;
  final AttemptStatus status;
  final int score;
  final int correctCount;
  final int totalCount;
  final DateTime createdAt;
  final DateTime? completedAt;

  const AttemptSummary({
    required this.id,
    required this.deviceId,
    required this.questionnaireId,
    required this.questionnaireTitle,
    required this.questionnaireType,
    required this.attemptNumber,
    required this.status,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.createdAt,
    this.completedAt,
  });

  factory AttemptSummary.fromJson(Map<String, dynamic> json) {
    return AttemptSummary(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      questionnaireId: json['questionnaire_id'] as int,
      questionnaireTitle: json['questionnaire_title'] as String,
      questionnaireType: json['questionnaire_type'] as String,
      attemptNumber: json['attempt_number'] as int,
      status: AttemptStatus.fromString(json['status'] as String),
      score: json['score'] as int,
      correctCount: json['correct_count'] as int,
      totalCount: json['total_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  bool get isPracticeMode => questionnaireType == 'practice';
  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;
  int get incorrectCount => totalCount - correctCount;
}

/// Represents an answer to a question in an attempt
class AttemptAnswer {
  final int id;
  final int questionId;
  final String questionText;
  final String questionType;
  final int? userAnswer;
  final List<int>? userAnswers;
  final int? correctAnswer;
  final List<int>? correctAnswers;
  final List<String> options;
  final bool isCorrect;

  const AttemptAnswer({
    required this.id,
    required this.questionId,
    required this.questionText,
    required this.questionType,
    this.userAnswer,
    this.userAnswers,
    this.correctAnswer,
    this.correctAnswers,
    required this.options,
    required this.isCorrect,
  });

  factory AttemptAnswer.fromJson(Map<String, dynamic> json) {
    return AttemptAnswer(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String? ?? 'single_choice',
      userAnswer: json['user_answer'] as int?,
      userAnswers: json['user_answers'] != null
          ? List<int>.from(json['user_answers'] as List)
          : null,
      correctAnswer: json['correct_answer'] as int?,
      correctAnswers: json['correct_answers'] != null
          ? List<int>.from(json['correct_answers'] as List)
          : null,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : [],
      isCorrect: json['is_correct'] as bool,
    );
  }

  bool get isMultipleChoice => questionType == 'multiple_choice';
  bool get isSingleChoice => questionType == 'single_choice';
}

/// Represents a full quiz attempt with all answers
class QuizAttempt {
  final int id;
  final String deviceId;
  final int questionnaireId;
  final String questionnaireTitle;
  final String questionnaireType;
  final int attemptNumber;
  final AttemptStatus status;
  final int score;
  final int correctCount;
  final int totalCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<AttemptAnswer> answers;

  const QuizAttempt({
    required this.id,
    required this.deviceId,
    required this.questionnaireId,
    required this.questionnaireTitle,
    required this.questionnaireType,
    required this.attemptNumber,
    required this.status,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.createdAt,
    this.completedAt,
    required this.answers,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      questionnaireId: json['questionnaire_id'] as int,
      questionnaireTitle: json['questionnaire_title'] as String,
      questionnaireType: json['questionnaire_type'] as String,
      attemptNumber: json['attempt_number'] as int,
      status: AttemptStatus.fromString(json['status'] as String),
      score: json['score'] as int,
      correctCount: json['correct_count'] as int,
      totalCount: json['total_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      answers: (json['answers'] as List?)
              ?.map((a) => AttemptAnswer.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isPracticeMode => questionnaireType == 'practice';
  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;
  int get incorrectCount => totalCount - correctCount;
}

/// Request to start a new attempt
class StartAttemptRequest {
  final String deviceId;
  final int questionnaireId;
  final String questionnaireTitle;
  final String questionnaireType;
  final int totalCount;

  const StartAttemptRequest({
    required this.deviceId,
    required this.questionnaireId,
    required this.questionnaireTitle,
    required this.questionnaireType,
    required this.totalCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'questionnaire_id': questionnaireId,
      'questionnaire_title': questionnaireTitle,
      'questionnaire_type': questionnaireType,
      'total_count': totalCount,
    };
  }
}

/// Request to complete an attempt
class CompleteAttemptRequest {
  final int score;
  final int correctCount;
  final int totalCount;
  final List<CreateAttemptAnswerRequest> answers;

  const CompleteAttemptRequest({
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.answers,
  });

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'correct_count': correctCount,
      'total_count': totalCount,
      'answers': answers.map((a) => a.toJson()).toList(),
    };
  }
}

/// Request for a single answer in an attempt
class CreateAttemptAnswerRequest {
  final int questionId;
  final String questionText;
  final String questionType;
  final int? userAnswer;
  final List<int>? userAnswers;
  final int? correctAnswer;
  final List<int>? correctAnswers;
  final List<String> options;
  final bool isCorrect;

  const CreateAttemptAnswerRequest({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    this.userAnswer,
    this.userAnswers,
    this.correctAnswer,
    this.correctAnswers,
    required this.options,
    required this.isCorrect,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'question_text': questionText,
      'question_type': questionType,
      if (userAnswer != null) 'user_answer': userAnswer,
      if (userAnswers != null) 'user_answers': userAnswers,
      if (correctAnswer != null) 'correct_answer': correctAnswer,
      if (correctAnswers != null) 'correct_answers': correctAnswers,
      'options': options,
      'is_correct': isCorrect,
    };
  }
}
