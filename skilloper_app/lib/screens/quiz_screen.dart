import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../models/questionnaire.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../widgets/answer_button.dart';
import '../widgets/code_block.dart';
import '../theme/app_colors.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  final Questionnaire questionnaire;

  const QuizScreen({
    super.key,
    required this.questionnaire,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();

  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // For single choice (stores ORIGINAL indices)
  final Map<int, Set<int>> _userMultipleAnswers = {}; // For multiple choice (stores ORIGINAL indices)

  int? _attemptId; // Track the attempt ID for completion

  // Practice mode: server-validated answers for immediate feedback
  final Map<int, ValidateAnswerResponse> _validatedAnswers = {};
  bool _isValidating = false;

  // Shuffle mappings: questionId -> list of original indices in display order
  // e.g., [2, 0, 3, 1] means display position 0 shows original option 2
  final Map<int, List<int>> _shuffleMappings = {};

  @override
  void initState() {
    super.initState();
    _initializeShuffleMappings();
    _startAttempt();
  }

  /// Initialize shuffle mappings for all questions
  void _initializeShuffleMappings() {
    for (final question in widget.questionnaire.questions) {
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
        // Convert display position to original index for all state checks
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
    // Only start tracking for exam mode (to track abandonments)
    // Practice attempts are created on completion in ResultsScreen
    if (widget.questionnaire.isPracticeMode) {
      return;
    }

    try {
      final deviceId = await _deviceService.getDeviceId();
      final request = StartAttemptRequest(
        deviceId: deviceId,
        questionnaireId: widget.questionnaire.id,
        questionnaireTitle: widget.questionnaire.title,
        questionnaireType: widget.questionnaire.type,
        totalCount: widget.questionnaire.questions.length,
      );

      final attempt = await _apiService.startAttempt(request);
      if (mounted) {
        setState(() {
          _attemptId = attempt.id;
        });
      }
    } catch (e) {
      // Silently fail - quiz can continue without tracking
      debugPrint('Failed to start attempt: $e');
    }
  }

  Future<bool> _confirmExit() async {
    final isExam = !widget.questionnaire.isPracticeMode;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExam ? 'Leave Exam?' : 'Leave Practice?'),
        content: Text(
          isExam
              ? 'If you leave now, this attempt will be marked as abandoned in your history. Are you sure you want to exit?'
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

  void _handleExit() async {
    if (await _confirmExit()) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Question get _currentQuestion =>
      widget.questionnaire.questions[_currentQuestionIndex];

  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.questionnaire.questions.length - 1;

  bool get _hasAnsweredCurrent {
    if (_currentQuestion.isMultipleChoice) {
      return _userMultipleAnswers.containsKey(_currentQuestion.id) &&
             _userMultipleAnswers[_currentQuestion.id]!.isNotEmpty;
    }
    return _userAnswers.containsKey(_currentQuestion.id);
  }

  bool get _showFeedback =>
      widget.questionnaire.isPracticeMode &&
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
        // For practice mode single choice, validate immediately
        if (widget.questionnaire.isPracticeMode) {
          _validateCurrentAnswer();
        }
      }
    });
  }

  void _checkAnswers() {
    // For practice mode multiple choice, validate when user clicks "Check"
    if (widget.questionnaire.isPracticeMode) {
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
    // Build user answers to send to results screen
    final userAnswers = _buildUserAnswers();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          questionnaire: widget.questionnaire,
          userAnswers: userAnswers,
          attemptId: _attemptId,
        ),
      ),
    );
  }

  /// Build list of user answers to send to server for validation
  List<UserAnswerRequest> _buildUserAnswers() {
    final answers = <UserAnswerRequest>[];

    for (final question in widget.questionnaire.questions) {
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
    final progress = (_currentQuestionIndex + 1) / widget.questionnaire.questions.length;
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
          title: Text(widget.questionnaire.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleExit,
          ),
        ),
      body: Column(
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${widget.questionnaire.questions.length}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.questionnaire.isPracticeMode
                            ? AppColors.practiceModeContainer
                            : AppColors.examModeContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.questionnaire.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: widget.questionnaire.isPracticeMode
                              ? AppColors.onPracticeModeContainer
                              : AppColors.onExamModeContainer,
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
                  backgroundColor: const Color(0xFFF3F4F6),
                  progressColor: Theme.of(context).primaryColor,
                  barRadius: const Radius.circular(4),
                ),
              ],
            ),
          ),

          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  Text(
                    _currentQuestion.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),

                  // Question type indicator
                  if (_currentQuestion.isMultipleChoice) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.infoContainer,
                        borderRadius: BorderRadius.circular(6),
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

                  // Code block (if present)
                  if (_currentQuestion.code != null) ...[
                    CodeBlock(
                      code: _currentQuestion.code!,
                      language: _currentQuestion.language,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Answer options (displayed in shuffled order)
                  ..._buildShuffledAnswerOptions(
                    userAnswer: userAnswer,
                    userMultipleAnswers: userMultipleAnswers,
                  ),

                  // Explanation (Practice mode only)
                  if (_showFeedback && _currentQuestion.explanation != null) ...[
                    const SizedBox(height: 16),
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

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              children: [
                // Check answers button for multiple choice (practice mode only)
                if (_currentQuestion.isMultipleChoice &&
                    widget.questionnaire.isPracticeMode &&
                    _hasAnsweredCurrent &&
                    !_validatedAnswers.containsKey(_currentQuestion.id)) ...[
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
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fact_check),
                      label: Text(_isValidating ? 'Checking...' : 'Check Answers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Navigation buttons
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
                                   !widget.questionnaire.isPracticeMode ||
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