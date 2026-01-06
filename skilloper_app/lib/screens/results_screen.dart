import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../widgets/code_block.dart';
import '../widgets/summary_card.dart';

class ResultsScreen extends StatefulWidget {
  final Quiz quiz;
  final List<UserAnswerRequest> userAnswers;
  final int? attemptId;

  const ResultsScreen({
    super.key,
    required this.quiz,
    required this.userAnswers,
    this.attemptId,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();

  bool _isLoading = true;
  QuizAttempt? _completedAttempt;
  String? _error;
  int? _createdAttemptId; // Track locally created attempt to avoid duplicates on retry

  @override
  void initState() {
    super.initState();
    _completeAttempt();
  }

  Future<void> _completeAttempt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use widget's attemptId, or locally created one, or create new
      int? attemptId = widget.attemptId ?? _createdAttemptId;

      // Create attempt if we don't have one (practice mode always, exam mode if it failed earlier)
      if (attemptId == null) {
        final deviceId = await _deviceService.getDeviceId();
        final startRequest = StartAttemptRequest(
          deviceId: deviceId,
          quizId: widget.quiz.id,
          quizTitle: widget.quiz.title,
          quizType: widget.quiz.type,
          totalCount: widget.quiz.questions.length,
        );
        if (!mounted) return;
        try {
          final attempt = await _apiService.startAttempt(startRequest);
          attemptId = attempt.id;
          _createdAttemptId = attemptId; // Store for retry
        } catch (e) {
          // If attempt creation fails, show error
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = 'Failed to save results: $e';
            });
          }
          return;
        }
      }

      // Complete the attempt - server validates answers and calculates score
      final completeRequest = CompleteAttemptRequest(
        answers: widget.userAnswers,
      );

      final completedAttempt = await _apiService.completeAttempt(attemptId, completeRequest);

      if (mounted) {
        setState(() {
          _completedAttempt = completedAttempt;
          _isLoading = false;
        });
      }
    } catch (e) {
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
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Home'),
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
            SizedBox(height: 16),
            Text(
              'Calculating results...',
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
              'Failed to calculate results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _completeAttempt,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final attempt = _completedAttempt!;

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
                  '${attempt.score}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${attempt.correctCount} out of ${attempt.totalCount} questions correct',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Result saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
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
                        value: '${attempt.score}%',
                        color: _getScoreColor(attempt.score),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Correct',
                        value: '${attempt.correctCount}',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Incorrect',
                        value: '${attempt.totalCount - attempt.correctCount}',
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total',
                        value: '${attempt.totalCount}',
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

                // Question review from server-validated answers
                ...List.generate(
                  attempt.answers.length,
                  (index) {
                    final answer = attempt.answers[index];
                    // Find matching question by ID, or null if not found
                    final question = widget.quiz.questions
                        .where((q) => q.id == answer.questionId)
                        .firstOrNull;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AnswerReviewCard(
                        questionNumber: index + 1,
                        answer: answer,
                        question: question,
                      ),
                    );
                  },
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

                const SizedBox(height: 12),

                // Code block (if present and question found)
                if (question?.code != null) ...[
                  CodeBlock(
                    code: question!.code!,
                    language: question!.language,
                  ),
                  const SizedBox(height: 16),
                ],

                // Answers - Compact layout
                if (answer.isMultipleChoice) ...[
                  // Multiple choice answers
                  if (!answer.isCorrect &&
                      answer.userAnswers != null &&
                      answer.userAnswers!.isNotEmpty &&
                      answer.correctAnswers != null) ...[
                    // Show both user and correct answers side by side when incorrect
                    _CompactMultipleAnswerComparison(
                      userAnswers: answer.userAnswers!,
                      correctAnswers: answer.correctAnswers!,
                      options: answer.options,
                    ),
                  ] else if (answer.userAnswers != null && answer.userAnswers!.isNotEmpty) ...[
                    // Show only user answer when correct
                    _MultipleAnswerDisplay(
                      label: answer.isCorrect ? 'Your answers (Correct)' : 'Your answers',
                      userAnswers: answer.userAnswers!,
                      options: answer.options,
                      isCorrect: answer.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ] else ...[
                  // Single choice answers
                  if (!answer.isCorrect &&
                      answer.userAnswer != null &&
                      answer.correctAnswer != null) ...[
                    // Show both user and correct answers side by side when incorrect
                    _CompactAnswerComparison(
                      userAnswer: answer.userAnswer!,
                      correctAnswer: answer.correctAnswer!,
                      options: answer.options,
                    ),
                  ] else if (answer.userAnswer != null &&
                      answer.userAnswer! >= 0 &&
                      answer.userAnswer! < answer.options.length) ...[
                    // Show only user answer when correct
                    _AnswerDisplay(
                      label: answer.isCorrect ? 'Your answer (Correct)' : 'Your answer',
                      option: String.fromCharCode(65 + answer.userAnswer!),
                      text: answer.options[answer.userAnswer!],
                      isCorrect: answer.isCorrect,
                      isUserAnswer: true,
                    ),
                  ],
                ],
                const SizedBox(height: 8),

                // Explanation (if question found and has explanation)
                if (question?.explanation != null) ...[
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
                          question!.explanation!,
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
                ...userAnswers
                    .where((i) => i >= 0 && i < options.length)
                    .map((answerIndex) => Padding(
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
    // Bounds check for safety
    final userAnswerValid = userAnswer >= 0 && userAnswer < options.length;
    final correctAnswerValid = correctAnswer >= 0 && correctAnswer < options.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User answer (incorrect)
        if (userAnswerValid)
          Expanded(
            child: _AnswerDisplay(
              label: 'Your answer',
              option: String.fromCharCode(65 + userAnswer),
              text: options[userAnswer],
              isCorrect: false,
              isUserAnswer: true,
            ),
          ),
        if (userAnswerValid && correctAnswerValid) const SizedBox(width: 8),
        // Correct answer
        if (correctAnswerValid)
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