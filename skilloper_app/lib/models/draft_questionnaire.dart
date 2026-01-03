// Draft questionnaire model for the create quiz wizard
// Uses 1-based indexing for user-friendly display
// Serializes to simplified JSON format for API submission

import '../constants/limits.dart';
import 'questionnaire.dart';

class DraftQuestion {
  String question;
  List<String> alternativeQuestions; // Alternative phrasings
  List<String> options;
  List<String> alternativeOptions; // Additional options for variety
  List<int> correctAnswers; // 1-based indices
  List<String> alternativeAnswers; // Alternative correct answer texts
  String explanation;
  String code;
  String language;
  String questionType; // 'single_choice' or 'multiple_choice'

  DraftQuestion({
    this.question = '',
    List<String>? alternativeQuestions,
    List<String>? options,
    List<String>? alternativeOptions,
    List<int>? correctAnswers,
    List<String>? alternativeAnswers,
    this.explanation = '',
    this.code = '',
    this.language = '',
    this.questionType = 'single_choice',
  })  : alternativeQuestions = alternativeQuestions ?? [],
        options = options ?? ['', ''],
        alternativeOptions = alternativeOptions ?? [],
        correctAnswers = correctAnswers ?? [],
        alternativeAnswers = alternativeAnswers ?? [];

  /// Whether this is a multiple choice question
  bool get isMultipleChoice => questionType == QuestionTypes.multipleChoice;

  /// For single choice, get the single correct answer (1-based)
  int? get singleAnswer =>
      correctAnswers.length == 1 ? correctAnswers.first : null;

  /// Set as single choice with given answer (1-based)
  void setSingleAnswer(int answer) {
    correctAnswers = [answer];
  }

  /// Toggle an answer for multiple choice (1-based)
  void toggleAnswer(int answer) {
    if (correctAnswers.contains(answer)) {
      correctAnswers.remove(answer);
    } else {
      correctAnswers.add(answer);
      correctAnswers.sort();
    }
  }

  /// Check if question is valid
  bool get isValid => validationError == null;

  /// Get validation error message, or null if valid
  String? get validationError {
    if (question.trim().isEmpty) {
      return 'Question text required';
    }
    final nonEmptyOptions = options.where((o) => o.trim().isNotEmpty).length;
    if (nonEmptyOptions < 2) {
      return 'At least 2 options required';
    }
    if (correctAnswers.isEmpty) {
      return 'Select correct answer';
    }
    // Check all answers are valid indices
    final validOptions = options
        .asMap()
        .entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => e.key + 1)
        .toList();
    if (!correctAnswers.every((a) => validOptions.contains(a))) {
      return 'Invalid answer selection';
    }
    return null;
  }

  /// Add an empty option
  void addOption() {
    if (options.length < QuizLimits.maxOptions) {
      options.add('');
    }
  }

  /// Remove an option and adjust correct answers
  void removeOption(int index) {
    if (options.length > QuizLimits.minOptions) {
      options.removeAt(index);
      // Adjust correct answers (1-based)
      final removed = index + 1;
      correctAnswers = correctAnswers
          .where((a) => a != removed)
          .map((a) => a > removed ? a - 1 : a)
          .toList();
    }
  }

  /// Convert to API JSON format for creating/updating questionnaires
  /// Uses 0-based indices for correctAnswer/correct_answers as required by backend
  Map<String, dynamic> toJson() {
    // Filter out empty options and build mapping
    final nonEmptyOptions = <String>[];
    final indexMapping = <int, int>{}; // old 1-based -> new 0-based

    for (var i = 0; i < options.length; i++) {
      if (options[i].trim().isNotEmpty) {
        nonEmptyOptions.add(options[i]);
        indexMapping[i + 1] = nonEmptyOptions.length - 1; // 0-based index
      }
    }

    // Remap correct answers to new 0-based indices
    final remappedAnswers = correctAnswers
        .where((a) => indexMapping.containsKey(a))
        .map((a) => indexMapping[a]!)
        .toList();

    // Safety check - should not happen if isValid was checked first
    if (remappedAnswers.isEmpty) {
      throw StateError('No valid answers after remapping - call isValid before toJson');
    }

    final json = <String, dynamic>{
      'question': question,
      'options': nonEmptyOptions,
      'question_type': questionType,
    };

    // Use correctAnswer for single choice, correct_answers for multiple choice
    if (questionType == QuestionTypes.multipleChoice) {
      json['correct_answers'] = remappedAnswers;
    } else {
      json['correctAnswer'] = remappedAnswers.first;
    }

    // Alternative texts
    final nonEmptyAltQuestions =
        alternativeQuestions.where((q) => q.trim().isNotEmpty).toList();
    if (nonEmptyAltQuestions.isNotEmpty) {
      json['alternative_questions'] = nonEmptyAltQuestions;
    }

    final nonEmptyAltOptions =
        alternativeOptions.where((o) => o.trim().isNotEmpty).toList();
    if (nonEmptyAltOptions.isNotEmpty) {
      json['alternative_options'] = nonEmptyAltOptions;
    }

    final nonEmptyAltAnswers =
        alternativeAnswers.where((a) => a.trim().isNotEmpty).toList();
    if (nonEmptyAltAnswers.isNotEmpty) {
      json['alternative_answers'] = nonEmptyAltAnswers;
    }

    if (explanation.trim().isNotEmpty) {
      json['explanation'] = explanation;
    }
    if (code.trim().isNotEmpty) {
      json['code'] = code;
    }
    if (language.trim().isNotEmpty) {
      json['language'] = language;
    }

    return json;
  }

  /// Create a copy of this question
  DraftQuestion copy() {
    return DraftQuestion(
      question: question,
      alternativeQuestions: List.from(alternativeQuestions),
      options: List.from(options),
      alternativeOptions: List.from(alternativeOptions),
      correctAnswers: List.from(correctAnswers),
      alternativeAnswers: List.from(alternativeAnswers),
      explanation: explanation,
      code: code,
      language: language,
      questionType: questionType,
    );
  }

  /// Create a DraftQuestion from an API Question object
  /// Note: Alternative questions/options/answers are not preserved as they're not in API response
  factory DraftQuestion.fromQuestion(Question q) {
    // Convert correct answers from 0-based to 1-based indexing
    List<int> answers;
    if (q.isMultipleChoice && q.correctAnswers != null) {
      // Multiple choice: convert each answer from 0-based to 1-based
      answers = q.correctAnswers!.map((a) => a + 1).toList();
    } else if (q.correctAnswer != null) {
      // Single choice: convert from 0-based to 1-based
      answers = [q.correctAnswer! + 1];
    } else {
      answers = [];
    }

    return DraftQuestion(
      question: q.question,
      options: List<String>.from(q.options),
      correctAnswers: answers,
      explanation: q.explanation ?? '',
      code: q.code ?? '',
      language: q.language ?? '',
      questionType: q.questionType, // Preserve question type from API
    );
  }
}

