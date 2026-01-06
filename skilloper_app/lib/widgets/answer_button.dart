import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    Color borderColor = AppColors.outlineVariant;
    Color backgroundColor = Colors.white;
    Color textColor = AppColors.textPrimary;
    Color labelColor = AppColors.textTertiary;
    Color labelBackgroundColor = AppColors.surfaceContainer;
    Widget? trailingIcon;

    if (isCorrect) {
      borderColor = AppColors.success;
      backgroundColor = AppColors.successContainer;
      textColor = AppColors.onSuccessContainer;
      labelColor = Colors.white;
      labelBackgroundColor = AppColors.success;
      trailingIcon = Icon(
        Icons.check_circle,
        color: AppColors.success,
        size: 20,
      );
    } else if (isCorrectButNotSelected) {
      borderColor = AppColors.success;
      backgroundColor = Colors.white;
      textColor = AppColors.success;
      labelColor = AppColors.success;
      labelBackgroundColor = Colors.white;
      trailingIcon = Icon(
        Icons.check_circle_outline,
        color: AppColors.success,
        size: 20,
      );
    } else if (isIncorrect) {
      borderColor = AppColors.error;
      backgroundColor = AppColors.errorContainer;
      textColor = AppColors.onErrorContainer;
      labelColor = Colors.white;
      labelBackgroundColor = AppColors.error;
      trailingIcon = Icon(
        Icons.cancel,
        color: AppColors.error,
        size: 20,
      );
    } else if (isSelected) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primaryContainer;
      textColor = AppColors.onPrimaryContainer;
      labelColor = Colors.white;
      labelBackgroundColor = AppColors.primary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (isMultipleChoice) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? labelBackgroundColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? labelBackgroundColor : 
                             isCorrectButNotSelected ? borderColor : const Color(0xFF9CA3AF),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ] else ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: labelBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),

              if (trailingIcon != null) ...[
                const SizedBox(width: 12),
                trailingIcon,
              ],
            ],
          ),
        ),
      ),
    );
  }
}