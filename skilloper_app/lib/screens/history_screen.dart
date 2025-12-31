import 'package:flutter/material.dart';
import '../models/attempt.dart';
import '../models/pagination.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/debouncer.dart';
import '../widgets/search_filter_bar.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));

  // Data state
  List<AttemptSummary> _attempts = [];
  PaginationMeta _pagination = PaginationMeta.initial();
  String? _deviceId;

  // Loading states
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
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
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    _deviceId = await _deviceService.getDeviceId();
    if (!mounted) return;
    _loadHistory(refresh: true);
  }

  /// Handle scroll to trigger load more
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Load history (initial or refresh)
  Future<void> _loadHistory({bool refresh = false}) async {
    if (_isInitialLoading || _deviceId == null) return;

    setState(() {
      _isInitialLoading = true;
      _error = null;
      if (refresh) {
        _attempts = [];
        _pagination = PaginationMeta.initial();
      }
    });

    // Capture current search/filter/sort state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;

    try {
      final result = await _apiService.getHistory(
        _deviceId!,
        limit: 20,
        offset: 0,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      // Check if search/filter/sort changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter || requestSort != _sortBy) {
        // Query changed - clear loading flag and retry with current query
        setState(() {
          _isInitialLoading = false;
        });
        _loadHistory(refresh: true);
        return;
      }

      setState(() {
        _attempts = result.data;
        _pagination = result.pagination;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  /// Load more history (infinite scroll)
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore || _isInitialLoading || _deviceId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Capture current state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;
    final requestOffset = _pagination.nextOffset;

    try {
      final result = await _apiService.getHistory(
        _deviceId!,
        limit: _pagination.limit,
        offset: requestOffset,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      // Check if search/filter/sort changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter || requestSort != _sortBy) {
        // Query changed - discard stale results; a fresh load should already be in progress
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _attempts.addAll(result.data);
        _pagination = result.pagination;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more: $e')),
      );
    }
  }

  /// Handle search text change with debounce
  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
      });
      _loadHistory(refresh: true);
    });
  }

  /// Handle filter change (immediate, no debounce)
  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    _loadHistory(refresh: true);
  }

  /// Handle sort change (immediate, no debounce)
  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
    });
    _loadHistory(refresh: true);
  }

  void _viewAttemptDetails(AttemptSummary attempt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDetailScreen(attemptId: attempt.id),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final attemptDate = DateTime(date.year, date.month, date.day);

    if (attemptDate == today) {
      return 'Today at ${_formatTime(date)}';
    } else if (attemptDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quiz History',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review your past quiz attempts',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),

              // Search and filter bar
              SearchFilterBar(
                searchHint: 'Search history...',
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                filterOptions: kQuizTypeFilterOptions,
                selectedFilter: _typeFilter,
                onFilterChanged: _onFilterChanged,
                sortOptions: kAttemptSortOptions,
                selectedSort: _sortBy,
                onSortChanged: _onSortChanged,
              ),

              const SizedBox(height: 16),

              if (_isInitialLoading && _attempts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading history...',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null && _attempts.isEmpty)
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
                          'Failed to load history',
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
                          onPressed: () => _loadHistory(refresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_attempts.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? Icons.search_off
                              : Icons.history,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'No matches found'
                              : 'No quiz attempts yet',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'Try a different search or filter'
                              : 'Complete a quiz to see your results here',
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
                              _loadHistory(refresh: true);
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
                    itemCount: _attempts.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the bottom
                      if (index == _attempts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final attempt = _attempts[index];
                      return _AttemptListItem(
                        attempt: attempt,
                        formattedDate: _formatDate(attempt.createdAt),
                        onTap: () => _viewAttemptDetails(attempt),
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

class _AttemptListItem extends StatelessWidget {
  final AttemptSummary attempt;
  final String formattedDate;
  final VoidCallback onTap;

  const _AttemptListItem({
    required this.attempt,
    required this.formattedDate,
    required this.onTap,
  });

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.achievement;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isAbandoned = attempt.isInProgress;
    final displayColor = isAbandoned ? AppColors.textDisabled : _getScoreColor(attempt.score);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isAbandoned ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Score circle or abandoned indicator
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: displayColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isAbandoned
                      ? Icon(
                          Icons.close,
                          color: displayColor,
                          size: 24,
                        )
                      : Text(
                          '${attempt.score}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title, attempt number badge, and type badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            attempt.questionnaireTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${attempt.attemptNumber}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: attempt.questionnaireType == 'exam'
                                ? AppColors.examModeContainer
                                : AppColors.practiceModeContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            attempt.questionnaireType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: attempt.questionnaireType == 'exam'
                                  ? AppColors.onExamModeContainer
                                  : AppColors.onPracticeModeContainer,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        Icon(
                          attempt.isPracticeMode
                              ? AppIcons.practiceMode
                              : AppIcons.examMode,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${attempt.correctCount}/${attempt.totalCount} correct',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow (only for completed attempts)
              if (!isAbandoned)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
