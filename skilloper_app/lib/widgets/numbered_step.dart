import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NumberedStep extends StatelessWidget {
  final String number;
  final String text;
  final String? description;
  final double circleSize;
  final double fontSize;

  const NumberedStep({
    required this.number,
    required this.text,
    this.description,
    this.circleSize = 28,
    this.fontSize = 14,
    super.key,
  });

  const NumberedStep.compact({
    required this.number,
    required this.text,
    super.key,
  })  : description = null,
        circleSize = 20,
        fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final numberFontSize = circleSize == 20 ? 11.0 : 14.0;

    return Padding(
      padding: description != null ? EdgeInsets.zero : const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment:
            description != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: numberFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: description != null ? 12 : 10),
          Expanded(
            child: description != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
