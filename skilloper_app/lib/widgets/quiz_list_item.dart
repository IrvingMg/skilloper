import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/date_formatter.dart';

class QuizListItem extends StatelessWidget {
  final QuizSummary quiz;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveToCollection;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onLongPress;

  const QuizListItem({
    required this.quiz,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToCollection,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.onLongPress,
    super.key,
  });

  Widget? _buildCollectionBadges(bool isNarrowScreen) {
    final path = quiz.collectionPath;
    if (path.isEmpty) return null;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: path.map((breadcrumb) {
        final color = AppColors.getCollectionColor(breadcrumb.id);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrowScreen ? 6 : 8,
            vertical: isNarrowScreen ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            breadcrumb.name,
            style: TextStyle(
              fontSize: isNarrowScreen ? 10 : 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectionMode ? onToggleSelection : onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.lgAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = constraints.maxWidth < 360;

            return Padding(
              padding: EdgeInsets.all(isNarrowScreen ? 12 : 20),
              child: Row(
                children: [
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelection?.call(),
                      activeColor: AppColors.primary,
                    ),
                    SizedBox(width: isNarrowScreen ? 4 : 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                quiz.title,
                                style: TextStyle(
                                  fontSize: isNarrowScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: isNarrowScreen ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrowScreen ? 6 : 8,
                                vertical: 3,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: AppRadius.xsAll,
                              ),
                              child: Text(
                                quiz.type.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isNarrowScreen)
                          const SizedBox(height: AppSpacing.xs),
                        if (!isNarrowScreen && quiz.description.isNotEmpty) ...[
                          Text(
                            quiz.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (isNarrowScreen) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.quiz_outlined,
                                size: AppIconSizes.xs,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '${quiz.questionCount} questions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              const Icon(
                                Icons.schedule,
                                size: AppIconSizes.xs,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                formatRelativeDate(quiz.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.quiz_outlined,
                                size: AppIconSizes.sm,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '${quiz.questionCount} questions',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              const Icon(
                                Icons.schedule,
                                size: AppIconSizes.sm,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                formatRelativeDate(quiz.createdAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Collection badges (shows full path: ancestors + current)
                        if (quiz.collectionPath.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _buildCollectionBadges(isNarrowScreen)!,
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isNarrowScreen ? AppSpacing.sm : AppSpacing.md,
                  ),
                  if (!isSelectionMode)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: isNarrowScreen ? 20 : 24,
                        color: AppColors.textTertiary,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        } else if (value == 'move') {
                          onMoveToCollection();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: AppIconSizes.lg),
                              SizedBox(width: AppSpacing.md),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              Icon(
                                Icons.drive_file_move_outline,
                                size: AppIconSizes.lg,
                              ),
                              SizedBox(width: AppSpacing.md),
                              Text('Move to Collection'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: AppIconSizes.lg,
                                color: AppColors.error,
                              ),
                              SizedBox(width: AppSpacing.md),
                              Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
