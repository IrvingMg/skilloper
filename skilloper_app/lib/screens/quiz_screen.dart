import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:collection/collection.dart';
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
  final Map<int, int> _userAnswers = {}; // For single choice
  final Map<int, Set<int>> _userMultipleAnswers = {}; // For multiple choice

  int? _attemptId; // Track the attempt ID for completion

  @override
  void initState() {
    super.initState();
    _startAttempt();
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

  bool _hasCheckedAnswers = false;

  bool get _showFeedback =>
      widget.questionnaire.isPracticeMode &&
      _hasAnsweredCurrent &&
      (!_currentQuestion.isMultipleChoice || _hasCheckedAnswers);

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
    setState(() {
      _hasCheckedAnswers = true;
    });
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _finishQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _hasCheckedAnswers = false; // Reset for next question
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _hasCheckedAnswers = false; // Reset for previous question
      });
    }
  }

  void _finishQuiz() {
    final results = _calculateResults();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          questionnaire: widget.questionnaire,
          results: results,
          attemptId: _attemptId,
        ),
      ),
    );
  }

  QuizResult _calculateResults() {
    int correct = 0;
    List<QuestionResult> questionResults = [];

    for (final question in widget.questionnaire.questions) {
      bool isCorrect = false;
      int? userAnswer;
      List<int>? userAnswers;

      if (question.isMultipleChoice) {
        userAnswers = _userMultipleAnswers[question.id]?.toList();
        if (userAnswers != null && question.correctAnswers != null) {
          userAnswers.sort();
          final correctAnswers = List<int>.from(question.correctAnswers!);
          correctAnswers.sort();
          isCorrect = const ListEquality().equals(userAnswers, correctAnswers);
        }
      } else {
        userAnswer = _userAnswers[question.id];
        isCorrect = userAnswer == question.correctAnswer;
      }

      if (isCorrect) correct++;

      questionResults.add(
        QuestionResult(
          question: question,
          userAnswer: userAnswer,
          userAnswers: userAnswers,
          isCorrect: isCorrect,
        ),
      );
    }

    final score = ((correct / widget.questionnaire.questions.length) * 100).round();

    return QuizResult(
      score: score,
      correct: correct,
      total: widget.questionnaire.questions.length,
      questionResults: questionResults,
    );
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

                  // Answer options
                  ...List.generate(
                    _currentQuestion.options.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnswerButton(
                        index: index,
                        text: _currentQuestion.options[index],
                        isSelected: _currentQuestion.isMultipleChoice
                            ? userMultipleAnswers.contains(index)
                            : userAnswer == index,
                        isCorrect: _showFeedback &&
                            (_currentQuestion.isMultipleChoice
                                ? _currentQuestion.correctAnswers?.contains(index) == true &&
                                  userMultipleAnswers.contains(index)
                                : index == _currentQuestion.correctAnswer && userAnswer == index),
                        isCorrectButNotSelected: _showFeedback &&
                            (_currentQuestion.isMultipleChoice
                                ? _currentQuestion.correctAnswers?.contains(index) == true &&
                                  !userMultipleAnswers.contains(index)
                                : index == _currentQuestion.correctAnswer && userAnswer != index),
                        isIncorrect: _showFeedback &&
                            (_currentQuestion.isMultipleChoice
                                ? userMultipleAnswers.contains(index) &&
                                  _currentQuestion.correctAnswers?.contains(index) != true
                                : userAnswer == index && index != _currentQuestion.correctAnswer),
                        isDisabled: _showFeedback,
                        isMultipleChoice: _currentQuestion.isMultipleChoice,
                        onTap: () => _selectAnswer(index),
                      ),
                    ),
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
                    !_hasCheckedAnswers) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkAnswers,
                      icon: const Icon(Icons.fact_check),
                      label: const Text('Check Answers'),
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
                                   _hasCheckedAnswers)) ? _nextQuestion : null,
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