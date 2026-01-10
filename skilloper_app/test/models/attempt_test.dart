import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/models/attempt.dart';

void main() {
  group('AttemptStatus', () {
    test('fromString parses in_progress', () {
      expect(AttemptStatus.fromString('in_progress'), AttemptStatus.inProgress);
    });

    test('fromString parses completed', () {
      expect(AttemptStatus.fromString('completed'), AttemptStatus.completed);
    });

    test('fromString parses abandoned', () {
      expect(AttemptStatus.fromString('abandoned'), AttemptStatus.abandoned);
    });

    test('fromString defaults to inProgress for unknown value', () {
      expect(AttemptStatus.fromString('unknown'), AttemptStatus.inProgress);
      expect(AttemptStatus.fromString(''), AttemptStatus.inProgress);
      expect(AttemptStatus.fromString('garbage'), AttemptStatus.inProgress);
    });

    test('toJson converts inProgress to in_progress', () {
      expect(AttemptStatus.inProgress.toJson(), 'in_progress');
    });

    test('toJson converts completed to completed', () {
      expect(AttemptStatus.completed.toJson(), 'completed');
    });

    test('toJson converts abandoned to abandoned', () {
      expect(AttemptStatus.abandoned.toJson(), 'abandoned');
    });
  });

  group('AttemptSummary.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 1,
        'user_id': 42,
        'quiz_id': 5,
        'quiz_title': 'Go Basics',
        'quiz_type': 'practice',
        'attempt_number': 2,
        'status': 'completed',
        'score': 80,
        'correct_count': 8,
        'total_count': 10,
        'created_at': '2024-01-15T10:30:00Z',
        'completed_at': '2024-01-15T10:45:00Z',
      };

      final summary = AttemptSummary.fromJson(json);

      expect(summary.id, 1);
      expect(summary.userId, 42);
      expect(summary.quizId, 5);
      expect(summary.quizTitle, 'Go Basics');
      expect(summary.quizType, 'practice');
      expect(summary.attemptNumber, 2);
      expect(summary.status, AttemptStatus.completed);
      expect(summary.score, 80);
      expect(summary.correctCount, 8);
      expect(summary.totalCount, 10);
      expect(summary.createdAt, DateTime.utc(2024, 1, 15, 10, 30, 0));
      expect(summary.completedAt, DateTime.utc(2024, 1, 15, 10, 45, 0));
    });

    test('handles null completedAt for in-progress attempt', () {
      final json = {
        'id': 1,
        'user_id': 42,
        'quiz_id': 5,
        'quiz_title': 'Go Basics',
        'quiz_type': 'exam',
        'attempt_number': 1,
        'status': 'in_progress',
        'score': 0,
        'correct_count': 0,
        'total_count': 10,
        'created_at': '2024-01-15T10:30:00Z',
        'completed_at': null,
      };

      final summary = AttemptSummary.fromJson(json);

      expect(summary.status, AttemptStatus.inProgress);
      expect(summary.completedAt, isNull);
    });
  });

  group('AttemptAnswer.fromJson', () {
    test('parses single choice answer', () {
      final json = {
        'id': 1,
        'question_id': 10,
        'question_text': 'What is 2+2?',
        'question_type': 'single_choice',
        'user_answer': 1,
        'correct_answer': 1,
        'options': ['3', '4', '5', '6'],
        'is_correct': true,
      };

      final answer = AttemptAnswer.fromJson(json);

      expect(answer.id, 1);
      expect(answer.questionId, 10);
      expect(answer.questionText, 'What is 2+2?');
      expect(answer.questionType, 'single_choice');
      expect(answer.userAnswer, 1);
      expect(answer.userAnswers, isNull);
      expect(answer.correctAnswer, 1);
      expect(answer.correctAnswers, isNull);
      expect(answer.options, ['3', '4', '5', '6']);
      expect(answer.isCorrect, isTrue);
      expect(answer.isSingleChoice, isTrue);
      expect(answer.isMultipleChoice, isFalse);
    });

    test('parses multiple choice answer', () {
      final json = {
        'id': 2,
        'question_id': 11,
        'question_text': 'Select primes',
        'question_type': 'multiple_choice',
        'user_answers': [0, 1, 3],
        'correct_answers': [0, 1, 3],
        'options': ['2', '3', '4', '5'],
        'is_correct': true,
      };

      final answer = AttemptAnswer.fromJson(json);

      expect(answer.userAnswer, isNull);
      expect(answer.userAnswers, [0, 1, 3]);
      expect(answer.correctAnswer, isNull);
      expect(answer.correctAnswers, [0, 1, 3]);
      expect(answer.isMultipleChoice, isTrue);
      expect(answer.isSingleChoice, isFalse);
    });

    test('defaults question_type to single_choice when missing', () {
      final json = {
        'id': 3,
        'question_id': 12,
        'question_text': 'Test',
        'user_answer': 0,
        'correct_answer': 1,
        'options': ['A', 'B'],
        'is_correct': false,
      };

      final answer = AttemptAnswer.fromJson(json);

      expect(answer.questionType, 'single_choice');
      expect(answer.isSingleChoice, isTrue);
    });

    test('handles null options as empty list', () {
      final json = {
        'id': 4,
        'question_id': 13,
        'question_text': 'Test',
        'options': null,
        'is_correct': false,
      };

      final answer = AttemptAnswer.fromJson(json);

      expect(answer.options, isEmpty);
    });
  });

  group('QuizAttempt.fromJson', () {
    test('parses attempt with answers array', () {
      final json = {
        'id': 1,
        'user_id': 42,
        'quiz_id': 5,
        'quiz_title': 'Go Quiz',
        'quiz_type': 'practice',
        'attempt_number': 1,
        'status': 'completed',
        'score': 100,
        'correct_count': 2,
        'total_count': 2,
        'created_at': '2024-01-15T10:30:00Z',
        'completed_at': '2024-01-15T10:35:00Z',
        'answers': [
          {
            'id': 1,
            'question_id': 10,
            'question_text': 'Q1',
            'question_type': 'single_choice',
            'user_answer': 0,
            'correct_answer': 0,
            'options': ['A', 'B'],
            'is_correct': true,
          },
          {
            'id': 2,
            'question_id': 11,
            'question_text': 'Q2',
            'question_type': 'multiple_choice',
            'user_answers': [0, 1],
            'correct_answers': [0, 1],
            'options': ['A', 'B', 'C'],
            'is_correct': true,
          },
        ],
      };

      final attempt = QuizAttempt.fromJson(json);

      expect(attempt.id, 1);
      expect(attempt.status, AttemptStatus.completed);
      expect(attempt.answers.length, 2);
      expect(attempt.answers[0].isSingleChoice, isTrue);
      expect(attempt.answers[1].isMultipleChoice, isTrue);
    });

    test('handles null answers as empty list', () {
      final json = {
        'id': 1,
        'user_id': 42,
        'quiz_id': 5,
        'quiz_title': 'Quiz',
        'quiz_type': 'exam',
        'attempt_number': 1,
        'status': 'in_progress',
        'score': 0,
        'correct_count': 0,
        'total_count': 5,
        'created_at': '2024-01-15T10:30:00Z',
        'answers': null,
      };

      final attempt = QuizAttempt.fromJson(json);

      expect(attempt.answers, isEmpty);
    });
  });

  group('StartAttemptRequest', () {
    test('toJson serializes quiz_id', () {
      const request = StartAttemptRequest(quizId: 42);
      final json = request.toJson();

      expect(json['quiz_id'], 42);
      expect(json.length, 1);
    });
  });

  group('CompleteAttemptRequest', () {
    test('toJson serializes answers list', () {
      const request = CompleteAttemptRequest(
        answers: [
          UserAnswerRequest(questionId: 1, userAnswer: 2),
          UserAnswerRequest(questionId: 2, userAnswers: [0, 1]),
        ],
      );
      final json = request.toJson();

      expect(json['answers'], hasLength(2));
      expect(json['answers'][0]['question_id'], 1);
      expect(json['answers'][1]['question_id'], 2);
    });
  });

  group('UserAnswerRequest', () {
    test('toJson includes only userAnswer for single choice', () {
      const request = UserAnswerRequest(questionId: 1, userAnswer: 2);
      final json = request.toJson();

      expect(json['question_id'], 1);
      expect(json['user_answer'], 2);
      expect(json.containsKey('user_answers'), isFalse);
    });

    test('toJson includes only userAnswers for multiple choice', () {
      const request = UserAnswerRequest(questionId: 2, userAnswers: [0, 1, 3]);
      final json = request.toJson();

      expect(json['question_id'], 2);
      expect(json['user_answers'], [0, 1, 3]);
      expect(json.containsKey('user_answer'), isFalse);
    });
  });

  group('ValidateAnswerRequest', () {
    test('toJson includes only userAnswer for single choice', () {
      const request = ValidateAnswerRequest(userAnswer: 1);
      final json = request.toJson();

      expect(json['user_answer'], 1);
      expect(json.containsKey('user_answers'), isFalse);
    });

    test('toJson includes only userAnswers for multiple choice', () {
      const request = ValidateAnswerRequest(userAnswers: [0, 2]);
      final json = request.toJson();

      expect(json['user_answers'], [0, 2]);
      expect(json.containsKey('user_answer'), isFalse);
    });

    test('toJson is empty when neither set', () {
      const request = ValidateAnswerRequest();
      final json = request.toJson();

      expect(json, isEmpty);
    });
  });

  group('ValidateAnswerResponse', () {
    test('fromJson parses single choice answer', () {
      final json = {'is_correct': true, 'correct_answer': 2};

      final response = ValidateAnswerResponse.fromJson(json);

      expect(response.isCorrect, isTrue);
      expect(response.correctAnswer, 2);
      expect(response.correctAnswers, isNull);
    });

    test('fromJson parses multiple choice answer', () {
      final json = {
        'is_correct': false,
        'correct_answers': [0, 1, 3],
      };

      final response = ValidateAnswerResponse.fromJson(json);

      expect(response.isCorrect, isFalse);
      expect(response.correctAnswer, isNull);
      expect(response.correctAnswers, [0, 1, 3]);
    });
  });
}
