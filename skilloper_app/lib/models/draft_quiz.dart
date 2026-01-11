import '../constants/limits.dart';
import 'quiz.dart';

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
  }) : alternativeQuestions = alternativeQuestions ?? [],
       options = options ?? ['', ''],
       alternativeOptions = alternativeOptions ?? [],
       correctAnswers = correctAnswers ?? [],
       alternativeAnswers = alternativeAnswers ?? [];

  bool get isMultipleChoice => questionType == QuestionTypes.multipleChoice;

  int? get singleAnswer =>
      correctAnswers.length == 1 ? correctAnswers.first : null;

  void setSingleAnswer(int answer) {
    correctAnswers = [answer];
  }

  void toggleAnswer(int answer) {
    if (correctAnswers.contains(answer)) {
      correctAnswers.remove(answer);
    } else {
      correctAnswers.add(answer);
      correctAnswers.sort();
    }
  }

  bool get isValid => validationError == null;

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
    if (!correctAnswers.every(validOptions.contains)) {
      return 'Invalid answer selection';
    }
    return null;
  }

  void addOption() {
    if (options.length < QuizLimits.maxOptions) {
      options.add('');
    }
  }

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
        .where(indexMapping.containsKey)
        .map((a) => indexMapping[a]!)
        .toList();

    // Safety check - should not happen if isValid was checked first
    if (remappedAnswers.isEmpty) {
      throw StateError(
        'No valid answers after remapping - call isValid before toJson',
      );
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
    final nonEmptyAltQuestions = alternativeQuestions
        .where((q) => q.trim().isNotEmpty)
        .toList();
    if (nonEmptyAltQuestions.isNotEmpty) {
      json['alternative_questions'] = nonEmptyAltQuestions;
    }

    final nonEmptyAltOptions = alternativeOptions
        .where((o) => o.trim().isNotEmpty)
        .toList();
    if (nonEmptyAltOptions.isNotEmpty) {
      json['alternative_options'] = nonEmptyAltOptions;
    }

    final nonEmptyAltAnswers = alternativeAnswers
        .where((a) => a.trim().isNotEmpty)
        .toList();
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

class DraftQuiz {
  int? id; // Set when editing an existing quiz
  String title;
  String description;
  String type; // 'practice' or 'exam'
  int maxOptions; // Maximum options per question (2-8)
  List<DraftQuestion> questions;

  DraftQuiz({
    this.id,
    this.title = '',
    this.description = '',
    this.type = 'practice',
    this.maxOptions = 4, // Default to 4, range is 2-8
    List<DraftQuestion>? questions,
  }) : questions = questions ?? [];

  bool get isEditMode => id != null;

  void loadFromQuiz(Quiz q) {
    id = q.id;
    title = q.title;
    description = q.description;
    type = q.type;
    maxOptions = q.maxOptions;
    questions = q.questions.map(DraftQuestion.fromQuestion).toList();
  }

  bool get isValid {
    if (title.trim().isEmpty) return false;
    if (questions.isEmpty) return false;
    return questions.every((q) => q.isValid);
  }

  int get validQuestionCount => questions.where((q) => q.isValid).length;

  void addQuestion() {
    questions.add(DraftQuestion());
  }

  void removeQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      questions.removeAt(index);
    }
  }

  void moveQuestionUp(int index) {
    if (index > 0 && index < questions.length) {
      final q = questions.removeAt(index);
      questions.insert(index - 1, q);
    }
  }

  void moveQuestionDown(int index) {
    if (index >= 0 && index < questions.length - 1) {
      final q = questions.removeAt(index);
      questions.insert(index + 1, q);
    }
  }

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

  void clear() {
    id = null;
    title = '';
    description = '';
    type = 'practice';
    maxOptions = 4;
    questions.clear();
  }
}
