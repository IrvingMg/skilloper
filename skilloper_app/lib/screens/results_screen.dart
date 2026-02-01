import 'package:flutter/material.dart';

import '../models/attempt.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/code_block.dart';
import '../widgets/floating_score_header.dart';
import '../widgets/summary_card.dart';

class ResultsScreen extends StatefulWidget {
  final Quiz quiz;
  final List<UserAnswerRequest> userAnswers;
  final int? attemptId;

  const ResultsScreen({
    required this.quiz,
    required this.userAnswers,
    super.key,
    this.attemptId,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  late QuizAttempt _completedAttempt;
  String? _error;

  @override
  void initState() {
    super.initState();
    assert(widget.attemptId != null, 'ResultsScreen requires an attemptId');
    _completeAttempt();
  }

  Future<void> _completeAttempt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final attemptId = widget.attemptId!;

    try {
      final completeRequest = CompleteAttemptRequest(
        answers: widget.userAnswers,
      );

      final completedAttempt = await _apiService.completeAttempt(
        attemptId,
        completeRequest,
      );

      if (mounted) {
        setState(() {
          _completedAttempt = completedAttempt;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (_) => false),
            tooltip: 'Home',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Calculating results...',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Failed to calculate results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _completeAttempt,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final attempt = _completedAttempt;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          floating: true,
          delegate: FloatingScoreHeaderDelegate(
            header: FloatingScoreHeader(
              score: attempt.score,
              subtitle:
                  '${attempt.correctCount} out of ${attempt.totalCount} questions correct',
              showSavedIndicator: true,
            ),
          ),
        ),
        SliverPadding(
          padding: AppSpacing.allLg,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    final scoreCard = SummaryCard(
                      title: 'Score',
                      value: '${attempt.score}%',
                      color: _getScoreColor(attempt.score),
                    );
                    final correctCard = SummaryCard(
                      title: 'Correct',
                      value: '${attempt.correctCount}',
                      color: AppColors.success,
                    );
                    final incorrectCard = SummaryCard(
                      title: 'Incorrect',
                      value: '${attempt.totalCount - attempt.correctCount}',
                      color: AppColors.error,
                    );
                    final totalCard = SummaryCard(
                      title: 'Total',
                      value: '${attempt.totalCount}',
                      color: AppColors.textTertiary,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: scoreCard),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: correctCard),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: incorrectCard),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: totalCard),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: scoreCard),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: correctCard),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: incorrectCard),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: totalCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  'Question Review',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final answer = attempt.answers[index];
              final questionIndex = widget.quiz.questions.indexWhere(
                (q) => q.id == answer.questionId,
              );
              final question = questionIndex >= 0
                  ? widget.quiz.questions[questionIndex]
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _AnswerReviewCard(
                  questionNumber: questionIndex >= 0
                      ? questionIndex + 1
                      : index + 1,
                  answer: answer,
                  question: question,
                ),
              );
            }, childCount: attempt.answers.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (_) => false),
                        icon: const Icon(Icons.home),
                        label: const Text('Back to Home'),
                        style: ElevatedButton.styleFrom(
                          padding: AppSpacing.verticalLg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.achievement;
    return AppColors.error;
  }
}

/// Review card for server-validated answers
class _AnswerReviewCard extends StatelessWidget {
  final int questionNumber;
  final AttemptAnswer answer;
  final Question? question; // Nullable - may not find matching question

