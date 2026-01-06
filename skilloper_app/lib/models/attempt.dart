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
  final int quizId;
  final String quizTitle;
  final String quizType;
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
    required this.quizId,
    required this.quizTitle,
    required this.quizType,
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
      quizId: json['quiz_id'] as int,
      quizTitle: json['quiz_title'] as String,
      quizType: json['quiz_type'] as String,
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

  bool get isPracticeMode => quizType == 'practice';
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
  final int quizId;
  final String quizTitle;
  final String quizType;
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
    required this.quizId,
    required this.quizTitle,
    required this.quizType,
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
      quizId: json['quiz_id'] as int,
      quizTitle: json['quiz_title'] as String,
      quizType: json['quiz_type'] as String,
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

  bool get isPracticeMode => quizType == 'practice';
  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;
  int get incorrectCount => totalCount - correctCount;
}

/// Request to start a new attempt
class StartAttemptRequest {
  final String deviceId;
  final int quizId;
  final String quizTitle;
  final String quizType;
  final int totalCount;

  const StartAttemptRequest({
    required this.deviceId,
    required this.quizId,
    required this.quizTitle,
    required this.quizType,
    required this.totalCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'quiz_id': quizId,
      'quiz_title': quizTitle,
      'quiz_type': quizType,
      'total_count': totalCount,
    };
  }
}

/// Request to complete an attempt - server validates answers and calculates score
class CompleteAttemptRequest {
  final List<UserAnswerRequest> answers;

  const CompleteAttemptRequest({
    required this.answers,
  });

  Map<String, dynamic> toJson() {
    return {
      'answers': answers.map((a) => a.toJson()).toList(),
    };
  }
}

/// User's answer to a single question - server will validate
class UserAnswerRequest {
  final int questionId;
  final int? userAnswer;      // For single_choice
  final List<int>? userAnswers; // For multiple_choice

  const UserAnswerRequest({
    required this.questionId,
    this.userAnswer,
    this.userAnswers,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      if (userAnswer != null) 'user_answer': userAnswer,
      if (userAnswers != null) 'user_answers': userAnswers,
    };
  }
}

/// Request to validate a single answer (practice mode)
class ValidateAnswerRequest {
  final int? userAnswer;      // For single_choice
  final List<int>? userAnswers; // For multiple_choice

  const ValidateAnswerRequest({
    this.userAnswer,
    this.userAnswers,
  });

  Map<String, dynamic> toJson() {
    return {
      if (userAnswer != null) 'user_answer': userAnswer,
      if (userAnswers != null) 'user_answers': userAnswers,
    };
  }
}

/// Response from validating a single answer (practice mode)
class ValidateAnswerResponse {
  final bool isCorrect;
  final int? correctAnswer;       // For single_choice
  final List<int>? correctAnswers; // For multiple_choice

  const ValidateAnswerResponse({
    required this.isCorrect,
    this.correctAnswer,
    this.correctAnswers,
  });

  factory ValidateAnswerResponse.fromJson(Map<String, dynamic> json) {
    return ValidateAnswerResponse(
      isCorrect: json['is_correct'] as bool,
      correctAnswer: json['correct_answer'] as int?,
      correctAnswers: json['correct_answers'] != null
          ? List<int>.from(json['correct_answers'] as List)
          : null,
    );
  }
}
