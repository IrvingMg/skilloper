import 'package:flutter/material.dart';
import '../models/questionnaire.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/search_filter_bar.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<QuestionnaireSummary> _questionnaires = [];
  bool _isLoading = false;
  String? _error;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadQuestionnaires();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuestionnaireSummary> get _filteredQuestionnaires {
    final normalizedQuery = _searchQuery.toLowerCase();
    return _questionnaires.where((q) => matchesFilter(
      title: q.title,
      type: q.type,
      searchQuery: normalizedQuery,
      typeFilter: _typeFilter,
    )).toList();
  }

  Future<void> _loadQuestionnaires() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final questionnaires = await _apiService.getQuestionnaireSummaries();
      setState(() {
        _questionnaires = questionnaires;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        onRefresh: _loadQuestionnaires,
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
                          'Loading questionnaires...',
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
                        Text(
                          'Failed to load questionnaires',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure the API is running on localhost:8080',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadQuestionnaires,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_questionnaires.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No questionnaires available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload some questionnaires using the Import tab',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredQuestionnaires.isEmpty)
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
                    itemCount: _filteredQuestionnaires.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final questionnaire = _filteredQuestionnaires[index];
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