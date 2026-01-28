import 'package:flutter/material.dart';
import '../../constants/limits.dart';
import '../../models/draft_quiz.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class QuestionEditorDialog extends StatefulWidget {
  final DraftQuestion? question;
  final int maxOptions;
  final void Function(DraftQuestion question) onSave;

  const QuestionEditorDialog({
    required this.onSave,
    super.key,
    this.question,
    this.maxOptions = 8,
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
  late List<TextEditingController> _extraOptionControllers;
  late List<List<TextEditingController>> _optionVariantControllers;
  bool _isMultipleChoice = false;
  bool _showAdvanced = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _question = widget.question?.copy() ?? DraftQuestion();
    _questionController = TextEditingController(text: _question.question);
    _optionControllers = _question.options
        .map((o) => TextEditingController(text: o))
        .toList();
    _explanationController = TextEditingController(text: _question.explanation);
    _codeController = TextEditingController(text: _question.code);
    _languageController = TextEditingController(text: _question.language);
    _altQuestionControllers = _question.alternativeQuestions
        .map((q) => TextEditingController(text: q))
        .toList();
    _extraOptionControllers = _question.extraOptions
        .map((o) => TextEditingController(text: o))
        .toList();
    _optionVariantControllers = [];
    for (int i = 0; i < _question.options.length; i++) {
      final variants = (i < _question.optionVariants.length)
          ? _question.optionVariants[i]
          : <String>[];
      _optionVariantControllers.add(
        variants.map((v) => TextEditingController(text: v)).toList(),
      );
    }
    _isMultipleChoice = _question.isMultipleChoice;
    _showAdvanced =
        _question.code.isNotEmpty ||
        _question.alternativeQuestions.isNotEmpty ||
        _question.extraOptions.isNotEmpty ||
        _optionVariantControllers.any((v) => v.isNotEmpty);
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _explanationController.dispose();
    _codeController.dispose();
    _languageController.dispose();
    for (final c in _altQuestionControllers) {
      c.dispose();
    }
    for (final c in _extraOptionControllers) {
      c.dispose();
    }
    for (final optionVariants in _optionVariantControllers) {
      for (final c in optionVariants) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncFromControllers() {
    _question.question = _questionController.text;
    _question.options = _optionControllers.map((c) => c.text).toList();
    _question.explanation = _explanationController.text;
    _question.code = _codeController.text;
    _question.language = _languageController.text;
    _question.alternativeQuestions = _altQuestionControllers
        .map((c) => c.text)
        .toList();
    _question.extraOptions = _extraOptionControllers
        .map((c) => c.text)
        .toList();
    _question.optionVariants = _optionVariantControllers
        .map((controllers) => controllers.map((c) => c.text).toList())
        .toList();
  }

  void _addOption() {
    if (_optionControllers.length < widget.maxOptions) {
      setState(() {
        _optionControllers.add(TextEditingController());
        _optionVariantControllers.add([]);
        _question.addOption();
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
        if (index < _optionVariantControllers.length) {
          for (final c in _optionVariantControllers[index]) {
            c.dispose();
          }
          _optionVariantControllers.removeAt(index);
        }
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

  void _addExtraOption() {
    setState(() {
      _extraOptionControllers.add(TextEditingController());
    });
  }

  void _removeExtraOption(int index) {
    setState(() {
      _extraOptionControllers[index].dispose();
      _extraOptionControllers.removeAt(index);
    });
  }

  void _addOptionVariant(int optionIndex) {
    setState(() {
      if (optionIndex < _optionVariantControllers.length) {
        _optionVariantControllers[optionIndex].add(TextEditingController());
      }
    });
  }

  void _removeOptionVariant(int optionIndex, int variantIndex) {
    setState(() {
      if (optionIndex < _optionVariantControllers.length &&
          variantIndex < _optionVariantControllers[optionIndex].length) {
        _optionVariantControllers[optionIndex][variantIndex].dispose();
        _optionVariantControllers[optionIndex].removeAt(variantIndex);
      }
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
      _errorMessage = null;
    });
  }

  void _setMultipleChoice(bool value) {
    setState(() {
      _isMultipleChoice = value;
      _question.questionType = value
          ? QuestionTypes.multipleChoice
          : QuestionTypes.singleChoice;
      if (!value && _question.correctAnswers.length > 1) {
        _question.correctAnswers = [_question.correctAnswers.first];
      }
    });
  }

  bool _isAnswerSelected(int optionIndex) {
    return _question.correctAnswers.contains(optionIndex + 1);
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _save() {
    _syncFromControllers();
    if (_question.isValid) {
      widget.onSave(_question);
      Navigator.pop(context);
    } else {
      setState(() {
        _errorMessage =
            _question.validationError ?? 'Please complete all required fields';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.question != null;
    final canAddOption = _optionControllers.length < widget.maxOptions;

    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.quiz, color: AppColors.primary),
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
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: AppColors.errorContainer,
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: AppIconSizes.md,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: AppIconSizes.md),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Question *',
                        hintText: 'Enter your question',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (_) => _clearError(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'Question Type:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Options *',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Max: ${widget.maxOptions} options',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        if (canAddOption)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add, size: AppIconSizes.md),
                            label: const Text('Add Option'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMultipleChoice
                          ? 'Select all correct answers'
                          : 'Select the correct answer',
                      style: const TextStyle(
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
                                      ? BorderRadius.circular(AppRadius.xs)
                                      : null,
                                  color: isSelected
                                      ? AppColors.success
                                      : AppColors.surfaceWhite,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success
                                        : AppColors.textDisabled,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColors.textOnPrimary,
                                        size: AppIconSizes.md,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                onChanged: (_) => _clearError(),
                              ),
                            ),
                            if (_optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _removeOption(index),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
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
                    InkWell(
                      onTap: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.smAll,
                          border: Border.all(color: AppColors.outline),
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
                            const Text(
                              'Advanced Options',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Text(
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
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Code Snippet',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
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
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          hintText: 'Enter code snippet',
                          border: OutlineInputBorder(),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Alternative Questions',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextButton.icon(
                            onPressed: _addAltQuestion,
                            icon: const Icon(Icons.add, size: AppIconSizes.md),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const Text(
                        'Different ways to phrase the same question',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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
                                    hintText:
                                        'Alternative question ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _removeAltQuestion(index),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Extra Options',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextButton.icon(
                            onPressed: _addExtraOption,
                            icon: const Icon(Icons.add, size: AppIconSizes.md),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const Text(
                        'Additional distractor options for variety',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_extraOptionControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _extraOptionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Extra option ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _removeExtraOption(index),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Option Variants',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Text(
                        'Alternative text for each option (picked randomly)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_optionControllers.length, (
                        optionIndex,
                      ) {
                        final optionText = _optionControllers[optionIndex].text;
                        if (optionText.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final variants =
                            optionIndex < _optionVariantControllers.length
                            ? _optionVariantControllers[optionIndex]
                            : <TextEditingController>[];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Option ${optionIndex + 1}: "${optionText.length > 20 ? '${optionText.substring(0, 20)}...' : optionText}"',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _addOptionVariant(optionIndex),
                                    icon: const Icon(
                                      Icons.add,
                                      size: AppIconSizes.sm,
                                    ),
                                    label: const Text('Add Variant'),
                                  ),
                                ],
                              ),
                              ...List.generate(variants.length, (variantIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    top: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: variants[variantIndex],
                                          decoration: InputDecoration(
                                            hintText:
                                                'Variant ${variantIndex + 1}',
                                            border: const OutlineInputBorder(),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.error,
                                          size: AppIconSizes.md,
                                        ),
                                        onPressed: () => _removeOptionVariant(
                                          optionIndex,
                                          variantIndex,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.outline)),
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
