import 'package:flutter/material.dart';
import '../../models/draft_questionnaire.dart';
import '../../theme/app_colors.dart';

class QuestionEditorDialog extends StatefulWidget {
  final DraftQuestion? question;
  final int maxOptions;
  final void Function(DraftQuestion question) onSave;

  const QuestionEditorDialog({
    super.key,
    this.question,
    this.maxOptions = 8,
    required this.onSave,
  });

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  late DraftQuestion _question;
  late TextEditingController _questionController;
  late List<TextEditingController> _optionControllers;
  late TextEditingController _explanationController;
  late TextEditingController _codeController;
  late TextEditingController _languageController;
  late List<TextEditingController> _altQuestionControllers;
  late List<TextEditingController> _altOptionControllers;
  bool _isMultipleChoice = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _question = widget.question?.copy() ?? DraftQuestion();
    _questionController = TextEditingController(text: _question.question);
    _optionControllers = _question.options
        .map((o) => TextEditingController(text: o))
        .toList();
    _explanationController =
        TextEditingController(text: _question.explanation);
    _codeController = TextEditingController(text: _question.code);
    _languageController = TextEditingController(text: _question.language);
    _altQuestionControllers = _question.alternativeQuestions
        .map((q) => TextEditingController(text: q))
        .toList();
    _altOptionControllers = _question.alternativeOptions
        .map((o) => TextEditingController(text: o))
        .toList();
    _isMultipleChoice = _question.isMultipleChoice;

    // Show advanced section if any advanced fields have content
    _showAdvanced = _question.code.isNotEmpty ||
        _question.alternativeQuestions.isNotEmpty ||
        _question.alternativeOptions.isNotEmpty;
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    _explanationController.dispose();
    _codeController.dispose();
    _languageController.dispose();
    for (var c in _altQuestionControllers) {
      c.dispose();
    }
    for (var c in _altOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncFromControllers() {
    _question.question = _questionController.text;
    _question.options = _optionControllers.map((c) => c.text).toList();
    _question.explanation = _explanationController.text;
    _question.code = _codeController.text;
    _question.language = _languageController.text;
    _question.alternativeQuestions =
        _altQuestionControllers.map((c) => c.text).toList();
    _question.alternativeOptions =
        _altOptionControllers.map((c) => c.text).toList();
  }

  void _addOption() {
    if (_optionControllers.length < widget.maxOptions) {
      setState(() {
        _optionControllers.add(TextEditingController());
        _question.addOption();
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
        _question.removeOption(index);
      });
    }
  }

  void _addAltQuestion() {
    setState(() {
      _altQuestionControllers.add(TextEditingController());
    });
  }

  void _removeAltQuestion(int index) {
    setState(() {
      _altQuestionControllers[index].dispose();
      _altQuestionControllers.removeAt(index);
    });
  }

  void _addAltOption() {
    setState(() {
      _altOptionControllers.add(TextEditingController());
    });
  }

  void _removeAltOption(int index) {
    setState(() {
      _altOptionControllers[index].dispose();
      _altOptionControllers.removeAt(index);
    });
  }

  void _toggleAnswer(int optionIndex) {
    final answer = optionIndex + 1; // 1-based
    setState(() {
      if (_isMultipleChoice) {
        _question.toggleAnswer(answer);
      } else {
        _question.setSingleAnswer(answer);
      }
    });
  }

  void _setMultipleChoice(bool value) {
    setState(() {
      _isMultipleChoice = value;
      if (!value && _question.correctAnswers.length > 1) {
        // Keep only first answer when switching to single
        _question.correctAnswers = [_question.correctAnswers.first];
      }
    });
  }

  bool _isAnswerSelected(int optionIndex) {
    return _question.correctAnswers.contains(optionIndex + 1);
  }

  void _save() {
    _syncFromControllers();
    if (_question.isValid) {
      widget.onSave(_question);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required fields'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.question != null;
    final canAddOption = _optionControllers.length < widget.maxOptions;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.quiz, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Question' : 'Add Question',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    TextField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Question *',
                        hintText: 'Enter your question',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Question type toggle
                    Row(
                      children: [
                        const Text('Question Type:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Single Choice'),
                          selected: !_isMultipleChoice,
                          onSelected: (_) => _setMultipleChoice(false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Multiple Choice'),
                          selected: _isMultipleChoice,
                          onSelected: (_) => _setMultipleChoice(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Options *',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              'Max: ${widget.maxOptions} options',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        if (canAddOption)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Option'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMultipleChoice
                          ? 'Select all correct answers'
                          : 'Select the correct answer',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(_optionControllers.length, (index) {
                      final isSelected = _isAnswerSelected(index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // Selection indicator
                            GestureDetector(
                              onTap: () => _toggleAnswer(index),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: _isMultipleChoice
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  borderRadius: _isMultipleChoice
                                      ? BorderRadius.circular(4)
                                      : null,
                                  color: isSelected
                                      ? AppColors.success
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Option text field
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  hintText: 'Option ${index + 1}',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),

                            // Remove button
                            if (_optionControllers.length > 2)
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: AppColors.error),
                                onPressed: () => _removeOption(index),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Explanation (optional)
                    TextField(
                      controller: _explanationController,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (optional)',
                        hintText: 'Explain why this is the correct answer',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Advanced options toggle
                    InkWell(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvanced
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Advanced Options',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text(
                              'Code, alternatives',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Advanced options content
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),

                      // Code snippet
                      const Text('Code Snippet',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _languageController,
                              decoration: const InputDecoration(
                                labelText: 'Language',
                                hintText: 'e.g., javascript',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: 'Code',
                          hintText: 'Enter code snippet',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: AppColors.codeBackground,
                        ),
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Alternative questions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alternative Questions',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          TextButton.icon(
                            onPressed: _addAltQuestion,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      Text(
                        'Different ways to phrase the same question',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_altQuestionControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _altQuestionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Alternative question ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: AppColors.error),
                                onPressed: () => _removeAltQuestion(index),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Alternative options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alternative Options',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          TextButton.icon(
                            onPressed: _addAltOption,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      Text(
                        'Additional distractor options for variety',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_altOptionControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _altOptionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Alternative option ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: AppColors.error),
                                onPressed: () => _removeAltOption(index),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Update' : 'Add'),
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