class DraftQuestionnaire {
  int? id; // Set when editing an existing questionnaire
  String title;
  String description;
  String type; // 'practice' or 'exam'
  int maxOptions; // Maximum options per question (2-8)
  List<DraftQuestion> questions;

  DraftQuestionnaire({
    this.id,
    this.title = '',
    this.description = '',
    this.type = 'practice',
    this.maxOptions = 4, // Default to 4, range is 2-8
    List<DraftQuestion>? questions,
  }) : questions = questions ?? [];

  /// Whether this is an existing questionnaire being edited
  bool get isEditMode => id != null;

  /// Load data from an existing questionnaire for editing
  void loadFromQuestionnaire(Questionnaire q) {
    id = q.id;
    title = q.title;
    description = q.description;
    type = q.type;
    maxOptions = q.maxOptions;
    questions = q.questions.map((q) => DraftQuestion.fromQuestion(q)).toList();
  }

  /// Check if questionnaire is valid for submission
  bool get isValid {
    if (title.trim().isEmpty) return false;
    if (questions.isEmpty) return false;
    return questions.every((q) => q.isValid);
  }

  /// Get count of valid questions
  int get validQuestionCount => questions.where((q) => q.isValid).length;

  /// Add a new empty question
  void addQuestion() {
    questions.add(DraftQuestion());
  }

  /// Remove a question by index
  void removeQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      questions.removeAt(index);
    }
  }

  /// Move a question up
  void moveQuestionUp(int index) {
    if (index > 0 && index < questions.length) {
      final q = questions.removeAt(index);
      questions.insert(index - 1, q);
    }
  }

  /// Move a question down
  void moveQuestionDown(int index) {
    if (index >= 0 && index < questions.length - 1) {
      final q = questions.removeAt(index);
      questions.insert(index + 1, q);
    }
  }

  /// Convert to simplified JSON format for API submission
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'title': title,
      'type': type,
      'questions': questions.map((q) => q.toJson()).toList(),
    };

    if (description.trim().isNotEmpty) {
      json['description'] = description;
    }

    if (maxOptions > 0) {
      json['max_options'] = maxOptions;
    }

    return json;
  }

  /// Clear all data
  void clear() {
    id = null;
    title = '';
    description = '';
    type = 'practice';
    maxOptions = 4;
    questions.clear();
  }
}
