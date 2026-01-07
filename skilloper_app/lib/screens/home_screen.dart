import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/pagination.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
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
  final DeviceService _deviceService = DeviceService();

  void refresh() {
    _loadQuizzes(refresh: true);
  }
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));

  List<QuizSummary> _quizzes = [];
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

  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
      });
      _loadQuizzes(refresh: true);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    _loadQuizzes(refresh: true);
  }

  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
    });
    _loadQuizzes(refresh: true);
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
    _loadAndNavigateToQuiz(summary, attemptId: null);
  }

  void _showExamConfirmation(QuizSummary summary) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const QuizModeIcon(
                isExamMode: true,
                size: AppIconSizes.xxl,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Start Exam'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are about to start an exam. Please note:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.history, 'Your attempt will be recorded in history'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.timer_outlined, 'Leaving early will mark it as abandoned'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.visibility_off, 'Answers are revealed only at the end'),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Load quiz and create attempt in parallel
      final quizFuture = _apiService.getQuiz(summary.id);
      final deviceId = await _deviceService.getDeviceId();

      final quiz = await quizFuture;

      // Create the attempt (this checks concurrent session limits)
      final request = StartAttemptRequest(
        deviceId: deviceId,
        quizId: summary.id,
        quizTitle: summary.title,
        quizType: summary.type,
        totalCount: summary.questionCount,
      );

      final attempt = await _apiService.startAttempt(request);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _isStartingQuiz = false;

      // Navigate with the pre-created attempt ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(quiz: quiz, attemptId: attempt.id),
        ),
      );
    } catch (e) {
      _isStartingQuiz = false;
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error dialog instead of snackbar for better visibility
      _showExamStartError(e.toString());
    }
  }

  void _showExamStartError(String error) {
    showDialog(
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

  Future<void> _loadAndNavigateToQuiz(QuizSummary summary, {int? attemptId}) async {
    if (_isStartingQuiz) return;
    _isStartingQuiz = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final quiz = await _apiService.getQuiz(summary.id);

      if (!mounted) return;
      Navigator.pop(context);
      _isStartingQuiz = false;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(quiz: quiz, attemptId: attemptId),
        ),
      );
    } catch (e) {
      _isStartingQuiz = false;
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading quiz: $e')),
      );
    }
  }

  Future<void> _editQuiz(QuizSummary summary) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final quiz = await _apiService.getQuizForEdit(summary.id);

      if (!mounted) return;
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateQuizScreen(quiz: quiz),
        ),
      );

      if (mounted) {
        _loadQuizzes(refresh: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
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
              const Icon(Icons.check_circle, color: AppColors.textOnPrimary, size: AppIconSizes.lg),
              const SizedBox(width: AppSpacing.sm),
              const Text('Quiz deleted'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
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
          padding: AppSpacing.allLg,
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
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Choose a quiz to test your skills',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

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
                          style: TextStyle(
                            color: AppColors.textTertiary,
                          ),
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
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? Icons.search_off
                              : Icons.quiz_outlined,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'No matches found'
                              : 'No quizzes available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                          const SizedBox(height: AppSpacing.lg),
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
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == _quizzes.length) {
                        return Padding(
                          padding: AppSpacing.verticalLg,
                          child: const Center(child: CircularProgressIndicator()),
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
        borderRadius: AppRadius.lgAll,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = constraints.maxWidth < 360;

            return Padding(
              padding: EdgeInsets.all(isNarrowScreen ? 12 : 20),
              child: Row(
                children: [
                  Container(
                    width: isNarrowScreen ? 44 : 56,
                    height: isNarrowScreen ? 44 : 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(isNarrowScreen ? AppRadius.sm : AppRadius.md),
                    ),
                    child: Center(
                      child: QuizModeIcon(
                        isExamMode: quiz.type == 'exam',
                        size: isNarrowScreen ? 32 : 40,
                      ),
                    ),
                  ),

                  SizedBox(width: isNarrowScreen ? AppSpacing.md : AppSpacing.lg),

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
                              decoration: BoxDecoration(
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

                        if (!isNarrowScreen) const SizedBox(height: AppSpacing.xs),

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
                      ],
                    ),
                  ),

                  SizedBox(width: isNarrowScreen ? AppSpacing.sm : AppSpacing.md),

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
                            Icon(Icons.edit_outlined, size: AppIconSizes.lg),
                            SizedBox(width: AppSpacing.md),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: AppIconSizes.lg, color: AppColors.error),
                            const SizedBox(width: AppSpacing.md),
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