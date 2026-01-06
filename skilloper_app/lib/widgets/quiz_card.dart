import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../theme/app_colors.dart';

class QuizCard extends StatelessWidget {
  final QuizSummary quiz;
  final VoidCallback onTap;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPractice = quiz.isPracticeMode;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPractice
                          ? AppColors.practiceModeContainer
                          : AppColors.examModeContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPractice ? Icons.lightbulb : Icons.quiz,
                          size: 12,
                          color: isPractice
                              ? AppColors.onPracticeModeContainer
                              : AppColors.onExamModeContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          quiz.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPractice
                                ? AppColors.onPracticeModeContainer
                                : AppColors.onExamModeContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                quiz.description,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Metadata
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.quiz_outlined,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.questionCount} questions',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${quiz.estimatedMinutes} min',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
