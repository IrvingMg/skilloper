import 'package:flutter/material.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/summary_card.dart';

class HistoryDetailScreen extends StatefulWidget {
  final int attemptId;

  const HistoryDetailScreen({
    super.key,
    required this.attemptId,
  });

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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.achievement;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attempt Details'),
      ),
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
            SizedBox(height: 16),
            Text(
              'Loading details...',
              style: TextStyle(color: Color(0xFF6B7280)),
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
            const SizedBox(height: 16),
            const Text(
              'Failed to load attempt details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAttemptDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_attempt == null) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return SingleChildScrollView(
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
                  '${_attempt!.score}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _attempt!.questionnaireTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Attempt #${_attempt!.attemptNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(_attempt!.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
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
                      child: SummaryCard(
                        title: 'Score',
                        value: '${_attempt!.score}%',
                        color: _getScoreColor(_attempt!.score),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Correct',
                        value: '${_attempt!.correctCount}',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Incorrect',
                        value: '${_attempt!.incorrectCount}',
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total',
                        value: '${_attempt!.totalCount}',
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
                  _attempt!.answers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AnswerReviewCard(
                      questionNumber: index + 1,
                      answer: _attempt!.answers[index],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
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

  const _AnswerReviewCard({
    required this.questionNumber,
    required this.answer,
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
              borderRadius: const BorderRadius.only(
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
                    color: answer.isCorrect
                        ? AppColors.successContainer
                        : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(16),
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

                const SizedBox(height: 16),

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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
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
                ...answers.map((answerIndex) {
                  if (answerIndex >= 0 && answerIndex < options.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${String.fromCharCode(65 + answerIndex)}. ${options[answerIndex]}',
                        style: TextStyle(
                          fontSize: 14,
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
