// Centralized limits for questionnaire validation
// Keep in sync with Go API limits in internal/models/limits.go

class QuizLimits {
  QuizLimits._(); // Prevent instantiation

  // Options per question
  static const int minOptions = 2;
  static const int maxOptions = 8;
  static const int defaultMaxOptions = 4;

  // Questions per questionnaire
  static const int maxQuestionsPerQuiz = 500;

  // Field lengths
  static const int maxTitleLength = 255;
  static const int maxDescriptionLength = 1000;

  // Alternative fields (for question variety)
  static const int maxAlternativeQuestions = 10;
  static const int maxAlternativeOptions = 20;
}

// Question type constants
// Keep in sync with Go API constants in internal/models/questionnaire.go
class QuestionTypes {
  QuestionTypes._(); // Prevent instantiation

  static const String singleChoice = 'single_choice';
  static const String multipleChoice = 'multiple_choice';
}
