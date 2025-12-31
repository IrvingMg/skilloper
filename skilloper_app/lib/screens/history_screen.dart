import 'package:flutter/material.dart';
import '../models/attempt.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
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
  List<AttemptSummary> _attempts = [];
  bool _isLoading = false;
  String? _error;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AttemptSummary> get _filteredAttempts {
    final normalizedQuery = _searchQuery.toLowerCase();
    return _attempts.where((a) => matchesFilter(
      title: a.questionnaireTitle,
      type: a.questionnaireType,
      searchQuery: normalizedQuery,
      typeFilter: _typeFilter,
    )).toList();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceId = await _deviceService.getDeviceId();
      final attempts = await _apiService.getHistory(deviceId);
      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        onRefresh: _loadHistory,
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
                onSearchChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                },
                filterOptions: kQuizTypeFilterOptions,
                selectedFilter: _typeFilter,
                onFilterChanged: (filter) {
                  setState(() {
                    _typeFilter = filter;
                  });
                },
              ),

              const SizedBox(height: 16),

              if (_isLoading)
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
              else if (_error != null)
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
                          onPressed: _loadHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_attempts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No quiz attempts yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Complete a quiz to see your results here',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredAttempts.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No matches found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try a different search or filter',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _typeFilter = '';
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _filteredAttempts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final attempt = _filteredAttempts[index];
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
