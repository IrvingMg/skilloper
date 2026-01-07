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
    super.key,
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isIncorrect,
    this.isCorrectButNotSelected = false,
    required this.isDisabled,
    this.isMultipleChoice = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on state
    Color borderColor = AppColors.outline;
    Color backgroundColor = AppColors.surfaceWhite;
    Color textColor = AppColors.textPrimary;
    Color labelColor = AppColors.textTertiary;
    Color labelBackgroundColor = AppColors.surfaceContainer;
    Widget? trailingIcon;

    if (isCorrect) {
      // Correct answer - green theme (matches summary cards)
      borderColor = AppColors.success;
      backgroundColor = AppColors.successContainer;
      textColor = AppColors.onSuccessContainer;
      labelColor = AppColors.textOnPrimary;
      labelBackgroundColor = AppColors.success;
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
      labelColor = AppColors.success;
      labelBackgroundColor = AppColors.surfaceWhite;
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
      labelColor = AppColors.textOnPrimary;
      labelBackgroundColor = AppColors.error;
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
      labelColor = AppColors.textOnPrimary;
      labelBackgroundColor = AppColors.primary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
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
              if (isMultipleChoice) ...[
                // Checkbox indicator for multiple choice
                _buildCheckbox(labelBackgroundColor, borderColor),
              ] else ...[
                // Letter badge for single choice (A, B, C, D)
                _buildLetterBadge(labelBackgroundColor, labelColor),
              ],

              SizedBox(width: AppSpacing.md + 2),

              // Answer text
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
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
    );
  }

  Widget _buildLetterBadge(Color backgroundColor, Color textColor) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          String.fromCharCode(65 + index), // A, B, C, D
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
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
        border: Border.all(
          color: checkboxBorder,
          width: 2,
        ),
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
