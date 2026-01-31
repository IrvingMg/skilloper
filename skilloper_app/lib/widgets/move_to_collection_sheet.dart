import 'package:flutter/material.dart';

import '../constants/limits.dart';
import '../models/collection.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/debouncer.dart';
import 'breadcrumb_navigation.dart';

/// Bottom sheet for selecting a collection to move a quiz to.
/// Returns:
/// - Collection ID (int) when a collection is selected
/// - [UISentinels.removeFromCollection] when "Remove from Collection" is selected
/// - null when dismissed without selection
class MoveToCollectionSheet extends StatefulWidget {
  final int? currentCollectionId;
  final int selectedCount;

  const MoveToCollectionSheet({
    this.currentCollectionId,
    this.selectedCount = 1,
    super.key,
  });

  bool get isBulkMode => selectedCount > 1;

  @override
  State<MoveToCollectionSheet> createState() => _MoveToCollectionSheetState();
}

class _MoveToCollectionSheetState extends State<MoveToCollectionSheet>
    with CollectionNavigationMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  List<Collection> _collections = [];
  List<FlatCollectionItem> _flatCollections = [];
  List<FlatCollectionItem> _filteredFlatCollections = [];
  bool _isLoading = true;
  String? _error;
  bool _hasFlatCollectionsError = false;
  String _searchQuery = '';
  bool _isSearchMode = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _loadFlatCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
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

  Future<void> _loadFlatCollections() async {
    try {
      final result = await _apiService.getCollectionsFlat();
      if (mounted) {
        setState(() {
          _flatCollections = result;
          _filteredFlatCollections = result;
          _hasFlatCollectionsError = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _hasFlatCollectionsError = true;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
        _isSearchMode = query.isNotEmpty;
        if (_isSearchMode) {
          final lowerQuery = query.toLowerCase();
          _filteredFlatCollections = _flatCollections.where((c) {
            return c.name.toLowerCase().contains(lowerQuery) ||
                c.fullPath.toLowerCase().contains(lowerQuery);
          }).toList();
        } else {
          _filteredFlatCollections = _flatCollections;
        }
      });
    });
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search collections...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFlatList() {
    if (_hasFlatCollectionsError) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Failed to load collections for search. Use hierarchical view.',
          style: TextStyle(color: AppColors.textTertiary),
        ),
      );
    }

    if (_filteredFlatCollections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No collections match "$_searchQuery"'
              : 'No collections yet.',
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _filteredFlatCollections.map((c) {
        final isCurrentCollection = c.id == widget.currentCollectionId;
        return ListTile(
          leading: Icon(
            isCurrentCollection ? Icons.check_circle : Icons.folder_outlined,
            color: isCurrentCollection ? AppColors.primary : null,
          ),
          title: Text(c.name),
          subtitle: Text(
            c.fullPath,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isCurrentCollection,
          onTap: () => Navigator.pop(context, c.id),
        );
      }).toList(),
    );
  }

  Widget _buildHierarchicalList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._collections.map(
          (c) => ListTile(
            leading: Icon(
              c.id == widget.currentCollectionId
                  ? Icons.check_circle
                  : Icons.folder_outlined,
              color: c.id == widget.currentCollectionId
                  ? AppColors.primary
                  : null,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isBulkMode
        ? 'Move ${widget.selectedCount} ${widget.selectedCount == 1 ? 'quiz' : 'quizzes'} to...'
        : 'Move to Collection';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Search field
              _buildSearchField(),

              // Breadcrumb navigation (only in hierarchical mode)
              if (!_isSearchMode && breadcrumbs.isNotEmpty)
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
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Remove from collection option
                      if (widget.currentCollectionId != null ||
                          widget.isBulkMode)
                        ListTile(
                          leading: const Icon(Icons.remove_circle_outline),
                          title: const Text('Remove from Collection'),
                          onTap: () => Navigator.pop(
                            context,
                            UISentinels.removeFromCollection,
                          ),
                        ),

                      // Show flat list when searching, hierarchical otherwise
                      if (_isSearchMode)
                        _buildFlatList()
                      else
                        _buildHierarchicalList(),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
