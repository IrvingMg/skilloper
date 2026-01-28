import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/models/draft_quiz.dart';
import 'package:skilloper_app/models/quiz.dart';

void main() {
  group('DraftQuestion', () {
    group('isValid and validationError', () {
      test('invalid when question is empty', () {
        final q = DraftQuestion(
          question: '',
          options: ['A', 'B'],
          correctAnswers: [1],
        );
        expect(q.isValid, isFalse);
        expect(q.validationError, 'Question text required');
      });

      test('invalid when question is only whitespace', () {
        final q = DraftQuestion(
          question: '   ',
          options: ['A', 'B'],
          correctAnswers: [1],
        );
        expect(q.isValid, isFalse);
        expect(q.validationError, 'Question text required');
      });

      test('invalid when less than 2 non-empty options', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', ''],
          correctAnswers: [1],
        );
        expect(q.isValid, isFalse);
        expect(q.validationError, 'At least 2 options required');
      });

      test('invalid when no correct answer selected', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', 'B'],
          correctAnswers: [],
        );
        expect(q.isValid, isFalse);
        expect(q.validationError, 'Select correct answer');
      });

      test('invalid when answer points to empty option', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', '', 'C'],
          correctAnswers: [2], // Points to empty option
        );
        expect(q.isValid, isFalse);
        expect(q.validationError, 'Invalid answer selection');
      });

      test('valid question passes all checks', () {
        final q = DraftQuestion(
          question: 'What is 2+2?',
          options: ['3', '4', '5'],
          correctAnswers: [2],
        );
        expect(q.isValid, isTrue);
        expect(q.validationError, isNull);
      });

      test('valid multiple choice question', () {
        final q = DraftQuestion(
          question: 'Select primes',
          options: ['2', '3', '4', '5'],
          correctAnswers: [1, 2, 4],
          questionType: 'multiple_choice',
        );
        expect(q.isValid, isTrue);
        expect(q.validationError, isNull);
      });
    });

    group('setSingleAnswer', () {
      test('sets single correct answer', () {
        final q = DraftQuestion();
        q.setSingleAnswer(2);
        expect(q.correctAnswers, [2]);
        expect(q.singleAnswer, 2);
      });

      test('replaces previous answer', () {
        final q = DraftQuestion(correctAnswers: [1]);
        q.setSingleAnswer(3);
        expect(q.correctAnswers, [3]);
      });
    });

    group('toggleAnswer', () {
      test('adds answer when not present', () {
        final q = DraftQuestion(correctAnswers: [1]);
        q.toggleAnswer(3);
        expect(q.correctAnswers, [1, 3]);
      });

      test('removes answer when present', () {
        final q = DraftQuestion(correctAnswers: [1, 2, 3]);
        q.toggleAnswer(2);
        expect(q.correctAnswers, [1, 3]);
      });

      test('maintains sorted order', () {
        final q = DraftQuestion(correctAnswers: [1, 4]);
        q.toggleAnswer(2);
        expect(q.correctAnswers, [1, 2, 4]);
      });
    });

    group('addOption and removeOption', () {
      test('addOption adds empty option', () {
        final q = DraftQuestion(options: ['A', 'B']);
        q.addOption();
        expect(q.options.length, 3);
        expect(q.options[2], '');
      });

      test('removeOption removes option and adjusts answers', () {
        final q = DraftQuestion(
          options: ['A', 'B', 'C', 'D'],
          correctAnswers: [2, 4], // B and D selected (1-based)
        );
        q.removeOption(1); // Remove 'B' (0-indexed)
        expect(q.options, ['A', 'C', 'D']);
        // Answer 2 was removed, answer 4 becomes 3
        expect(q.correctAnswers, [3]);
      });

      test(
        'removeOption adjusts answers correctly when removing earlier option',
        () {
          final q = DraftQuestion(
            options: ['A', 'B', 'C', 'D'],
            correctAnswers: [3, 4], // C and D selected (1-based)
          );
          q.removeOption(0); // Remove 'A' (0-indexed)
          expect(q.options, ['B', 'C', 'D']);
          // Both answers shift down by 1
          expect(q.correctAnswers, [2, 3]);
        },
      );

      test('removeOption does not remove below minimum', () {
        final q = DraftQuestion(options: ['A', 'B']);
        q.removeOption(0);
        expect(q.options.length, 2); // Still 2 (minimum)
      });
    });

    group('toJson', () {
      test('converts single choice to correct JSON format', () {
        final q = DraftQuestion(
          question: 'What is 2+2?',
          options: ['3', '4', '5'],
          correctAnswers: [2], // 1-based
          questionType: 'single_choice',
        );
        final json = q.toJson();
        expect(json['question'], 'What is 2+2?');
        expect(json['options'], ['3', '4', '5']);
        expect(json['correctAnswer'], 1); // 0-based
        expect(json['question_type'], 'single_choice');
        expect(json.containsKey('correct_answers'), isFalse);
      });

      test('converts multiple choice to correct JSON format', () {
        final q = DraftQuestion(
          question: 'Select primes',
          options: ['2', '3', '4', '5'],
          correctAnswers: [1, 2, 4], // 1-based
          questionType: 'multiple_choice',
        );
        final json = q.toJson();
        expect(json['correct_answers'], [0, 1, 3]); // 0-based
        expect(json['question_type'], 'multiple_choice');
        expect(json.containsKey('correctAnswer'), isFalse);
      });

      test('filters out empty options and remaps answers', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', '', 'C', 'D'],
          correctAnswers: [3, 4], // C and D (1-based)
          questionType: 'multiple_choice',
        );
        final json = q.toJson();
        expect(json['options'], ['A', 'C', 'D']); // Empty filtered
        // C was at index 3 (1-based), now at index 1 (0-based)
        // D was at index 4 (1-based), now at index 2 (0-based)
        expect(json['correct_answers'], [1, 2]);
      });

      test('includes optional fields when non-empty', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', 'B'],
          correctAnswers: [1],
          explanation: 'Because...',
          code: 'print("hello")',
          language: 'python',
          alternativeQuestions: ['Alt question'],
          extraOptions: ['Extra option'],
          optionVariants: [
            ['Alt A'],
            ['Alt B'],
          ],
        );
        final json = q.toJson();
        expect(json['explanation'], 'Because...');
        expect(json['code'], 'print("hello")');
        expect(json['language'], 'python');
        expect(json['alternative_questions'], ['Alt question']);
        expect(json['extra_options'], ['Extra option']);
        expect(json['option_variants'], [
          ['Alt A'],
          ['Alt B'],
        ]);
      });

      test('excludes optional fields when empty', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', 'B'],
          correctAnswers: [1],
        );
        final json = q.toJson();
        expect(json.containsKey('explanation'), isFalse);
        expect(json.containsKey('code'), isFalse);
        expect(json.containsKey('language'), isFalse);
      });

      test('throws when no valid answers after remapping', () {
        final q = DraftQuestion(
          question: 'Test?',
          options: ['A', '', 'C'],
          correctAnswers: [2], // Points to empty option
        );
        expect(q.toJson, throwsStateError);
      });
    });

    group('fromQuestion', () {
      test('converts single choice from API format', () {
        const apiQuestion = Question(
          id: 1,
          questionType: 'single_choice',
          question: 'What is 2+2?',
          options: ['3', '4', '5'],
          correctAnswer: 1, // 0-based
          explanation: 'Basic math',
        );
        final draft = DraftQuestion.fromQuestion(apiQuestion);
        expect(draft.question, 'What is 2+2?');
        expect(draft.options, ['3', '4', '5']);
        expect(draft.correctAnswers, [2]); // 1-based
        expect(draft.explanation, 'Basic math');
        expect(draft.questionType, 'single_choice');
      });

      test('converts multiple choice from API format', () {
        const apiQuestion = Question(
          id: 2,
          questionType: 'multiple_choice',
          question: 'Select primes',
          options: ['2', '3', '4', '5'],
          correctAnswers: [0, 1, 3], // 0-based
        );
        final draft = DraftQuestion.fromQuestion(apiQuestion);
        expect(draft.correctAnswers, [1, 2, 4]); // 1-based
        expect(draft.questionType, 'multiple_choice');
      });

      test('handles missing optional fields', () {
        const apiQuestion = Question(
          id: 3,
          questionType: 'single_choice',
          question: 'Test?',
          options: ['A', 'B'],
          correctAnswer: 0,
        );
        final draft = DraftQuestion.fromQuestion(apiQuestion);
        expect(draft.explanation, '');
        expect(draft.code, '');
        expect(draft.language, '');
      });
    });

    group('copy', () {
      test('creates independent copy', () {
        final original = DraftQuestion(
          question: 'Test?',
          options: ['A', 'B'],
          correctAnswers: [1],
        );
        final copy = original.copy();

        copy.question = 'Changed';
        copy.options.add('C');
        copy.correctAnswers.add(2);

        expect(original.question, 'Test?');
        expect(original.options.length, 2);
        expect(original.correctAnswers.length, 1);
      });
    });

    group('isMultipleChoice and singleAnswer', () {
      test('isMultipleChoice returns true for multiple_choice type', () {
        final q = DraftQuestion(questionType: 'multiple_choice');
        expect(q.isMultipleChoice, isTrue);
      });

      test('isMultipleChoice returns false for single_choice type', () {
        final q = DraftQuestion(questionType: 'single_choice');
        expect(q.isMultipleChoice, isFalse);
      });

      test('singleAnswer returns value when exactly one answer', () {
        final q = DraftQuestion(correctAnswers: [3]);
        expect(q.singleAnswer, 3);
      });

      test('singleAnswer returns null when multiple answers', () {
        final q = DraftQuestion(correctAnswers: [1, 2]);
        expect(q.singleAnswer, isNull);
      });
    });
  });

  group('DraftQuiz', () {
    group('isValid', () {
      test('invalid when title is empty', () {
        final quiz = DraftQuiz(
          title: '',
          questions: [
            DraftQuestion(
              question: 'Test?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        expect(quiz.isValid, isFalse);
      });

      test('invalid when no questions', () {
        final quiz = DraftQuiz(title: 'Test Quiz', questions: []);
        expect(quiz.isValid, isFalse);
      });

      test('invalid when any question is invalid', () {
        final quiz = DraftQuiz(
          title: 'Test Quiz',
          questions: [
            DraftQuestion(
              question: 'Valid?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: '', // Invalid
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        expect(quiz.isValid, isFalse);
      });

      test('valid when all conditions met', () {
        final quiz = DraftQuiz(
          title: 'Test Quiz',
          questions: [
            DraftQuestion(
              question: 'Question 1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Question 2?',
              options: ['X', 'Y', 'Z'],
              correctAnswers: [2],
            ),
          ],
        );
        expect(quiz.isValid, isTrue);
      });
    });

    group('validQuestionCount', () {
      test('counts only valid questions', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: '',
              options: ['A', 'B'],
              correctAnswers: [1],
            ), // Invalid
            DraftQuestion(
              question: 'Q3?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        expect(quiz.validQuestionCount, 2);
      });
    });

    group('isEditMode', () {
      test('returns false when id is null', () {
        final quiz = DraftQuiz(title: 'New Quiz');
        expect(quiz.isEditMode, isFalse);
      });

      test('returns true when id is set', () {
        final quiz = DraftQuiz(id: 42, title: 'Existing Quiz');
        expect(quiz.isEditMode, isTrue);
      });
    });

    group('moveQuestionUp and moveQuestionDown', () {
      test('moveQuestionUp swaps with previous', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q2?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q3?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.moveQuestionUp(1);
        expect(quiz.questions[0].question, 'Q2?');
        expect(quiz.questions[1].question, 'Q1?');
      });

      test('moveQuestionUp does nothing at index 0', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q2?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.moveQuestionUp(0);
        expect(quiz.questions[0].question, 'Q1?');
      });

      test('moveQuestionDown swaps with next', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q2?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q3?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.moveQuestionDown(0);
        expect(quiz.questions[0].question, 'Q2?');
        expect(quiz.questions[1].question, 'Q1?');
      });

      test('moveQuestionDown does nothing at last index', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q2?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.moveQuestionDown(1);
        expect(quiz.questions[1].question, 'Q2?');
      });
    });

    group('toJson', () {
      test('produces correct JSON structure', () {
        final quiz = DraftQuiz(
          title: 'Test Quiz',
          description: 'A description',
          type: 'exam',
          maxOptions: 6,
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        final json = quiz.toJson();
        expect(json['title'], 'Test Quiz');
        expect(json['description'], 'A description');
        expect(json['type'], 'exam');
        expect(json['max_options'], 6);
        expect(json['questions'], hasLength(1));
      });

      test('excludes empty description', () {
        final quiz = DraftQuiz(
          title: 'Test',
          description: '',
          questions: [
            DraftQuestion(
              question: 'Q?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        final json = quiz.toJson();
        expect(json.containsKey('description'), isFalse);
      });
    });

    group('clear', () {
      test('resets all fields to defaults', () {
        final quiz = DraftQuiz(
          id: 42,
          title: 'Test',
          description: 'Desc',
          type: 'exam',
          maxOptions: 6,
          questions: [
            DraftQuestion(
              question: 'Q?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.clear();
        expect(quiz.id, isNull);
        expect(quiz.title, '');
        expect(quiz.description, '');
        expect(quiz.type, 'practice');
        expect(quiz.maxOptions, 4);
        expect(quiz.questions, isEmpty);
      });
    });

    group('addQuestion and removeQuestion', () {
      test('addQuestion appends new empty question', () {
        final quiz = DraftQuiz(title: 'Test');
        quiz.addQuestion();
        expect(quiz.questions.length, 1);
        expect(quiz.questions[0].question, '');
      });

      test('removeQuestion removes at valid index', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
            DraftQuestion(
              question: 'Q2?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.removeQuestion(0);
        expect(quiz.questions.length, 1);
        expect(quiz.questions[0].question, 'Q2?');
      });

      test('removeQuestion does nothing at invalid index', () {
        final quiz = DraftQuiz(
          title: 'Test',
          questions: [
            DraftQuestion(
              question: 'Q1?',
              options: ['A', 'B'],
              correctAnswers: [1],
            ),
          ],
        );
        quiz.removeQuestion(5); // Out of bounds
        expect(quiz.questions.length, 1);
      });
    });
  });
}
