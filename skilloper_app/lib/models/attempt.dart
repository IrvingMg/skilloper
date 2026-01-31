enum AttemptStatus {
  inProgress,
  completed,
  abandoned;

  static AttemptStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return AttemptStatus.inProgress;
      case 'completed':
        return AttemptStatus.completed;
      case 'abandoned':
        return AttemptStatus.abandoned;
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
      case AttemptStatus.abandoned:
        return 'abandoned';
    }
  }
}

class AttemptSummary {
  final int id;
  final int userId;
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
    required this.userId,
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
    final id = json['id'];
    final createdAt = json['created_at'];

    if (id == null) {
      throw const FormatException('AttemptSummary missing required field: id');
    }
    if (createdAt == null) {
      throw const FormatException(
        'AttemptSummary missing required field: created_at',
      );
    }

    return AttemptSummary(
      id: id is int ? id : int.parse(id.toString()),
      userId: (json['user_id'] as int?) ?? 0,
      quizId: (json['quiz_id'] as int?) ?? 0,
      quizTitle: (json['quiz_title'] ?? 'Unknown Quiz').toString(),
      quizType: (json['quiz_type'] ?? 'practice').toString(),
      attemptNumber: (json['attempt_number'] as int?) ?? 1,
      status: AttemptStatus.fromString(
        (json['status'] ?? 'in_progress').toString(),
      ),
      score: (json['score'] as int?) ?? 0,
      correctCount: (json['correct_count'] as int?) ?? 0,
      totalCount: (json['total_count'] as int?) ?? 0,
      createdAt: DateTime.parse(createdAt.toString()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'].toString())
          : null,
    );
  }

  bool get isPracticeMode => quizType == 'practice';
  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;
  bool get isAbandoned => status == AttemptStatus.abandoned;
  int get incorrectCount => totalCount - correctCount;
}

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
    required this.options,
    required this.isCorrect,
    this.userAnswer,
    this.userAnswers,
    this.correctAnswer,
    this.correctAnswers,
  });

  factory AttemptAnswer.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final questionId = json['question_id'];

    if (id == null) {
      throw const FormatException('AttemptAnswer missing required field: id');
    }
    if (questionId == null) {
      throw const FormatException(
        'AttemptAnswer missing required field: question_id',
      );
    }

    return AttemptAnswer(
      id: id is int ? id : int.parse(id.toString()),
      questionId: questionId is int
          ? questionId
          : int.parse(questionId.toString()),
      questionText: (json['question_text'] ?? '').toString(),
      questionType: (json['question_type'] ?? 'single_choice').toString(),
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
      isCorrect: (json['is_correct'] as bool?) ?? false,
    );
  }

  bool get isMultipleChoice => questionType == 'multiple_choice';
  bool get isSingleChoice => questionType == 'single_choice';
}

class QuizAttempt {
  final int id;
  final int userId;
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
    required this.userId,
    required this.quizId,
    required this.quizTitle,
    required this.quizType,
    required this.attemptNumber,
    required this.status,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.createdAt,
    required this.answers,
    this.completedAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['created_at'];

    if (id == null) {
      throw const FormatException('QuizAttempt missing required field: id');
    }
    if (createdAt == null) {
      throw const FormatException(
        'QuizAttempt missing required field: created_at',
      );
    }

    return QuizAttempt(
      id: id is int ? id : int.parse(id.toString()),
      userId: (json['user_id'] as int?) ?? 0,
      quizId: (json['quiz_id'] as int?) ?? 0,
      quizTitle: (json['quiz_title'] ?? 'Unknown Quiz').toString(),
      quizType: (json['quiz_type'] ?? 'practice').toString(),
      attemptNumber: (json['attempt_number'] as int?) ?? 1,
      status: AttemptStatus.fromString(
        (json['status'] ?? 'in_progress').toString(),
      ),
      score: (json['score'] as int?) ?? 0,
      correctCount: (json['correct_count'] as int?) ?? 0,
      totalCount: (json['total_count'] as int?) ?? 0,
      createdAt: DateTime.parse(createdAt.toString()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'].toString())
          : null,
      answers:
          (json['answers'] as List?)
              ?.map((a) => AttemptAnswer.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isPracticeMode => quizType == 'practice';
  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;
  bool get isAbandoned => status == AttemptStatus.abandoned;
  int get incorrectCount => totalCount - correctCount;
}

class StartAttemptRequest {
  final int quizId;

  const StartAttemptRequest({required this.quizId});

  Map<String, dynamic> toJson() {
    return {'quiz_id': quizId};
  }
}

/// Displayed question data with randomized text and options from the server
class DisplayedQuestionData {
  final int questionId;
  final String questionText;
  final List<String> options;

  const DisplayedQuestionData({
    required this.questionId,
    required this.questionText,
    required this.options,
  });

  factory DisplayedQuestionData.fromJson(Map<String, dynamic> json) {
    final questionId = json['question_id'];
    if (questionId == null) {
      throw const FormatException(
        'DisplayedQuestionData missing required field: question_id',
      );
    }

    return DisplayedQuestionData(
      questionId: questionId is int
          ? questionId
          : int.parse(questionId.toString()),
      questionText: (json['question_text'] ?? '').toString(),
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : [],
    );
  }
}

/// Response from starting an attempt, includes displayed questions with randomized variants
class AttemptStartResponse {
  final int id;
  final int quizId;
  final AttemptStatus status;
  final DateTime createdAt;
  final List<DisplayedQuestionData> displayedQuestions;

  const AttemptStartResponse({
    required this.id,
    required this.quizId,
    required this.status,
    required this.createdAt,
    required this.displayedQuestions,
  });

  factory AttemptStartResponse.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['created_at'];

    if (id == null) {
      throw const FormatException(
        'AttemptStartResponse missing required field: id',
      );
    }
    if (createdAt == null) {
      throw const FormatException(
        'AttemptStartResponse missing required field: created_at',
      );
    }

    return AttemptStartResponse(
      id: id is int ? id : int.parse(id.toString()),
      quizId: (json['quiz_id'] as int?) ?? 0,
      status: AttemptStatus.fromString(
        (json['status'] ?? 'in_progress').toString(),
      ),
      createdAt: DateTime.parse(createdAt.toString()),
      displayedQuestions:
          (json['displayed_questions'] as List?)
              ?.map(
                (q) =>
                    DisplayedQuestionData.fromJson(q as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class CompleteAttemptRequest {
  final List<UserAnswerRequest> answers;

  const CompleteAttemptRequest({required this.answers});

  Map<String, dynamic> toJson() {
    return {'answers': answers.map((a) => a.toJson()).toList()};
  }
}

class UserAnswerRequest {
  final int questionId;
  final int? userAnswer; // For single_choice
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

class ValidateAnswerRequest {
  final int? userAnswer; // For single_choice
  final List<int>? userAnswers; // For multiple_choice

  const ValidateAnswerRequest({this.userAnswer, this.userAnswers});

  Map<String, dynamic> toJson() {
    return {
      if (userAnswer != null) 'user_answer': userAnswer,
      if (userAnswers != null) 'user_answers': userAnswers,
    };
  }
}

class ValidateAnswerResponse {
  final bool isCorrect;
  final int? correctAnswer; // For single_choice
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
