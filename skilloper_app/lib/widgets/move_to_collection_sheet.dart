import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../theme/app_colors.dart';

/// Bottom sheet for selecting a collection to move a quiz to.
/// Returns:
/// - Collection ID (int) when a collection is selected
/// - -1 when "Remove from Collection" is selected
/// - null when dismissed without selection
class MoveToCollectionSheet extends StatelessWidget {
  final List<Collection> collections;
  final int? currentCollectionId;

  const MoveToCollectionSheet({
    required this.collections,
    this.currentCollectionId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Move to Collection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (currentCollectionId != null)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove from Collection'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ...collections.map(
            (c) => ListTile(
              leading: Icon(
                c.id == currentCollectionId
                    ? Icons.check_circle
                    : Icons.folder_outlined,
                color: c.id == currentCollectionId ? AppColors.primary : null,
              ),
              title: Text(c.name),
              subtitle: Text('${c.quizCount} quizzes'),
              selected: c.id == currentCollectionId,
              onTap: () => Navigator.pop(context, c.id),
            ),
          ),
          if (collections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No collections yet. Add one from the Home screen.',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
