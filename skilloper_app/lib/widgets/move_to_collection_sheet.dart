import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'breadcrumb_navigation.dart';

/// Bottom sheet for selecting a collection to move a quiz to.
/// Returns:
/// - Collection ID (int) when a collection is selected
/// - -1 when "Remove from Collection" is selected
/// - null when dismissed without selection
class MoveToCollectionSheet extends StatefulWidget {
  final int? currentCollectionId;

  const MoveToCollectionSheet({
    this.currentCollectionId,
    super.key,
  });

  @override
  State<MoveToCollectionSheet> createState() => _MoveToCollectionSheetState();
}

class _MoveToCollectionSheetState extends State<MoveToCollectionSheet>
    with CollectionNavigationMixin {
  final ApiService _apiService = ApiService();

  List<Collection> _collections = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.getCollections(
        limit: 100,
        parentId: currentParentId,
      );
      if (mounted) {
        setState(() {
          _collections = result.data;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleNavigateIntoCollection(Collection collection) {
    navigateIntoCollection(collection, onNavigate: _loadCollections);
  }

  void _handleNavigateToBreadcrumb(int index) {
    navigateToBreadcrumb(index, onNavigate: _loadCollections);
  }

  void _handleNavigateUp() {
    navigateUp(onNavigate: _loadCollections);
  }

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

          // Breadcrumb navigation
          if (breadcrumbs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BreadcrumbNavigation(
                breadcrumbs: breadcrumbs,
                onNavigateUp: _handleNavigateUp,
                onNavigateToBreadcrumb: _handleNavigateToBreadcrumb,
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading collections: $_error',
                style: const TextStyle(color: AppColors.error),
              ),
            )
          else ...[
            if (widget.currentCollectionId != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from Collection'),
                onTap: () => Navigator.pop(context, -1),
              ),
            ..._collections.map(
              (c) => ListTile(
                leading: Icon(
                  c.id == widget.currentCollectionId
                      ? Icons.check_circle
                      : Icons.folder_outlined,
                  color: c.id == widget.currentCollectionId ? AppColors.primary : null,
                ),
                title: Text(c.name),
                subtitle: Text(
                  c.hasChildren
                      ? '${c.totalQuizCount} quizzes total'
                      : '${c.quizCount} quizzes',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _handleNavigateIntoCollection(c),
                ),
                selected: c.id == widget.currentCollectionId,
                onTap: () => Navigator.pop(context, c.id),
              ),
            ),
            if (_collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  breadcrumbs.isEmpty
                      ? 'No collections yet. Add one from the Home screen.'
                      : 'No subcollections here.',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