  const _AnswerReviewCard({
    required this.questionNumber,
    required this.answer,
    this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.allLg,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: answer.isCorrect
                        ? AppColors.successContainer
                        : AppColors.errorContainer,
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    answer.isCorrect ? 'Correct' : 'Incorrect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: answer.isCorrect
                          ? AppColors.onSuccessContainer
                          : AppColors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: AppSpacing.allLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.questionText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                if (question?.code != null) ...[
                  CodeBlock(
                    code: question!.code!,
                    language: question!.language,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (answer.isMultipleChoice) ...[
                  if (!answer.isCorrect &&
                      answer.userAnswers != null &&
                      answer.userAnswers!.isNotEmpty &&
                      answer.correctAnswers != null) ...[
                    _CompactMultipleAnswerComparison(
                      userAnswers: answer.userAnswers!,
                      correctAnswers: answer.correctAnswers!,
                      options: answer.options,
                    ),
                  ] else if (answer.userAnswers != null &&
                      answer.userAnswers!.isNotEmpty) ...[
                    _MultipleAnswerDisplay(
                      label: answer.isCorrect
                          ? 'Your answers (Correct)'
                          : 'Your answers',
                      userAnswers: answer.userAnswers!,
                      options: answer.options,
                      isCorrect: answer.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ] else ...[
                  if (!answer.isCorrect &&
                      answer.userAnswer != null &&
                      answer.correctAnswer != null) ...[
                    _CompactAnswerComparison(
                      userAnswer: answer.userAnswer!,
                      correctAnswer: answer.correctAnswer!,
                      options: answer.options,
                    ),
                  ] else if (answer.userAnswer != null &&
                      answer.userAnswer! >= 0 &&
                      answer.userAnswer! < answer.options.length) ...[
                    _AnswerDisplay(
                      label: answer.isCorrect
                          ? 'Your answer (Correct)'
                          : 'Your answer',
                      option: String.fromCharCode(65 + answer.userAnswer!),
                      text: answer.options[answer.userAnswer!],
                      isCorrect: answer.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.sm),

                if (question?.explanation != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.allLg,
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.info, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outlined,
                              color: AppColors.info,
                              size: AppIconSizes.md,
                            ),
                            SizedBox(width: AppSpacing.sm),
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
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          question!.explanation!,
                          style: const TextStyle(
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
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
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
            size: AppIconSizes.lg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$option. $text',
                  style: const TextStyle(
                    fontSize: 15,
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
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
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
            size: AppIconSizes.lg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...userAnswers
                    .where((i) => i >= 0 && i < options.length)
                    .map(
                      (answerIndex) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          '${String.fromCharCode(65 + answerIndex)}. ${options[answerIndex]}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
    final userAnswerValid = userAnswer >= 0 && userAnswer < options.length;
    final correctAnswerValid =
        correctAnswer >= 0 && correctAnswer < options.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final userDisplay = userAnswerValid
            ? _AnswerDisplay(
                label: 'Your answer',
                option: String.fromCharCode(65 + userAnswer),
                text: options[userAnswer],
                isCorrect: false,
                isUserAnswer: true,
              )
            : null;
        final correctDisplay = correctAnswerValid
            ? _AnswerDisplay(
                label: 'Correct answer',
                option: String.fromCharCode(65 + correctAnswer),
                text: options[correctAnswer],
                isCorrect: true,
                isUserAnswer: false,
              )
            : null;

        if (isNarrow) {
          return Column(
            children: [
              if (userDisplay != null) userDisplay,
              if (userDisplay != null && correctDisplay != null)
                const SizedBox(height: AppSpacing.sm),
              if (correctDisplay != null) correctDisplay,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userDisplay != null) Expanded(child: userDisplay),
            if (userDisplay != null && correctDisplay != null)
              const SizedBox(width: AppSpacing.sm),
            if (correctDisplay != null) Expanded(child: correctDisplay),
          ],
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final userDisplay = _MultipleAnswerDisplay(
          label: 'Your answers',
          userAnswers: userAnswers,
          options: options,
          isCorrect: false,
          isUserAnswer: true,
        );
        final correctDisplay = _MultipleAnswerDisplay(
          label: 'Correct answers',
          userAnswers: correctAnswers,
          options: options,
          isCorrect: true,
          isUserAnswer: false,
        );

        if (isNarrow) {
          return Column(
            children: [
              userDisplay,
              const SizedBox(height: AppSpacing.sm),
              correctDisplay,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: userDisplay),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: correctDisplay),
          ],
        );
      },
    );
  }
}
