import 'package:flutter/material.dart';
import '../models/questionnaire.dart';
import '../models/pagination.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/debouncer.dart';
import '../widgets/search_filter_bar.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));

  // Data state
  List<QuestionnaireSummary> _questionnaires = [];
  PaginationMeta _pagination = PaginationMeta.initial();

  // Loading states
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadQuestionnaires(refresh: true);
  }

  @override
  void dispose() {
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

  /// Load questionnaires (initial or refresh)
  Future<void> _loadQuestionnaires({bool refresh = false}) async {
    if (_isInitialLoading) return;

    setState(() {
      _isInitialLoading = true;
      _error = null;
      if (refresh) {
        _questionnaires = [];
        _pagination = PaginationMeta.initial();
      }
    });

    // Capture current search/filter state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;

    try {
      final result = await _apiService.getQuestionnaireSummaries(
        limit: 20,
        offset: 0,
        search: _searchQuery,
        type: _typeFilter,
      );

      if (!mounted) return;
      // Check if search/filter changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter) {
        // Query changed - clear loading flag and retry with current query
        setState(() {
          _isInitialLoading = false;
        });
        _loadQuestionnaires(refresh: true);
        return;
      }

      setState(() {
        _questionnaires = result.data;
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

  /// Load more questionnaires (infinite scroll)
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore || _isInitialLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Capture current state for race condition detection
    final requestSearch = _searchQuery;
    final requestType = _typeFilter;
    final requestOffset = _pagination.nextOffset;

    try {
      final result = await _apiService.getQuestionnaireSummaries(
        limit: _pagination.limit,
        offset: requestOffset,
        search: _searchQuery,
        type: _typeFilter,
      );

      if (!mounted) return;
      // Check if search/filter changed while request was in flight
      if (requestSearch != _searchQuery || requestType != _typeFilter) {
        // Query changed - discard stale results; a fresh load should already be in progress
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _questionnaires.addAll(result.data);
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
      _loadQuestionnaires(refresh: true);
    });
  }

  /// Handle filter change (immediate, no debounce)
  void _onFilterChanged(String filter) {
    setState(() {
      _typeFilter = filter;
    });
    _loadQuestionnaires(refresh: true);
  }

  Future<void> _startQuiz(QuestionnaireSummary summary) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch full questionnaire with questions (fresh shuffled data)
      final questionnaire = await _apiService.getQuestionnaire(summary.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(questionnaire: questionnaire),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questionnaire: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadQuestionnaires(refresh: true),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Questionnaires',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a questionnaire to test your skills',
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
              ),

              const SizedBox(height: 16),

              if (_isInitialLoading && _questionnaires.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading questionnaires...',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null && _questionnaires.isEmpty)
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
                          'Failed to load questionnaires',
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
                          onPressed: () => _loadQuestionnaires(refresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_questionnaires.isEmpty)
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
                              : 'No questionnaires available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _typeFilter.isNotEmpty
                              ? 'Try a different search or filter'
                              : 'Upload some questionnaires using the Import tab',
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
                              _loadQuestionnaires(refresh: true);
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
                    itemCount: _questionnaires.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the bottom
                      if (index == _questionnaires.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final questionnaire = _questionnaires[index];
                      return _QuestionnaireListItem(
                        questionnaire: questionnaire,
                        onTap: () => _startQuiz(questionnaire),
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

class _QuestionnaireListItem extends StatelessWidget {
  final QuestionnaireSummary questionnaire;
  final VoidCallback onTap;

  const _QuestionnaireListItem({
    required this.questionnaire,
    required this.onTap,
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
                      color: questionnaire.type == 'exam'
                          ? AppColors.examModeContainer
                          : AppColors.practiceModeContainer,
                      borderRadius: BorderRadius.circular(isNarrowScreen ? 10 : 12),
                    ),
                    child: Icon(
                      questionnaire.type == 'exam' ? AppIcons.examMode : AppIcons.practiceMode,
                      color: questionnaire.type == 'exam'
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
                                questionnaire.title,
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
                                color: questionnaire.type == 'exam'
                                    ? AppColors.examModeContainer
                                    : AppColors.practiceModeContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                questionnaire.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: questionnaire.type == 'exam'
                                      ? AppColors.onExamModeContainer
                                      : AppColors.onPracticeModeContainer,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (!isNarrowScreen) const SizedBox(height: 6),

                        // Description - only show on wider screens
                        if (!isNarrowScreen && questionnaire.description.isNotEmpty) ...[
                          Text(
                            questionnaire.description,
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
                          // Vertical layout for narrow screens
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.quiz_outlined,
                                    size: 14,
                                    color: AppColors.textDisabled,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${questionnaire.questionCount} questions',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              // Max options info removed per user request
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
                                '${questionnaire.questionCount} questions',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Max options info removed per user request
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: isNarrowScreen ? 8 : 16),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isNarrowScreen ? 14 : 16,
                    color: const Color(0xFF9CA3AF),
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