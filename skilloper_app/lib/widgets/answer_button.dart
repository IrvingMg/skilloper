import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Answer button widget for quiz questions
/// Supports single choice (radio) and multiple choice (checkbox) modes
/// with various visual states: unselected, selected, correct, incorrect
class AnswerButton extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isIncorrect;
  final bool isCorrectButNotSelected;
  final bool isDisabled;
  final bool isMultipleChoice;
  final VoidCallback onTap;

  const AnswerButton({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isIncorrect,
    required this.isDisabled,
    required this.onTap,
    super.key,
    this.isCorrectButNotSelected = false,
    this.isMultipleChoice = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on state
    Color borderColor = AppColors.outline;
    Color backgroundColor = AppColors.surfaceWhite;
    Color textColor = AppColors.textPrimary;
    Color checkboxFillColor = AppColors.surfaceContainer;
    Widget? trailingIcon;

    if (isCorrect) {
      // Correct answer - green theme (matches summary cards)
      borderColor = AppColors.success;
      backgroundColor = AppColors.successContainer;
      textColor = AppColors.onSuccessContainer;
      checkboxFillColor = AppColors.success;
      trailingIcon = const Icon(
        Icons.check_circle,
        color: AppColors.success,
        size: AppIconSizes.xl,
      );
    } else if (isCorrectButNotSelected) {
      // Correct but user didn't select it - outlined green (no fill) to indicate "also correct"
      borderColor = AppColors.success.withValues(alpha: 0.5);
      backgroundColor = AppColors.surfaceWhite; // No green fill
      textColor = AppColors.textPrimary;
      // checkboxFillColor stays default - checkbox renders transparent for this state
      trailingIcon = Icon(
        Icons.check_circle_outline,
        color: AppColors.success.withValues(alpha: 0.7),
        size: AppIconSizes.xl,
      );
    } else if (isIncorrect) {
      // Incorrect answer - red theme
      borderColor = AppColors.error;
      backgroundColor = AppColors.errorContainer;
      textColor = AppColors.onErrorContainer;
      checkboxFillColor = AppColors.error;
      trailingIcon = const Icon(
        Icons.cancel,
        color: AppColors.error,
        size: AppIconSizes.xl,
      );
    } else if (isSelected) {
      // Selected (before validation) - primary violet
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primaryContainer;
      textColor = AppColors.onPrimaryContainer;
      checkboxFillColor = AppColors.primary;
    }

    final String stateLabel = isCorrect
        ? 'Correct answer'
        : isIncorrect
        ? 'Incorrect answer'
        : isCorrectButNotSelected
        ? 'Correct answer, not selected'
        : isSelected
        ? 'Selected'
        : '';

    final String optionLabel = 'Option ${index + 1}';

    return Semantics(
      button: true,
      enabled: !isDisabled,
      selected: isSelected,
      label:
          '$optionLabel: $text${stateLabel.isNotEmpty ? '. $stateLabel' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: AppRadius.mdAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: borderColor,
                width: isCorrectButNotSelected ? 1.5 : 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              boxShadow: isSelected && !isCorrect && !isIncorrect
                  ? AppShadows.sm
                  : null,
            ),
            child: Row(
              children: [
                // Keyboard key hint (shows shortcut number)
                _buildKeyboardHint(),

                if (isMultipleChoice) ...[
                  const SizedBox(width: AppSpacing.sm),
                  // Checkbox indicator for multiple choice
                  _buildCheckbox(checkboxFillColor, borderColor),
                ],

                const SizedBox(width: AppSpacing.md + 2),

                // Answer text
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),

                // Trailing icon (check/cancel)
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardHint() {
    // Styled like a keyboard key - subtle hint for keyboard shortcuts
    // Uses own background to stay visible on colored answer states
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // ~10% black for consistent shadow
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(Color fillColor, Color borderColor) {
    final bool showCheck = isSelected || isCorrect || isCorrectButNotSelected;
    final Color checkboxBorder = isSelected
        ? fillColor
        : isCorrectButNotSelected
        ? AppColors.success.withValues(alpha: 0.5)
        : AppColors.textDisabled;

    // For "correct but not selected", no fill - just outlined
    final Color checkboxFill = isCorrectButNotSelected
        ? Colors.transparent
        : (isSelected ? fillColor : Colors.transparent);

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checkboxFill,
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: checkboxBorder, width: 2),
      ),
      child: showCheck
          ? Icon(
              Icons.check,
              color: isCorrectButNotSelected
                  ? AppColors.success.withValues(alpha: 0.7)
                  : AppColors.textOnPrimary,
              size: AppIconSizes.sm,
            )
          : null,
    );
  }
}
