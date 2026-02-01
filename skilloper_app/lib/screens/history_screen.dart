import 'dart:async';

import 'package:flutter/material.dart';
import '../models/attempt.dart';
import '../models/pagination.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/date_formatter.dart';
import '../utils/debouncer.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/history_screen_toolbar.dart';
import '../widgets/search_filter_bar.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();

  void refresh() {
    _loadHistory(refresh: true);
  }

  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  List<AttemptSummary> _attempts = [];
  PaginationMeta _pagination = PaginationMeta.initial();

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';
  String _sortBy = 'date_desc';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory(refresh: true);
  }

  @override
  void dispose() {
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

  Future<void> _loadHistory({bool refresh = false}) async {
    if (_isInitialLoading) return;

    setState(() {
      _isInitialLoading = true;
      _error = null;
      if (refresh) {
        _attempts = [];
        _pagination = PaginationMeta.initial();
      }
    });

    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;

    try {
      final result = await _apiService.getHistory(
        limit: 20,
        offset: 0,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      if (requestSearch != _searchQuery ||
          requestType != _typeFilter ||
          requestSort != _sortBy) {
        setState(() {
          _isInitialLoading = false;
        });
        unawaited(_loadHistory(refresh: true));
        return;
      }

      setState(() {
        _attempts = result.data;
        _pagination = result.pagination;
        _isInitialLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore || _isInitialLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestSort = _sortBy;
    final requestOffset = _pagination.nextOffset;

    try {
      final result = await _apiService.getHistory(
        limit: _pagination.limit,
        offset: requestOffset,
        search: _searchQuery,
        type: _typeFilter,
        sort: _sortBy,
      );

      if (!mounted) return;
      if (requestSearch != _searchQuery ||
          requestType != _typeFilter ||
          requestSort != _sortBy) {
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
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      showErrorSnackBar(context, 'Failed to load more: $e');
    }
  }

  void _onSearchChanged(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = query;
      });
      _loadHistory(refresh: true);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    _loadHistory(refresh: true);
  }

  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
    });
    _loadHistory(refresh: true);
  }

  void _viewAttemptDetails(AttemptSummary attempt) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => HistoryDetailScreen(attemptId: attempt.id),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _typeFilter.isNotEmpty;

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = '';
    });
    _loadHistory(refresh: true);
  }

  HistoryScreenToolbar _buildToolbar() {
    return HistoryScreenToolbar(
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      filterOptions: kQuizTypeFilterOptions,
      selectedFilter: _typeFilter,
      onFilterChanged: _onFilterChanged,
      sortOptions: kAttemptSortOptions,
      selectedSort: _sortBy,
      onSortChanged: _onSortChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              floating: true,
              delegate: HistoryScreenToolbarDelegate(toolbar: _buildToolbar()),
            ),

            if (_isInitialLoading && _attempts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.lg),
                      Text(
                        'Loading history...',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null && _attempts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
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
                        'Failed to load history',
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
                        onPressed: () => _loadHistory(refresh: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_attempts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasActiveFilters ? Icons.search_off : Icons.history,
                        size: 64,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _hasActiveFilters
                            ? 'No matches found'
                            : 'No quiz attempts yet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _hasActiveFilters
                            ? 'Try a different search or filter'
                            : 'Complete a quiz to see your results here',
                        style: const TextStyle(color: AppColors.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _attempts.length) {
                      return const Padding(
                        padding: AppSpacing.verticalLg,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final attempt = _attempts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _AttemptListItem(
                        attempt: attempt,
                        formattedDate: formatRelativeDateWithTime(
                          attempt.createdAt,
                        ),
                        onTap: () => _viewAttemptDetails(attempt),
                      ),
                    );
                  }, childCount: _attempts.length + (_isLoadingMore ? 1 : 0)),
                ),
              ),
          ],
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
    final isAbandoned = attempt.isAbandoned;
    final displayColor = isAbandoned
        ? AppColors.textDisabled
        : _getScoreColor(attempt.score);

    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: InkWell(
        onTap: isAbandoned ? null : onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: displayColor, width: 2),
                ),
                child: Center(
                  child: isAbandoned
                      ? Icon(
                          Icons.close,
                          color: displayColor,
                          size: AppIconSizes.xxl,
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            attempt.quizTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.xsAll,
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
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: Text(
                            attempt.quizType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: AppIconSizes.xs,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            '${attempt.correctCount}/${attempt.totalCount} correct',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Icon(
                          Icons.access_time,
                          size: AppIconSizes.xs,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (!isAbandoned)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: AppIconSizes.sm,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
