// Draft questionnaire model for the create quiz wizard
// Uses 1-based indexing for user-friendly display
// Serializes to simplified JSON format for API submission

import '../constants/limits.dart';

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
  })  : alternativeQuestions = alternativeQuestions ?? [],
        options = options ?? ['', ''],
        alternativeOptions = alternativeOptions ?? [],
        correctAnswers = correctAnswers ?? [],
        alternativeAnswers = alternativeAnswers ?? [];

  /// Whether this is a multiple choice question (multiple correct answers)
  bool get isMultipleChoice => correctAnswers.length > 1;

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
  bool get isValid {
    if (question.trim().isEmpty) return false;
    if (options.where((o) => o.trim().isNotEmpty).length < 2) return false;
    if (correctAnswers.isEmpty) return false;
    // Check all answers are valid indices
    final validOptions = options
        .asMap()
        .entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => e.key + 1)
        .toList();
    return correctAnswers.every((a) => validOptions.contains(a));
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

  /// Convert to simple JSON format for API
  /// Answer is always an array of strings (1-based indices)
  Map<String, dynamic> toJson() {
    // Filter out empty options and build mapping
    final nonEmptyOptions = <String>[];
    final indexMapping = <int, int>{}; // old 1-based -> new 1-based

    for (var i = 0; i < options.length; i++) {
      if (options[i].trim().isNotEmpty) {
        nonEmptyOptions.add(options[i]);
        indexMapping[i + 1] = nonEmptyOptions.length;
      }
    }

    // Remap correct answers to new indices as strings
    final remappedAnswers = correctAnswers
        .where((a) => indexMapping.containsKey(a))
        .map((a) => indexMapping[a]!.toString())
        .toList();

    // Safety check - should not happen if isValid was checked first
    if (remappedAnswers.isEmpty) {
      throw StateError('No valid answers after remapping - call isValid before toJson');
    }

    final json = <String, dynamic>{
      'question': question,
      'options': nonEmptyOptions,
      'answer': remappedAnswers, // Always array of strings
    };

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
    );
  }
}

class DraftQuestionnaire {
  String title;
  String description;
  String type; // 'practice' or 'exam'
  int maxOptions; // Maximum options per question (2-8)
  List<DraftQuestion> questions;

  DraftQuestionnaire({
    this.title = '',
    this.description = '',
    this.type = 'practice',
    this.maxOptions = 4, // Default to 4, range is 2-8
    List<DraftQuestion>? questions,
  }) : questions = questions ?? [];

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
    title = '';
    description = '';
    type = 'practice';
    maxOptions = 4;
    questions.clear();
  }
}
