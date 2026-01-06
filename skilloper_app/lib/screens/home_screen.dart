import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/pagination.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/date_formatter.dart';
import '../utils/debouncer.dart';
import '../widgets/search_filter_bar.dart';
import 'quiz_screen.dart';
import 'create_quiz/create_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  /// Public method to refresh the quiz list.
  /// Called by parent when tab becomes active.
  void refresh() {
    _loadQuizzes(refresh: true);
  }
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));

  // Data state
  List<QuizSummary> _quizzes = [];
  PaginationMeta _pagination = PaginationMeta.initial();

  // Loading states
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _isStartingQuiz = false; // Prevents double-tap on quiz start
  bool _pendingRefresh = false; // Tracks if a refresh was requested during loading
  String? _error;

  // Search, filter, and sort
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';
  String _sortBy = 'date_desc'; // Default sort

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadQuizzes(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  /// Handle scroll to trigger load more
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Load quizzes (initial or refresh)
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
      }
    });

    // Capture current search/filter/sort state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;

    try {
      final result = await _apiService.getQuizSummaries(
        limit: 20,
        offset: 0,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      // Check if search/filter/sort changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter || requestSort != _sortBy || _pendingRefresh) {
        // Query changed or refresh pending - discard stale results and load with current filters
        setState(() {
          _isInitialLoading = false;
        });
        _loadQuizzes(refresh: true);
        return;
      }

      setState(() {
        _quizzes = result.data;
        _pagination = result.pagination;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
      // Check for pending refresh even on error
      if (_pendingRefresh) {
        _loadQuizzes(refresh: true);
      }
    }
  }

  /// Load more quizzes (infinite scroll)
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore || _isInitialLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Capture current state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;
    final requestOffset = _pagination.nextOffset;

    try {
      final result = await _apiService.getQuizSummaries(
        limit: _pagination.limit,
        offset: requestOffset,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      // Check if search/filter/sort changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter || requestSort != _sortBy || _pendingRefresh) {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      // Check for pending refresh even on error
      if (_pendingRefresh) {
        _loadQuizzes(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e')),
        );
      }
    }
  }

  /// Handle search text change with debounce
  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
      });
      _loadQuizzes(refresh: true);
    });
  }

  /// Handle filter change (immediate, no debounce)
  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    _loadQuizzes(refresh: true);
  }

  /// Handle sort change (immediate, no debounce)
  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
    });
    _loadQuizzes(refresh: true);
  }

  Future<void> _startQuiz(QuizSummary summary) async {
    // Prevent double-tap
    if (_isStartingQuiz) return;
    _isStartingQuiz = true;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch full quiz with questions (fresh shuffled data)
      final quiz = await _apiService.getQuiz(summary.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _isStartingQuiz = false;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(quiz: quiz),
        ),
      );
    } catch (e) {
      _isStartingQuiz = false;
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading quiz: $e')),
      );
    }
  }

  Future<void> _editQuiz(QuizSummary summary) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch full quiz with answers included for edit mode
      final quiz = await _apiService.getQuizForEdit(summary.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateQuizScreen(quiz: quiz),
        ),
      );

      // Refresh list after returning
      if (mounted) {
        _loadQuizzes(refresh: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading quiz: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Quiz deleted'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      _loadQuizzes(refresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting quiz: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadQuizzes(refresh: true),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Quizzes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a quiz to test your skills',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),

              // Search and filter bar
              SearchFilterBar(
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

              const SizedBox(height: 16),

              if (_isInitialLoading && _quizzes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading quizzes...',
                          style: TextStyle(color: Color(0xFF6B7280)),
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
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load quizzes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make sure the API is running on localhost:8080',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
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
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? Icons.search_off
                              : Icons.quiz_outlined,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'No matches found'
                              : 'No quizzes available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'Try a different search or filter'
                              : 'Upload some quizzes using the Add tab',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty || _typeFilter.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _typeFilter = '';
                              });
                              _loadQuizzes(refresh: true);
                            },
                            child: const Text('Clear filters'),
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
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the bottom
                      if (index == _quizzes.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final quiz = _quizzes[index];
                      return _QuizListItem(
                        quiz: quiz,
                        onTap: () => _startQuiz(quiz),
                        onEdit: () => _editQuiz(quiz),
                        onDelete: () => _deleteQuiz(quiz),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizListItem extends StatelessWidget {
  final QuizSummary quiz;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuizListItem({
    required this.quiz,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive layout based on available width
            final isNarrowScreen = constraints.maxWidth < 360;

            return Padding(
              padding: EdgeInsets.all(isNarrowScreen ? 12 : 20),
              child: Row(
                children: [
                  // Icon - smaller on narrow screens
                  Container(
                    width: isNarrowScreen ? 44 : 56,
                    height: isNarrowScreen ? 44 : 56,
                    decoration: BoxDecoration(
                      color: quiz.type == 'exam'
                          ? AppColors.examModeContainer
                          : AppColors.practiceModeContainer,
                      borderRadius: BorderRadius.circular(isNarrowScreen ? 10 : 12),
                    ),
                    child: Icon(
                      quiz.type == 'exam' ? AppIcons.examMode : AppIcons.practiceMode,
                      color: quiz.type == 'exam'
                          ? AppColors.examMode
                          : AppColors.practiceMode,
                      size: isNarrowScreen ? 22 : 28,
                    ),
                  ),

                  SizedBox(width: isNarrowScreen ? 12 : 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and type badge
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
                              decoration: BoxDecoration(
                                color: quiz.type == 'exam'
                                    ? AppColors.examModeContainer
                                    : AppColors.practiceModeContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                quiz.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: quiz.type == 'exam'
                                      ? AppColors.onExamModeContainer
                                      : AppColors.onPracticeModeContainer,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (!isNarrowScreen) const SizedBox(height: 6),

                        // Description - only show on wider screens
                        if (!isNarrowScreen && quiz.description.isNotEmpty) ...[
                          Text(
                            quiz.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Stats - compact layout for narrow screens
                        if (isNarrowScreen) ...[
                          const SizedBox(height: 4),
                          // Single row with questions and date
                          Row(
                            children: [
                              const Icon(
                                Icons.quiz_outlined,
                                size: 14,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${quiz.questionCount} questions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: 4),
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
                          // Horizontal layout for wider screens
                          Row(
                            children: [
                              const Icon(
                                Icons.quiz_outlined,
                                size: 16,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${quiz.questionCount} questions',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.schedule,
                                size: 16,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(width: 4),
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
                      ],
                    ),
                  ),

                  SizedBox(width: isNarrowScreen ? 8 : 12),

                  // Three-dot menu
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
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                            const SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
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