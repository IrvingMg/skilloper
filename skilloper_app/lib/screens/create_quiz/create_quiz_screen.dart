import 'package:flutter/material.dart';
import '../../models/draft_quiz.dart';
import '../../models/quiz.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import 'question_editor_dialog.dart';

class CreateQuizScreen extends StatefulWidget {
  /// Optional quiz to edit. If null, creates a new quiz.
  final Quiz? quiz;

  const CreateQuizScreen({super.key, this.quiz});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final DraftQuiz _draft = DraftQuiz();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final ApiService _apiService = ApiService();

  int _currentStep = 0;
  bool _isSubmitting = false;

  bool get _isEditMode => _draft.isEditMode;

  @override
  void initState() {
    super.initState();
    if (widget.quiz != null) {
      _draft.loadFromQuiz(widget.quiz!);
      _titleController.text = _draft.title;
      _descController.text = _draft.description;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _titleController.text.trim().isNotEmpty;
      case 1:
        return _draft.questions.isNotEmpty &&
            _draft.questions.every((q) => q.isValid);
      case 2:
        return _draft.isValid;
      default:
        return false;
    }
  }

  Future<void> _submitQuiz() async {
    if (!_draft.isValid || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Map<String, dynamic> response;
      if (_isEditMode) {
        response = await _apiService.updateQuiz(_draft.id!, _draft.toJson());
      } else {
        response = await _apiService.createQuiz(_draft.toJson());
      }

      if (mounted) {
        _showSuccessDialog(response);
      }
    } on Object catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    final isEdit = _isEditMode;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: AppIconSizes.xxxl,
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? 'Quiz Updated!' : 'Quiz Created!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? 'Successfully updated quiz:'
                    : 'Successfully created quiz:',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draft.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_draft.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _draft.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.quiz,
                          size: AppIconSizes.sm,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_draft.questions.length} questions',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        QuizModeIcon(
                          isExamMode: _draft.type == 'exam',
                          size: AppIconSizes.sm,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _draft.type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!isEdit)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _draft.clear();
                  _titleController.clear();
                  _descController.clear();
                  setState(() {
                    _currentStep = 0;
                  });
                },
                child: const Text('Create Another'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (r) => false);
              },
              child: const Text('View Quizzes'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String error) {
    String message = error;
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error,
              color: AppColors.textOnPrimary,
              size: AppIconSizes.lg,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    );
  }

  void _addQuestion() {
    showDialog<void>(
      context: context,
      builder: (context) => QuestionEditorDialog(
        maxOptions: _draft.maxOptions,
        onSave: (question) {
          setState(() {
            _draft.questions.add(question);
          });
        },
      ),
    );
  }

  void _editQuestion(int index) {
    showDialog<void>(
      context: context,
      builder: (context) => QuestionEditorDialog(
        question: _draft.questions[index],
        maxOptions: _draft.maxOptions,
        onSave: (question) {
          setState(() {
            _draft.questions[index] = question;
          });
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _draft.removeQuestion(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Quiz' : 'Create Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showExitConfirmation,
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          _buildStepCircle(0, 'Details'),
          _buildStepLine(0),
          _buildStepCircle(1, 'Questions'),
          _buildStepLine(1),
          _buildStepCircle(2, 'Review'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: GestureDetector(
        onTap: step <= _currentStep ? () => _goToStep(step) : null,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary : AppColors.outline,
                border: isCurrent
                    ? Border.all(color: AppColors.primary, width: 3)
                    : null,
              ),
              child: Center(
                child: isActive && !isCurrent
                    ? const Icon(
                        Icons.check,
                        color: AppColors.textOnPrimary,
                        size: AppIconSizes.md,
                      )
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color: isActive
                              ? AppColors.textOnPrimary
                              : AppColors.textDisabled,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppColors.primary : AppColors.outline,
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildQuestionsStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quiz Details',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter basic information about your quiz',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Title
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title *',
            hintText: 'Enter quiz title',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _draft.title = v;
            setState(() {});
          },
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Enter optional description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (v) {
            _draft.description = v;
          },
        ),
        const SizedBox(height: 24),

        // Type
        const Text('Quiz Type', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                title: 'Practice',
                description: 'Show answers after each question',
                isExamMode: false,
                isSelected: _draft.type == 'practice',
                onTap: () => setState(() => _draft.type = 'practice'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeCard(
                title: 'Exam',
                description: 'Show results only at the end',
                isExamMode: true,
                isSelected: _draft.type == 'exam',
                onTap: () => setState(() => _draft.type = 'exam'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Max options
        const Text(
          'Max Options per Question',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'How many answer options each question can have (2-8)',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _draft.maxOptions.toDouble(),
                min: 2,
                max: 8,
                divisions: 6,
                label: '${_draft.maxOptions} options',
                onChanged: (value) {
                  setState(() {
                    _draft.maxOptions = value.toInt();
                  });
                },
              ),
            ),
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.smAll,
                border: Border.all(color: AppColors.outline),
              ),
              child: Text(
                '${_draft.maxOptions}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Questions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_draft.validQuestionCount} of ${_draft.questions.length} questions valid',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_draft.questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline),
              borderRadius: AppRadius.mdAll,
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 48,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(height: 12),
                  Text('No questions yet', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    'Add your first question to get started',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _draft.questions.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final q = _draft.questions.removeAt(oldIndex);
                _draft.questions.insert(newIndex, q);
              });
            },
            itemBuilder: (context, index) {
              final q = _draft.questions[index];
              return _QuestionCard(
                // Use object identity for stable keys during reordering
                key: ValueKey(identityHashCode(q)),
                index: index,
                question: q,
                onEdit: () => _editQuestion(index),
                onDelete: () => _deleteQuestion(index),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Submit',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review your quiz before submitting',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.primary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  QuizModeIcon(
                    isExamMode: _draft.type == 'exam',
                    size: AppIconSizes.xxl,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _draft.type.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _draft.title.isEmpty ? 'Untitled Quiz' : _draft.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_draft.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _draft.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.quiz,
                    size: AppIconSizes.sm,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_draft.questions.length} questions',
                    style: const TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Questions preview
        const Text(
          'Questions Preview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        ...List.generate(_draft.questions.length, (index) {
          final q = _draft.questions[index];
          final nonEmptyOptions = q.options
              .asMap()
              .entries
              .where((e) => e.value.trim().isNotEmpty)
              .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.question,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${nonEmptyOptions.length} options • ${q.isMultipleChoice ? "Multiple choice" : "Single choice"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: q.validationError ?? 'Valid',
                      child: Icon(
                        q.isValid ? Icons.check_circle : Icons.warning,
                        size: AppIconSizes.lg,
                        color: q.isValid
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),

                // Options list
                if (nonEmptyOptions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...nonEmptyOptions.map((entry) {
                    final optIndex = entry.key;
                    final optText = entry.value;
                    final isCorrect = q.correctAnswers.contains(optIndex + 1);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(left: 36),
                            decoration: BoxDecoration(
                              shape: q.isMultipleChoice
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: q.isMultipleChoice
                                  ? BorderRadius.circular(AppRadius.xs)
                                  : null,
                              color: isCorrect
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : AppColors.surface,
                              border: Border.all(
                                color: isCorrect
                                    ? AppColors.success
                                    : AppColors.textDisabled,
                                width: 1.5,
                              ),
                            ),
                            child: isCorrect
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: AppColors.success,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 13,
                                color: isCorrect
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                fontWeight: isCorrect
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Code snippet indicator
                if (q.code.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(left: 36),
                    decoration: const BoxDecoration(
                      color: AppColors.codeBackground,
                      borderRadius: AppRadius.xsAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.code,
                          size: AppIconSizes.xs,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          q.language.isNotEmpty ? q.language : 'Code snippet',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        // Validation warnings
        if (!_draft.isValid) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getValidationMessage(),
                    style: const TextStyle(color: AppColors.onWarningContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getValidationMessage() {
    if (_draft.title.isEmpty) return 'Please enter a quiz title';
    if (_draft.questions.isEmpty) return 'Please add at least one question';
    final invalidCount = _draft.questions.where((q) => !q.isValid).length;
    if (invalidCount > 0) {
      return '$invalidCount question(s) need to be completed';
    }
    return 'Please complete all required fields';
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          if (_currentStep < 2)
            ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              child: const Text('Continue'),
            )
          else
            ElevatedButton(
              onPressed: _draft.isValid && !_isSubmitting ? _submitQuiz : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : Text(_isEditMode ? 'Save Changes' : 'Create Quiz'),
            ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    if (_draft.title.isEmpty && _draft.questions.isEmpty) {
      Navigator.pop(context);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isExamMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.description,
    required this.isExamMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceWhite,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuizModeIcon(isExamMode: isExamMode, size: AppIconSizes.xxxl),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final DraftQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: question.isValid
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: AppRadius.xsAll,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: question.isValid ? AppColors.primary : AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        title: Text(
          question.question.isEmpty ? 'Untitled Question' : question.question,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${question.options.where((o) => o.isNotEmpty).length} options • ${question.isMultipleChoice ? "Multiple" : "Single"} choice',
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!question.isValid)
              Tooltip(
                message: question.validationError ?? 'Invalid',
                child: const Icon(
                  Icons.warning,
                  color: AppColors.warning,
                  size: AppIconSizes.lg,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: AppIconSizes.lg),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: AppIconSizes.lg,
                color: AppColors.error,
              ),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}
