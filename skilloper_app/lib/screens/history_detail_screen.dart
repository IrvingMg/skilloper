import 'package:flutter/material.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/date_formatter.dart';
import '../widgets/summary_card.dart';

class HistoryDetailScreen extends StatefulWidget {
  final int attemptId;

  const HistoryDetailScreen({required this.attemptId, super.key});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final ApiService _apiService = ApiService();
  QuizAttempt? _attempt;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttemptDetails();
  }

  Future<void> _loadAttemptDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final attempt = await _apiService.getAttemptDetails(widget.attemptId);
      setState(() {
        _attempt = attempt;
        _isLoading = false;
      });
    } on Exception catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.achievement;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attempt Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Loading details...',
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
              'Failed to load attempt details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadAttemptDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_attempt == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Score header
          Container(
            width: double.infinity,
            padding: AppSpacing.allXxxl,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${_attempt!.score}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _attempt!.quizTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    'Attempt #${_attempt!.attemptNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatFullDate(_attempt!.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: AppSpacing.allLg,
            child: Column(
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Score',
                        value: '${_attempt!.score}%',
                        color: _getScoreColor(_attempt!.score),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SummaryCard(
                        title: 'Correct',
                        value: '${_attempt!.correctCount}',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SummaryCard(
                        title: 'Incorrect',
                        value: '${_attempt!.incorrectCount}',
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total',
                        value: '${_attempt!.totalCount}',
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Section title
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Question Review',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Question review
                ...List.generate(
                  _attempt!.answers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _AnswerReviewCard(
                      questionNumber: index + 1,
                      answer: _attempt!.answers[index],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  final int questionNumber;
  final AttemptAnswer answer;

  const _AnswerReviewCard({required this.questionNumber, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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

          // Content
          Padding(
            padding: AppSpacing.allLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                Text(
                  answer.questionText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Answers
                if (answer.isMultipleChoice) ...[
                  _buildMultipleChoiceAnswers(),
                ] else ...[
                  _buildSingleChoiceAnswers(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleChoiceAnswers() {
    if (!answer.isCorrect &&
        answer.userAnswer != null &&
        answer.correctAnswer != null) {
      // Show both user and correct answers
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _AnswerDisplay(
              label: 'Your answer',
              answers: [answer.userAnswer!],
              options: answer.options,
              isCorrect: false,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _AnswerDisplay(
              label: 'Correct answer',
              answers: [answer.correctAnswer!],
              options: answer.options,
              isCorrect: true,
            ),
          ),
        ],
      );
    } else if (answer.userAnswer != null) {
      // Show only user answer (correct)
      return _AnswerDisplay(
        label: answer.isCorrect ? 'Your answer (Correct)' : 'Your answer',
        answers: [answer.userAnswer!],
        options: answer.options,
        isCorrect: answer.isCorrect,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMultipleChoiceAnswers() {
    if (!answer.isCorrect &&
        answer.userAnswers != null &&
        answer.userAnswers!.isNotEmpty &&
        answer.correctAnswers != null) {
      // Show both user and correct answers
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _AnswerDisplay(
              label: 'Your answers',
              answers: answer.userAnswers!,
              options: answer.options,
              isCorrect: false,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _AnswerDisplay(
              label: 'Correct answers',
              answers: answer.correctAnswers!,
              options: answer.options,
              isCorrect: true,
            ),
          ),
        ],
      );
    } else if (answer.userAnswers != null && answer.userAnswers!.isNotEmpty) {
      // Show only user answers (correct)
      return _AnswerDisplay(
        label: answer.isCorrect ? 'Your answers (Correct)' : 'Your answers',
        answers: answer.userAnswers!,
        options: answer.options,
        isCorrect: answer.isCorrect,
      );
    }
    return const SizedBox.shrink();
  }
}

class _AnswerDisplay extends StatelessWidget {
  final String label;
  final List<int> answers;
  final List<String> options;
  final bool isCorrect;

  const _AnswerDisplay({
    required this.label,
    required this.answers,
    required this.options,
    required this.isCorrect,
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
                ...answers.map((answerIndex) {
                  if (answerIndex >= 0 && answerIndex < options.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '${String.fromCharCode(65 + answerIndex)}. ${options[answerIndex]}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
