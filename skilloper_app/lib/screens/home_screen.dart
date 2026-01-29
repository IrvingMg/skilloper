import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/limits.dart';
import '../models/attempt.dart';
import '../models/collection.dart';
import '../models/pagination.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/debouncer.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/breadcrumb_navigation.dart';
import '../widgets/collection_chip.dart';
import '../widgets/collection_dialog.dart';
import '../widgets/move_to_collection_sheet.dart';
import '../widgets/quiz_list_item.dart';
import '../widgets/search_filter_bar.dart';
import 'create_quiz/create_quiz_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;

  const HomeScreen({super.key, this.onNavigateToAdd});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with CollectionNavigationMixin {
  static const double _collectionsScrollDelta = 200;

  final ApiService _apiService = ApiService();

  void refresh() {
    _loadQuizzes(refresh: true);
    _loadCollections();
  }

  final ScrollController _scrollController = ScrollController();
  final ScrollController _collectionsScrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  List<QuizSummary> _quizzes = [];
  List<Collection> _collections = [];
  PaginationMeta _pagination = PaginationMeta.initial();

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _isStartingQuiz = false;
  bool _pendingRefresh = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';
  String _sortBy = 'date_desc';
  int? _selectedCollectionId; // null means "All Quizzes"

  // Selection mode state
  bool _isSelectionMode = false;
  Set<int> _selectedQuizIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _collectionsScrollController.addListener(_updateScrollArrows);
    _loadQuizzes(refresh: true);
    _loadCollections();
  }

  void _updateScrollArrows() {
    if (!_collectionsScrollController.hasClients) return;
    final position = _collectionsScrollController.position;
    // Use small tolerance for floating point comparison
    const tolerance = 1.0;
    final canLeft = position.pixels > tolerance;
    final canRight = position.pixels < position.maxScrollExtent - tolerance;
    final canScroll = position.maxScrollExtent > tolerance;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canScroll && canLeft;
        _canScrollRight = canScroll && canRight;
      });
    }
  }

  void _scrollCollections(double delta) {
    final position = _collectionsScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _collectionsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildScrollArrow(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0.8),
            backgroundColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.only(
              left: isLeft ? 4 : 16,
              right: isLeft ? 16 : 4,
              top: 6,
              bottom: 6,
            ),
            child: Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadCollections() async {
    try {
      final result = await _apiService.getCollections(
        limit: 100,
        parentId: currentParentId,
      );
      if (mounted) {
        setState(() {
          _collections = result.data;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateScrollArrows();
        });
      }
    } on Exception catch (e) {
      // Collections are optional for the move menu - log and continue
      debugPrint('Failed to load collections for move menu: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _collectionsScrollController.removeListener(_updateScrollArrows);
    _collectionsScrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadQuizzes({bool refresh = false}) async {
    // If already loading, mark that a refresh is pending
    if (_isInitialLoading) {
      _pendingRefresh = true;
      return;
    }

    _pendingRefresh = false;
    setState(() {
      _isInitialLoading = true;
      _error = null;
      if (refresh) {
        _quizzes = [];
        _pagination = PaginationMeta.initial();
        // Keep selection mode active but IDs will be filtered after load
      }
    });

    // Capture current search/filter/sort/collection state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;
    final requestCollectionId = _selectedCollectionId;

    try {
      final result = await _apiService.getQuizSummaries(
        limit: 20,
        offset: 0,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
        collectionId: _selectedCollectionId,
      );

      if (!mounted) return;
      // Check if search/filter/sort/collection changed while request was in flight
      if (requestSearch != _searchQuery ||
          requestType != _typeFilter ||
          requestSort != _sortBy ||
          requestCollectionId != _selectedCollectionId ||
          _pendingRefresh) {
        // Query changed or refresh pending - discard stale results and load with current filters
        setState(() {
          _isInitialLoading = false;
        });
        unawaited(_loadQuizzes(refresh: true));
        return;
      }

      setState(() {
        _quizzes = result.data;
        _pagination = result.pagination;
        _isInitialLoading = false;
        // Filter selected IDs to only keep those visible in current results
        if (_isSelectionMode && _selectedQuizIds.isNotEmpty) {
          final visibleIds = result.data.map((q) => q.id).toSet();
          _selectedQuizIds = _selectedQuizIds.intersection(visibleIds);
          // Exit selection mode if no selections remain
          if (_selectedQuizIds.isEmpty) {
            _isSelectionMode = false;
          }
        }
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
      // Check for pending refresh even on error
      if (_pendingRefresh) {
        unawaited(_loadQuizzes(refresh: true));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore || _isInitialLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Capture current state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;
    final requestCollectionId = _selectedCollectionId;
    final requestOffset = _pagination.nextOffset;

    try {
      final result = await _apiService.getQuizSummaries(
        limit: _pagination.limit,
        offset: requestOffset,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
        collectionId: _selectedCollectionId,
      );

      if (!mounted) return;
      // Check if search/filter/sort/collection changed while request was in flight
      if (requestSearch != _searchQuery ||
          requestType != _typeFilter ||
          requestSort != _sortBy ||
          requestCollectionId != _selectedCollectionId ||
          _pendingRefresh) {
        // Query changed or refresh pending - discard stale results; a fresh load should already be in progress
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _quizzes.addAll(result.data);
        _pagination = result.pagination;
        _isLoadingMore = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      // Check for pending refresh even on error
      if (_pendingRefresh) {
        unawaited(_loadQuizzes(refresh: true));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load more: $e')));
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
      });
      unawaited(_loadQuizzes(refresh: true));
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    unawaited(_loadQuizzes(refresh: true));
  }

  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
    });
    unawaited(_loadQuizzes(refresh: true));
  }

  void _onCollectionNavigate() {
    _selectedCollectionId = currentParentId;
    unawaited(_loadCollections());
    unawaited(_loadQuizzes(refresh: true));
  }

  void _handleNavigateIntoCollection(Collection collection) {
    navigateIntoCollection(collection, onNavigate: _onCollectionNavigate);
  }

  void _handleNavigateToBreadcrumb(int index) {
    navigateToBreadcrumb(index, onNavigate: _onCollectionNavigate);
  }

  void _handleNavigateUp() {
    navigateUp(onNavigate: _onCollectionNavigate);
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _typeFilter.isNotEmpty ||
      _selectedCollectionId != null ||
      currentParentId != null;

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = '';
      _selectedCollectionId = null;
    });
    resetNavigation(
      onNavigate: () {
        _loadCollections();
        _loadQuizzes(refresh: true);
      },
    );
  }

  // Selection mode methods
  void _enterSelectionMode(int initialQuizId) {
    setState(() {
      _isSelectionMode = true;
      _selectedQuizIds = {initialQuizId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedQuizIds = {};
    });
  }

  void _toggleQuizSelection(int quizId) {
    setState(() {
      if (_selectedQuizIds.contains(quizId)) {
        _selectedQuizIds.remove(quizId);
        if (_selectedQuizIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedQuizIds.add(quizId);
      }
    });
  }

  void _selectAllQuizzes() {
    setState(() {
      _selectedQuizIds = _quizzes.map((q) => q.id).toSet();
    });
  }

  void _deselectAllQuizzes() {
    setState(() {
      _selectedQuizIds = {};
      _isSelectionMode = false;
    });
  }

  Future<void> _bulkMoveToCollection() async {
    final selectedCollectionId = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MoveToCollectionSheet(
        selectedCount: _selectedQuizIds.length,
      ),
    );

    if (selectedCollectionId == null || !mounted) return;

    final targetCollectionId = selectedCollectionId == UISentinels.removeFromCollection
        ? null
        : selectedCollectionId;

    try {
      await _apiService.bulkSetQuizCollection(
        _selectedQuizIds.toList(),
        targetCollectionId,
      );

      if (!mounted) return;

      showSuccessSnackBar(
        context,
        targetCollectionId == null
            ? 'Removed ${_selectedQuizIds.length} quizzes from collection'
            : 'Moved ${_selectedQuizIds.length} quizzes to collection',
      );

      _exitSelectionMode();
      unawaited(_loadQuizzes(refresh: true));
      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error moving quizzes: $e');
    }
  }

  Future<void> _bulkDeleteQuizzes() async {
    final count = _selectedQuizIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quizzes'),
        content: Text(
          'Are you sure you want to delete $count ${count == 1 ? 'quiz' : 'quizzes'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _apiService.bulkDeleteQuizzes(_selectedQuizIds.toList());

      if (!mounted) return;

      showSuccessSnackBar(context, 'Deleted $count quizzes');

      _exitSelectionMode();
      unawaited(_loadQuizzes(refresh: true));
      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error deleting quizzes: $e');
    }
  }

  Future<void> _createCollection() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CollectionDialog(),
    );

    if (result == null || !mounted) return;

    try {
      final data = <String, dynamic>{...result};
      if (currentParentId != null) {
        data['parent_id'] = currentParentId;
      }
      await _apiService.createCollection(data);
      if (!mounted) return;

      showSuccessSnackBar(context, 'Collection created');

      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error creating collection: $e');
    }
  }

  Future<void> _renameCollection(Collection collection) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => CollectionDialog(initialName: collection.name),
    );

    if (result == null || !mounted) return;

    try {
      await _apiService.updateCollection(collection.id, result);
      if (!mounted) return;

      showSuccessSnackBar(context, 'Collection updated');

      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error updating collection: $e');
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          'Are you sure you want to delete "${collection.name}"? '
          'Quizzes in this collection will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _apiService.deleteCollection(collection.id);

      if (!mounted) return;

      // If currently filtering by this collection, reset to "All"
      if (_selectedCollectionId == collection.id) {
        setState(() {
          _selectedCollectionId = null;
        });
        unawaited(_loadQuizzes(refresh: true));
      }

      showSuccessSnackBar(context, 'Collection deleted');

      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error deleting collection: $e');
    }
  }

  Future<void> _startQuiz(QuizSummary summary) async {
    // Prevent double-tap
    if (_isStartingQuiz) return;

    // For exam mode, show confirmation dialog first
    if (!summary.isPracticeMode) {
      _showExamConfirmation(summary);
      return;
    }

    // Practice mode: load quiz and navigate directly
    unawaited(_loadAndNavigateToQuiz(summary, attemptId: null));
  }

  void _showExamConfirmation(QuizSummary summary) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Start Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are about to start an exam. Please note:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.history,
              'Your attempt will be recorded in history',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.timer_outlined,
              'Leaving early will mark it as abandoned',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.visibility_off,
              'Answers are revealed only at the end',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startExamWithAttempt(summary);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Start Exam'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startExamWithAttempt(QuizSummary summary) async {
    if (_isStartingQuiz) return;
    _isStartingQuiz = true;

    // Show loading dialog
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // Fetch quiz first to prevent orphaned attempts if this fails
      final quiz = await _apiService.getQuiz(summary.id);

      if (!mounted) return;

      final request = StartAttemptRequest(quizId: summary.id);
      final attempt = await _apiService.startAttempt(request);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _isStartingQuiz = false;

      // Navigate with the pre-created attempt ID
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => QuizScreen(quiz: quiz, attemptId: attempt.id),
          ),
        ),
      );
    } on Exception catch (e) {
      _isStartingQuiz = false;
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error dialog instead of snackbar for better visibility
      _showExamStartError(e.toString());
    }
  }

  void _showExamStartError(String error) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Cannot Start Exam'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAndNavigateToQuiz(
    QuizSummary summary, {
    int? attemptId,
  }) async {
    if (_isStartingQuiz) return;
    _isStartingQuiz = true;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final quiz = await _apiService.getQuiz(summary.id);

      if (!mounted) return;
      Navigator.pop(context);
      _isStartingQuiz = false;

      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => QuizScreen(quiz: quiz, attemptId: attemptId),
          ),
        ),
      );
    } on Exception catch (e) {
      _isStartingQuiz = false;
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading quiz: $e')));
    }
  }

  Future<void> _editQuiz(QuizSummary summary) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final quiz = await _apiService.getQuizForEdit(summary.id);

      if (!mounted) return;
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => CreateQuizScreen(quiz: quiz),
        ),
      );

      if (mounted) {
        unawaited(_loadQuizzes(refresh: true));
      }
    } on Exception catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading quiz: $e')));
    }
  }

  Future<void> _deleteQuiz(QuizSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text(
          'Are you sure you want to delete "${summary.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _apiService.deleteQuiz(summary.id);

      if (!mounted) return;

      showSuccessSnackBar(context, 'Quiz deleted');

      unawaited(_loadQuizzes(refresh: true));
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error deleting quiz: $e');
    }
  }

  Future<void> _moveQuizToCollection(QuizSummary quiz) async {
    final selectedCollectionId = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          MoveToCollectionSheet(currentCollectionId: quiz.collectionId),
    );

    if (selectedCollectionId == UISentinels.removeFromCollection &&
        quiz.collectionId != null) {
      await _setQuizCollection(quiz.id, null);
    } else if (selectedCollectionId != null &&
        selectedCollectionId != UISentinels.removeFromCollection &&
        selectedCollectionId != quiz.collectionId) {
      await _setQuizCollection(quiz.id, selectedCollectionId);
    }
  }

  Future<void> _setQuizCollection(int quizId, int? collectionId) async {
    try {
      await _apiService.setQuizCollection(quizId, collectionId);
      if (!mounted) return;

      showSuccessSnackBar(
        context,
        collectionId == null
            ? 'Removed from collection'
            : 'Moved to collection',
      );

      unawaited(_loadQuizzes(refresh: true));
      unawaited(_loadCollections());
    } on Exception catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Error updating quiz: $e');
    }
  }

  Widget _buildSelectionHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
          tooltip: 'Cancel selection',
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${_selectedQuizIds.length} selected',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _selectedQuizIds.length == _quizzes.length
              ? _deselectAllQuizzes
              : _selectAllQuizzes,
          child: Text(
            _selectedQuizIds.length == _quizzes.length
                ? 'Deselect All'
                : 'Select All',
          ),
        ),
      ],
    );
  }

  Widget _buildNormalHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Quizzes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'Choose a quiz to test your skills',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadQuizzes(refresh: true),
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section - changes based on selection mode
              if (_isSelectionMode)
                _buildSelectionHeader()
              else
                _buildNormalHeader(),

              // Collections section with breadcrumb navigation
              const SizedBox(height: AppSpacing.lg),

              // Breadcrumb row (only show when navigated into subcollections)
              if (breadcrumbs.isNotEmpty) ...[
                BreadcrumbNavigation(
                  breadcrumbs: breadcrumbs,
                  onNavigateUp: _handleNavigateUp,
                  onNavigateToBreadcrumb: _handleNavigateToBreadcrumb,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Collection chips row with overlapping scroll arrows
              SizedBox(
                  height: 36,
                  child: Stack(
                    children: [
                      ListView.separated(
                        controller: _collectionsScrollController,
                        scrollDirection: Axis.horizontal,
                        // At root level: "All" chip + collections + "Add" chip
                        // Inside subcollection: collections + "Add" chip (breadcrumbs show "All")
                        itemCount: breadcrumbs.isEmpty
                            ? _collections.length + 2
                            : _collections.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          // At root level, show "All" chip first
                          if (breadcrumbs.isEmpty && index == 0) {
                            return CollectionChip(
                              label: 'All',
                              isSelected: _selectedCollectionId == null,
                              onTap: () {}, // Already at root, no-op
                            );
                          }
                          // Adjust index for collections when "All" chip is shown
                          final collectionIndex = breadcrumbs.isEmpty
                              ? index - 1
                              : index;
                          // Last: "Add" chip
                          if (collectionIndex == _collections.length) {
                            return AddCollectionChip(
                              onTap: _createCollection,
                            );
                          }
                          // Collection chips with actions
                          final collection = _collections[collectionIndex];
                          return CollectionChip(
                            label: collection.name,
                            isSelected:
                                _selectedCollectionId == collection.id,
                            color: AppColors.getCollectionColor(
                              collection.id,
                            ),
                            onTap: () =>
                                _handleNavigateIntoCollection(collection),
                            onRename: () => _renameCollection(collection),
                            onDelete: () => _deleteCollection(collection),
                          );
                        },
                      ),
                      // Left arrow overlay
                      if (_canScrollLeft)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: _buildScrollArrow(
                            context,
                            icon: Icons.chevron_left,
                            isLeft: true,
                            onTap: () =>
                                _scrollCollections(-_collectionsScrollDelta),
                          ),
                        ),
                      // Right arrow overlay
                      if (_canScrollRight)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: _buildScrollArrow(
                            context,
                            icon: Icons.chevron_right,
                            isLeft: false,
                            onTap: () =>
                                _scrollCollections(_collectionsScrollDelta),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SearchFilterBar(
                      searchHint: 'Search quizzes...',
                      searchController: _searchController,
                      onSearchChanged: _onSearchChanged,
                      filterOptions: kQuizTypeFilterOptions,
                      selectedFilter: _typeFilter,
                      onFilterChanged: _onFilterChanged,
                      sortOptions: kQuizSortOptions,
                      selectedSort: _sortBy,
                      onSortChanged: _onSortChanged,
                    ),
                  ),
                  // Only show selection mode button when not already in selection mode
                  if (_quizzes.isNotEmpty && !_isSelectionMode) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(Icons.checklist),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                      tooltip: 'Select multiple quizzes',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              if (_isInitialLoading && _quizzes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.lg),
                        Text(
                          'Loading quizzes...',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null && _quizzes.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Failed to load quizzes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Make sure the API is running on localhost:8080',
                          style: TextStyle(color: AppColors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                          onPressed: () => _loadQuizzes(refresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_quizzes.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hasActiveFilters
                              ? Icons.search_off
                              : Icons.quiz_outlined,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _hasActiveFilters
                              ? 'No matches found'
                              : 'No quizzes yet',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _hasActiveFilters
                                ? 'Try a different search or filter'
                                : 'Create quizzes from your study notes using ChatGPT or Claude',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: AppSpacing.lg),
                          TextButton(
                            onPressed: _clearAllFilters,
                            child: const Text('Clear filters'),
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton.icon(
                            onPressed: widget.onNavigateToAdd,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Quiz'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: _quizzes.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == _quizzes.length) {
                        return const Padding(
                          padding: AppSpacing.verticalLg,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final quiz = _quizzes[index];
                      return QuizListItem(
                        quiz: quiz,
                        onTap: () => _startQuiz(quiz),
                        onEdit: () => _editQuiz(quiz),
                        onDelete: () => _deleteQuiz(quiz),
                        onMoveToCollection: () => _moveQuizToCollection(quiz),
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedQuizIds.contains(quiz.id),
                        onToggleSelection: () => _toggleQuizSelection(quiz.id),
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _enterSelectionMode(quiz.id);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isSelectionMode && _selectedQuizIds.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bulkMoveToCollection,
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: const Text('Move'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bulkDeleteQuizzes,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
