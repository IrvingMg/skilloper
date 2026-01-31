import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../models/attempt.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/answer_button.dart';
import '../widgets/code_block.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final int? attemptId;
  final List<DisplayedQuestionData>? displayedQuestions;

  const QuizScreen({
    required this.quiz,
    super.key,
    this.attemptId,
    this.displayedQuestions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  final ApiService _apiService = ApiService();
  final FocusNode _focusNode = FocusNode();

  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers =
      {}; // For single choice (stores ORIGINAL indices)
  final Map<int, Set<int>> _userMultipleAnswers =
      {}; // For multiple choice (stores ORIGINAL indices)

  int? _attemptId; // Track the attempt ID for completion

  final Map<int, ValidateAnswerResponse> _validatedAnswers = {};
  bool _isValidating = false;

  // Shuffle mappings: questionId -> list of original indices in display order
  final Map<int, List<int>> _shuffleMappings = {};

  // Map of question ID to displayed data (from server)
  late final Map<int, DisplayedQuestionData> _displayedQuestionsMap;

  @override
  void initState() {
    super.initState();
    _buildDisplayedQuestionsMap();
    _initializeShuffleMappings();
    // Use pre-created attemptId if provided
    if (widget.attemptId != null) {
      _attemptId = widget.attemptId;
    }
  }

  void _buildDisplayedQuestionsMap() {
    _displayedQuestionsMap = {};
    if (widget.displayedQuestions != null) {
      for (final dq in widget.displayedQuestions!) {
        _displayedQuestionsMap[dq.questionId] = dq;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final optionCount = _getOptionsForQuestion(_currentQuestion).length;
    final alreadyValidated = _validatedAnswers.containsKey(_currentQuestion.id);

    // Number keys 1-9 to select answers
    for (var i = 0; i < _digitKeys.length && i < optionCount; i++) {
      if (event.logicalKey == _digitKeys[i]) {
        if (!alreadyValidated && !_isValidating) {
          final originalIndex = _toOriginalIndex(_currentQuestion.id, i);
          _selectAnswer(originalIndex);
        }
        return KeyEventResult.handled;
      }
    }

    // Enter to advance (check answer or next question)
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (!_hasAnsweredCurrent || _isValidating) {
        return KeyEventResult.ignored;
      }

      if (widget.quiz.isPracticeMode && !alreadyValidated) {
        // Practice mode: check answer first
        _checkAnswers();
        return KeyEventResult.handled;
      } else {
        // Exam mode or already validated: go to next question
        _nextQuestion();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Initialize shuffle mappings for all questions
  /// Uses displayed options count from server if available
  void _initializeShuffleMappings() {
    for (final question in widget.quiz.questions) {
      final optionCount = _getOptionsForQuestion(question).length;
      final indices = List.generate(optionCount, (i) => i);
      indices.shuffle();
      _shuffleMappings[question.id] = indices;
    }
  }

  /// Get the question text to display (from server-randomized data if available)
  String _getQuestionText(Question question) {
    final displayed = _displayedQuestionsMap[question.id];
    if (displayed != null && displayed.questionText.isNotEmpty) {
      return displayed.questionText;
    }
    return question.question;
  }

  /// Get the options to display (from server-randomized data if available)
  List<String> _getOptionsForQuestion(Question question) {
    final displayed = _displayedQuestionsMap[question.id];
    if (displayed != null && displayed.options.isNotEmpty) {
      return displayed.options;
    }
    return question.options;
  }

  /// Get shuffled options for display
  List<String> _getShuffledOptions(Question question) {
    final mapping = _shuffleMappings[question.id]!;
    final options = _getOptionsForQuestion(question);
    return mapping.map((i) => options[i]).toList();
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

    return List.generate(shuffledOptions.length, (displayIndex) {
      final originalIndex = _toOriginalIndex(_currentQuestion.id, displayIndex);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnswerButton(
          index: displayIndex,
          text: shuffledOptions[displayIndex],
          isSelected: _currentQuestion.isMultipleChoice
              ? userMultipleAnswers.contains(originalIndex)
              : userAnswer == originalIndex,
          isCorrect:
              _showFeedback &&
              (_currentQuestion.isMultipleChoice
                  ? (serverCorrectAnswers?.contains(originalIndex) ?? false) &&
                        userMultipleAnswers.contains(originalIndex)
                  : originalIndex == serverCorrectAnswer &&
                        userAnswer == originalIndex),
          isCorrectButNotSelected:
              _showFeedback &&
              (_currentQuestion.isMultipleChoice
                  ? (serverCorrectAnswers?.contains(originalIndex) ?? false) &&
                        !userMultipleAnswers.contains(originalIndex)
                  : originalIndex == serverCorrectAnswer &&
                        userAnswer != originalIndex),
          isIncorrect:
              _showFeedback &&
              (_currentQuestion.isMultipleChoice
                  ? userMultipleAnswers.contains(originalIndex) &&
                        serverCorrectAnswers?.contains(originalIndex) != true
                  : userAnswer == originalIndex &&
                        originalIndex != serverCorrectAnswer),
          isDisabled: _showFeedback || _isValidating,
          isMultipleChoice: _currentQuestion.isMultipleChoice,
          onTap: () => _selectAnswer(originalIndex),
        ),
      );
    });
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
        } on Exception catch (e) {
          debugPrint('Failed to abandon attempt: $e');
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Question get _currentQuestion => widget.quiz.questions[_currentQuestionIndex];

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
    } on Exception catch (e) {
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
      MaterialPageRoute<void>(
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
        answers.add(
          UserAnswerRequest(
            questionId: question.id,
            userAnswers: _userMultipleAnswers[question.id]?.toList(),
          ),
        );
      } else {
        answers.add(
          UserAnswerRequest(
            questionId: question.id,
            userAnswer: _userAnswers[question.id],
          ),
        );
      }
    }

    return answers;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;
    final userAnswer = _userAnswers[_currentQuestion.id];
    final userMultipleAnswers =
        _userMultipleAnswers[_currentQuestion.id] ?? <int>{};

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _handleExit();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.quiz.title, overflow: TextOverflow.ellipsis),
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
                  border: Border(bottom: BorderSide(color: AppColors.outline)),
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
                          decoration: const BoxDecoration(
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
                        _getQuestionText(_currentQuestion),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),

                      if (_currentQuestion.isMultipleChoice) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: const Text(
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

                      if (_showFeedback &&
                          _currentQuestion.explanation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: AppRadius.mdAll,
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
                                  SizedBox(width: 8),
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
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border(top: BorderSide(color: AppColors.outline)),
                ),
                child: Column(
                  children: [
                    if (widget.quiz.isPracticeMode &&
                        _hasAnsweredCurrent &&
                        !_validatedAnswers.containsKey(
                          _currentQuestion.id,
                        )) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isValidating ? null : _checkAnswers,
                          icon: _isValidating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnPrimary,
                                  ),
                                )
                              : const Icon(Icons.fact_check),
                          label: Text(
                            _isValidating
                                ? 'Checking...'
                                : _currentQuestion.isMultipleChoice
                                ? 'Check Answers'
                                : 'Check Answer',
                          ),
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
                          onPressed: _currentQuestionIndex > 0
                              ? _previousQuestion
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              (_hasAnsweredCurrent &&
                                  (!widget.quiz.isPracticeMode ||
                                      _validatedAnswers.containsKey(
                                        _currentQuestion.id,
                                      )))
                              ? _nextQuestion
                              : null,
                          icon: Icon(
                            _isLastQuestion ? Icons.check : Icons.arrow_forward,
                          ),
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
      ),
    );
  }
}
