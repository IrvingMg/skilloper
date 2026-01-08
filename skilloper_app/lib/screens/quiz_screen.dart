import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../models/quiz.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../widgets/answer_button.dart';
import '../widgets/code_block.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final int? attemptId; // Pre-created attempt ID for exam mode

  const QuizScreen({
    super.key,
    required this.quiz,
    this.attemptId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ApiService _apiService = ApiService();

  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // For single choice (stores ORIGINAL indices)
  final Map<int, Set<int>> _userMultipleAnswers = {}; // For multiple choice (stores ORIGINAL indices)

  int? _attemptId; // Track the attempt ID for completion

  final Map<int, ValidateAnswerResponse> _validatedAnswers = {};
  bool _isValidating = false;

  // Shuffle mappings: questionId -> list of original indices in display order
  final Map<int, List<int>> _shuffleMappings = {};

  @override
  void initState() {
    super.initState();
    _initializeShuffleMappings();
    // Use pre-created attemptId if provided, otherwise create one (for practice mode)
    if (widget.attemptId != null) {
      _attemptId = widget.attemptId;
    } else {
      _startAttempt();
    }
  }

  /// Initialize shuffle mappings for all questions
  void _initializeShuffleMappings() {
    for (final question in widget.quiz.questions) {
      final indices = List.generate(question.options.length, (i) => i);
      indices.shuffle();
      _shuffleMappings[question.id] = indices;
    }
  }

  /// Get shuffled options for display
  List<String> _getShuffledOptions(Question question) {
    final mapping = _shuffleMappings[question.id]!;
    return mapping.map((i) => question.options[i]).toList();
  }

  /// Convert display index to original index
  int _toOriginalIndex(int questionId, int displayIndex) {
    return _shuffleMappings[questionId]![displayIndex];
  }

  /// Build answer option widgets with shuffled display order
  List<Widget> _buildShuffledAnswerOptions({
    required int? userAnswer,
    required Set<int> userMultipleAnswers,
  }) {
    final shuffledOptions = _getShuffledOptions(_currentQuestion);
    final validated = _validatedAnswers[_currentQuestion.id];
    final serverCorrectAnswer = validated?.correctAnswer;
    final serverCorrectAnswers = validated?.correctAnswers;

    return List.generate(
      shuffledOptions.length,
      (displayIndex) {
        final originalIndex = _toOriginalIndex(_currentQuestion.id, displayIndex);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnswerButton(
            index: displayIndex,
            text: shuffledOptions[displayIndex],
            isSelected: _currentQuestion.isMultipleChoice
                ? userMultipleAnswers.contains(originalIndex)
                : userAnswer == originalIndex,
            isCorrect: _showFeedback &&
                (_currentQuestion.isMultipleChoice
                    ? serverCorrectAnswers?.contains(originalIndex) == true &&
                      userMultipleAnswers.contains(originalIndex)
                    : originalIndex == serverCorrectAnswer && userAnswer == originalIndex),
            isCorrectButNotSelected: _showFeedback &&
                (_currentQuestion.isMultipleChoice
                    ? serverCorrectAnswers?.contains(originalIndex) == true &&
                      !userMultipleAnswers.contains(originalIndex)
                    : originalIndex == serverCorrectAnswer && userAnswer != originalIndex),
            isIncorrect: _showFeedback &&
                (_currentQuestion.isMultipleChoice
                    ? userMultipleAnswers.contains(originalIndex) &&
                      serverCorrectAnswers?.contains(originalIndex) != true
                    : userAnswer == originalIndex && originalIndex != serverCorrectAnswer),
            isDisabled: _showFeedback || _isValidating,
            isMultipleChoice: _currentQuestion.isMultipleChoice,
            onTap: () => _selectAnswer(originalIndex),
          ),
        );
      },
    );
  }

  Future<void> _startAttempt() async {
    // Only start tracking for exam mode; practice attempts are created on completion
    if (widget.quiz.isPracticeMode) {
      return;
    }

    try {
      final request = StartAttemptRequest(quizId: widget.quiz.id);

      final attempt = await _apiService.startAttempt(request);
      if (mounted) {
        setState(() {
          _attemptId = attempt.id;
        });
      }
    } catch (e) {
      debugPrint('Failed to start attempt: $e');
      if (mounted) {
        _showAttemptFailedDialog(e.toString());
      }
    }
  }

  void _showAttemptFailedDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Start Exam'),
        content: Text(
          'Failed to create exam attempt: $error\n\n'
          'You can continue in practice mode (results won\'t be saved to history), '
          'or go back and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(this.context); // Go back to home
            },
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), // Continue anyway
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final isExam = !widget.quiz.isPracticeMode;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExam ? 'Leave Exam?' : 'Leave Practice?'),
        content: Text(
          isExam
              ? 'If you leave now, this attempt will be marked as abandoned. Are you sure you want to exit?'
              : 'Are you sure you want to exit? Your progress will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(isExam ? 'Leave Exam' : 'Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleExit() async {
    if (await _confirmExit()) {
      if (!widget.quiz.isPracticeMode && _attemptId != null) {
        try {
          await _apiService.abandonAttempt(_attemptId!);
        } catch (e) {
          debugPrint('Failed to abandon attempt: $e');
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Question get _currentQuestion =>
      widget.quiz.questions[_currentQuestionIndex];

  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.quiz.questions.length - 1;

  bool get _hasAnsweredCurrent {
    if (_currentQuestion.isMultipleChoice) {
      return _userMultipleAnswers.containsKey(_currentQuestion.id) &&
             _userMultipleAnswers[_currentQuestion.id]!.isNotEmpty;
    }
    return _userAnswers.containsKey(_currentQuestion.id);
  }

  bool get _showFeedback =>
      widget.quiz.isPracticeMode &&
      _validatedAnswers.containsKey(_currentQuestion.id);

  void _selectAnswer(int answerIndex) {
    setState(() {
      if (_currentQuestion.isMultipleChoice) {
        _userMultipleAnswers.putIfAbsent(_currentQuestion.id, () => <int>{});
        final currentAnswers = _userMultipleAnswers[_currentQuestion.id]!;
        if (currentAnswers.contains(answerIndex)) {
          currentAnswers.remove(answerIndex);
        } else {
          currentAnswers.add(answerIndex);
        }
      } else {
        _userAnswers[_currentQuestion.id] = answerIndex;
        if (widget.quiz.isPracticeMode) {
          _validateCurrentAnswer();
        }
      }
    });
  }

  void _checkAnswers() {
    if (widget.quiz.isPracticeMode) {
      _validateCurrentAnswer();
    }
  }

  Future<void> _validateCurrentAnswer() async {
    if (_isValidating || _validatedAnswers.containsKey(_currentQuestion.id)) {
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      final request = _currentQuestion.isMultipleChoice
          ? ValidateAnswerRequest(
              userAnswers: _userMultipleAnswers[_currentQuestion.id]?.toList(),
            )
          : ValidateAnswerRequest(
              userAnswer: _userAnswers[_currentQuestion.id],
            );

      final response = await _apiService.validateAnswer(
        _currentQuestion.id,
        request,
      );

      if (mounted) {
        setState(() {
          _validatedAnswers[_currentQuestion.id] = response;
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
        debugPrint('Failed to validate answer: $e');
      }
    }
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _finishQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _finishQuiz() {
    final userAnswers = _buildUserAnswers();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          quiz: widget.quiz,
          userAnswers: userAnswers,
          attemptId: _attemptId,
        ),
      ),
    );
  }

  /// Build list of user answers to send to server for validation
  List<UserAnswerRequest> _buildUserAnswers() {
    final answers = <UserAnswerRequest>[];

    for (final question in widget.quiz.questions) {
      if (question.isMultipleChoice) {
        answers.add(UserAnswerRequest(
          questionId: question.id,
          userAnswers: _userMultipleAnswers[question.id]?.toList(),
        ));
      } else {
        answers.add(UserAnswerRequest(
          questionId: question.id,
          userAnswer: _userAnswers[question.id],
        ));
      }
    }

    return answers;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;
    final userAnswer = _userAnswers[_currentQuestion.id];
    final userMultipleAnswers = _userMultipleAnswers[_currentQuestion.id] ?? <int>{};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuizModeIcon(
                isExamMode: !widget.quiz.isPracticeMode,
                size: AppIconSizes.appBarLogo,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.quiz.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleExit,
          ),
        ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(
                bottom: BorderSide(color: AppColors.outline),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${widget.quiz.questions.length}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Text(
                        widget.quiz.type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearPercentIndicator(
                  width: MediaQuery.of(context).size.width - 32,
                  lineHeight: 8.0,
                  percent: progress,
                  backgroundColor: AppColors.surfaceContainer,
                  progressColor: AppColors.primary,
                  barRadius: const Radius.circular(4),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentQuestion.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),

                  if (_currentQuestion.isMultipleChoice) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.infoContainer,
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: Text(
                        'Select all that apply',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onInfoContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  if (_currentQuestion.code != null) ...[
                    CodeBlock(
                      code: _currentQuestion.code!,
                      language: _currentQuestion.language,
                    ),
                    const SizedBox(height: 24),
                  ],

                  ..._buildShuffledAnswerOptions(
                    userAnswer: userAnswer,
                    userMultipleAnswers: userMultipleAnswers,
                  ),

                  if (_showFeedback && _currentQuestion.explanation != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.infoContainer,
                        borderRadius: AppRadius.mdAll,
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
                                size: AppIconSizes.md,
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
                            _currentQuestion.explanation!,
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
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(
                top: BorderSide(color: AppColors.outline),
              ),
            ),
            child: Column(
              children: [
                if (_currentQuestion.isMultipleChoice &&
                    widget.quiz.isPracticeMode &&
                    _hasAnsweredCurrent &&
                    !_validatedAnswers.containsKey(_currentQuestion.id)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isValidating ? null : _checkAnswers,
                      icon: _isValidating
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                          : const Icon(Icons.fact_check),
                      label: Text(_isValidating ? 'Checking...' : 'Check Answers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                    ElevatedButton.icon(
                      onPressed: (_hasAnsweredCurrent &&
                                  (!_currentQuestion.isMultipleChoice ||
                                   !widget.quiz.isPracticeMode ||
                                   _validatedAnswers.containsKey(_currentQuestion.id))) ? _nextQuestion : null,
                      icon: Icon(_isLastQuestion ? Icons.check : Icons.arrow_forward),
                      label: Text(_isLastQuestion ? 'Finish' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}