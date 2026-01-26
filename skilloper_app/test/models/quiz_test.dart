import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/models/quiz.dart';

void main() {
  group('Question.fromJson', () {
    test('parses single choice question', () {
      final json = {
        'id': 1,
        'question_type': 'single_choice',
        'question': 'What is 2 + 2?',
        'options': ['3', '4', '5', '6'],
        'correct_answer': 1,
        'explanation': 'Basic math',
      };

      final question = Question.fromJson(json);

      expect(question.id, 1);
      expect(question.questionType, 'single_choice');
      expect(question.question, 'What is 2 + 2?');
      expect(question.options, ['3', '4', '5', '6']);
      expect(question.correctAnswer, 1);
      expect(question.correctAnswers, isNull);
      expect(question.explanation, 'Basic math');
      expect(question.isSingleChoice, isTrue);
      expect(question.isMultipleChoice, isFalse);
    });

    test('parses multiple choice question', () {
      final json = {
        'id': 2,
        'question_type': 'multiple_choice',
        'question': 'Select all prime numbers',
        'options': ['2', '3', '4', '5'],
        'correct_answers': [0, 1, 3],
      };

      final question = Question.fromJson(json);

      expect(question.id, 2);
      expect(question.questionType, 'multiple_choice');
      expect(question.correctAnswer, isNull);
      expect(question.correctAnswers, [0, 1, 3]);
      expect(question.isMultipleChoice, isTrue);
      expect(question.isSingleChoice, isFalse);
    });

    test('parses question with code block', () {
      final json = {
        'id': 3,
        'question_type': 'single_choice',
        'question': 'What does this print?',
        'code': 'print("Hello")',
        'language': 'python',
        'options': ['Hello', 'World'],
        'correctAnswer': 0,
      };

      final question = Question.fromJson(json);

      expect(question.code, 'print("Hello")');
      expect(question.language, 'python');
    });

    test('defaults question_type to single_choice when missing', () {
      final json = {
        'id': 4,
        'question': 'Test question',
        'options': ['A', 'B'],
        'correctAnswer': 0,
      };

      final question = Question.fromJson(json);

      expect(question.questionType, 'single_choice');
      expect(question.isSingleChoice, isTrue);
    });

    test('handles null options as empty list', () {
      final json = {'id': 5, 'question': 'Test', 'options': null};

      final question = Question.fromJson(json);

      expect(question.options, isEmpty);
    });

    test('throws FormatException when id is null', () {
      final json = {
        'question': 'Test',
        'options': ['A', 'B'],
      };

      expect(
        () => Question.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('throws FormatException when question is null', () {
      final json = {
        'id': 1,
        'options': ['A', 'B'],
      };

      expect(
        () => Question.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('question'),
          ),
        ),
      );
    });

    test('handles string id by parsing to int', () {
      final json = {'id': '42', 'question': 'Test'};

      final question = Question.fromJson(json);

      expect(question.id, 42);
    });
  });

  group('QuizSummary.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 1,
        'title': 'Go Basics',
        'description': 'Learn Go fundamentals',
        'type': 'practice',
        'max_options': 4,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-16T14:00:00Z',
        'question_count': 10,
      };

      final summary = QuizSummary.fromJson(json);

      expect(summary.id, 1);
      expect(summary.title, 'Go Basics');
      expect(summary.description, 'Learn Go fundamentals');
      expect(summary.type, 'practice');
      expect(summary.maxOptions, 4);
      expect(summary.questionCount, 10);
      expect(summary.createdAt, DateTime.utc(2024, 1, 15, 10, 30, 0));
      expect(summary.updatedAt, DateTime.utc(2024, 1, 16, 14, 0, 0));
    });

    test('uses defaults for optional fields', () {
      final json = {
        'id': 1,
        'title': 'Test Quiz',
        'created_at': '2024-01-15T10:30:00Z',
      };

      final summary = QuizSummary.fromJson(json);

      expect(summary.description, '');
      expect(summary.type, 'practice');
      expect(summary.maxOptions, 4);
      expect(summary.questionCount, 0);
    });

    test('uses created_at as fallback for updated_at', () {
      final json = {
        'id': 1,
        'title': 'Test Quiz',
        'created_at': '2024-01-15T10:30:00Z',
      };

      final summary = QuizSummary.fromJson(json);

      expect(summary.createdAt, summary.updatedAt);
    });

    test('throws FormatException when id is null', () {
      final json = {'title': 'Test Quiz', 'created_at': '2024-01-15T10:30:00Z'};

      expect(
        () => QuizSummary.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('throws FormatException when title is null', () {
      final json = {'id': 1, 'created_at': '2024-01-15T10:30:00Z'};

      expect(
        () => QuizSummary.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('title'),
          ),
        ),
      );
    });

    test('throws FormatException when created_at is null', () {
      final json = {'id': 1, 'title': 'Test Quiz'};

      expect(
        () => QuizSummary.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('created_at'),
          ),
        ),
      );
    });
  });

  group('Quiz.fromJson', () {
    test('parses quiz with questions array', () {
      final json = {
        'id': 1,
        'title': 'Test Quiz',
        'description': 'A test quiz',
        'type': 'exam',
        'max_options': 4,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
        'questions': [
          {
            'id': 1,
            'question_type': 'single_choice',
            'question': 'Q1',
            'options': ['A', 'B'],
            'correctAnswer': 0,
          },
          {
            'id': 2,
            'question_type': 'multiple_choice',
            'question': 'Q2',
            'options': ['A', 'B', 'C'],
            'correct_answers': [0, 2],
          },
        ],
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.id, 1);
      expect(quiz.title, 'Test Quiz');
      expect(quiz.type, 'exam');
      expect(quiz.questions.length, 2);
      expect(quiz.questions[0].isSingleChoice, isTrue);
      expect(quiz.questions[1].isMultipleChoice, isTrue);
    });

    test('defaults max_options to 4 when missing', () {
      final json = {
        'id': 1,
        'title': 'Quiz',
        'description': 'Desc',
        'type': 'practice',
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
        'questions': <Map<String, Object?>>[],
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.maxOptions, 4);
    });

    test('handles empty questions list', () {
      final json = {
        'id': 1,
        'title': 'Empty Quiz',
        'description': 'No questions',
        'type': 'practice',
        'max_options': 4,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
        'questions': <Map<String, Object?>>[],
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.questions, isEmpty);
    });

    test('isPracticeMode returns true for practice type', () {
      final json = {
        'id': 1,
        'title': 'Quiz',
        'description': '',
        'type': 'practice',
        'max_options': 4,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
        'questions': <Map<String, Object?>>[],
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.isPracticeMode, isTrue);
    });

    test('estimatedMinutes calculates correctly', () {
      final json = {
        'id': 1,
        'title': 'Quiz',
        'description': '',
        'type': 'exam',
        'max_options': 4,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
        'questions': [
          {
            'id': 1,
            'question': 'Q1',
            'options': ['A', 'B'],
          },
          {
            'id': 2,
            'question': 'Q2',
            'options': ['A', 'B'],
          },
          {
            'id': 3,
            'question': 'Q3',
            'options': ['A', 'B'],
          },
          {
            'id': 4,
            'question': 'Q4',
            'options': ['A', 'B'],
          },
        ],
      };

      final quiz = Quiz.fromJson(json);

      // 4 questions * 1.5 minutes = 6 minutes
      expect(quiz.estimatedMinutes, 6);
    });
  });

  group('QuizResult', () {
    test('percentage calculates correctly', () {
      const result = QuizResult(
        score: 80,
        correct: 8,
        total: 10,
        questionResults: <QuestionResult>[],
      );
      expect(result.percentage, 80.0);
    });

    test('percentage handles all correct', () {
      const result = QuizResult(
        score: 100,
        correct: 5,
        total: 5,
        questionResults: <QuestionResult>[],
      );
      expect(result.percentage, 100.0);
    });

    test('percentage handles none correct', () {
      const result = QuizResult(
        score: 0,
        correct: 0,
        total: 10,
        questionResults: <QuestionResult>[],
      );
      expect(result.percentage, 0.0);
    });

    test('percentage handles fractional result', () {
      const result = QuizResult(
        score: 33,
        correct: 1,
        total: 3,
        questionResults: <QuestionResult>[],
      );
      expect(result.percentage, closeTo(33.33, 0.01));
    });
  });
}
