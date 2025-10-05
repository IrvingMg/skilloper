import 'package:flutter/material.dart';
import '../models/questionnaire.dart';
import '../theme/app_colors.dart';
import '../widgets/code_block.dart';

class ResultsScreen extends StatelessWidget {
  final Questionnaire questionnaire;
  final QuizResult results;

  const ResultsScreen({
    super.key,
    required this.questionnaire,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Home'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Score header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${results.score}%',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${results.correct} out of ${results.total} questions correct',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Score',
                          value: '${results.score}%',
                          color: _getScoreColor(results.score),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Correct',
                          value: '${results.correct}',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Incorrect',
                          value: '${results.total - results.correct}',
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total',
                          value: '${results.total}',
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section title
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Question Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Question review
                  ...List.generate(
                    results.questionResults.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _QuestionReviewCard(
                        questionNumber: index + 1,
                        result: results.questionResults[index],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.popUntil(
                            context, 
                            (route) => route.isFirst,
                          ),
                          icon: const Icon(Icons.home),
                          label: const Text('Back to Home'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.achievement;
    return AppColors.error;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final int questionNumber;
  final QuestionResult result;

  const _QuestionReviewCard({
    required this.questionNumber,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: result.isCorrect
                        ? AppColors.successContainer
                        : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.isCorrect ? 'Correct' : 'Incorrect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: result.isCorrect
                          ? AppColors.onSuccessContainer
                          : AppColors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                Text(
                  result.question.question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                // Code block (if present)
                if (result.question.code != null) ...[
                  CodeBlock(
                    code: result.question.code!,
                    language: result.question.language,
                  ),
                  const SizedBox(height: 16),
                ],

                // Answers - Compact layout
                if (result.question.isMultipleChoice) ...[
                  // Multiple choice answers
                  if (!result.isCorrect &&
                      result.userAnswers != null &&
                      result.userAnswers!.isNotEmpty &&
                      result.question.correctAnswers != null) ...[
                    // Show both user and correct answers side by side when incorrect
                    _CompactMultipleAnswerComparison(
                      userAnswers: result.userAnswers!,
                      correctAnswers: result.question.correctAnswers!,
                      options: result.question.options,
                    ),
                  ] else if (result.userAnswers != null && result.userAnswers!.isNotEmpty) ...[
                    // Show only user answer when correct or no correct answer available
                    _MultipleAnswerDisplay(
                      label: result.isCorrect ? 'Your answers (Correct)' : 'Your answers',
                      userAnswers: result.userAnswers!,
                      options: result.question.options,
                      isCorrect: result.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ] else ...[
                  // Single choice answers
                  if (!result.isCorrect &&
                      result.userAnswer != null &&
                      result.question.correctAnswer != null) ...[
                    // Show both user and correct answers side by side when incorrect
                    _CompactAnswerComparison(
                      userAnswer: result.userAnswer!,
                      correctAnswer: result.question.correctAnswer!,
                      options: result.question.options,
                    ),
                  ] else if (result.userAnswer != null) ...[
                    // Show only user answer when correct or no correct answer available
                    _AnswerDisplay(
                      label: result.isCorrect ? 'Your answer (Correct)' : 'Your answer',
                      option: String.fromCharCode(65 + result.userAnswer!),
                      text: result.question.options[result.userAnswer!],
                      isCorrect: result.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ],
                const SizedBox(height: 8),

                // Explanation
                if (result.question.explanation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outlined,
                              color: AppColors.info,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Explanation',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onInfoContainer,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          result.question.explanation!,
                          style: TextStyle(
                            color: AppColors.onInfoContainer,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerDisplay extends StatelessWidget {
  final String label;
  final String option;
  final String text;
  final bool isCorrect;
  final bool isUserAnswer;

  const _AnswerDisplay({
    required this.label,
    required this.option,
    required this.text,
    required this.isCorrect,
    required this.isUserAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$option. $text',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MultipleAnswerDisplay extends StatelessWidget {
  final String label;
  final List<int> userAnswers;
  final List<String> options;
  final bool isCorrect;
  final bool isUserAnswer;

  const _MultipleAnswerDisplay({
    required this.label,
    required this.userAnswers,
    required this.options,
    required this.isCorrect,
    required this.isUserAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                ...userAnswers.map((answerIndex) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${String.fromCharCode(65 + answerIndex)}. ${options[answerIndex]}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAnswerComparison extends StatelessWidget {
  final int userAnswer;
  final int correctAnswer;
  final List<String> options;

  const _CompactAnswerComparison({
    required this.userAnswer,
    required this.correctAnswer,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User answer (incorrect)
        Expanded(
          child: _AnswerDisplay(
            label: 'Your answer',
            option: String.fromCharCode(65 + userAnswer),
            text: options[userAnswer],
            isCorrect: false,
            isUserAnswer: true,
          ),
        ),
        const SizedBox(width: 8),
        // Correct answer
        Expanded(
          child: _AnswerDisplay(
            label: 'Correct answer',
            option: String.fromCharCode(65 + correctAnswer),
            text: options[correctAnswer],
            isCorrect: true,
            isUserAnswer: false,
          ),
        ),
      ],
    );
  }
}

class _CompactMultipleAnswerComparison extends StatelessWidget {
  final List<int> userAnswers;
  final List<int> correctAnswers;
  final List<String> options;

  const _CompactMultipleAnswerComparison({
    required this.userAnswers,
    required this.correctAnswers,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User answers (incorrect)
        Expanded(
          child: _MultipleAnswerDisplay(
            label: 'Your answers',
            userAnswers: userAnswers,
            options: options,
            isCorrect: false,
            isUserAnswer: true,
          ),
        ),
        const SizedBox(width: 8),
        // Correct answers
        Expanded(
          child: _MultipleAnswerDisplay(
            label: 'Correct answers',
            userAnswers: correctAnswers,
            options: options,
            isCorrect: true,
            isUserAnswer: false,
          ),
        ),
      ],
    );
  }
}