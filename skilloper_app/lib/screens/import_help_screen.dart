import 'package:flutter/material.dart';
import 'package:flutter_code_view/flutter_code_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

class ImportHelpScreen extends StatelessWidget {
  const ImportHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Guide')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Import Guide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Supported formats for importing quizzes',
              style: TextStyle(fontSize: 15, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),

            // Supported formats badges
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.data_object,
                    size: AppIconSizes.sm,
                    color: AppColors.primary,
                  ),
                  label: const Text('JSON'),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
                Chip(
                  avatar: const Icon(
                    Icons.table_chart,
                    size: AppIconSizes.sm,
                    color: AppColors.success,
                  ),
                  label: const Text('CSV'),
                  backgroundColor: AppColors.success.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // JSON Section
            const _SectionHeader(icon: Icons.data_object, title: 'JSON Format'),
            const SizedBox(height: 12),

            // JSON Quiz Fields Table
            _buildTable(
              title: 'Quiz Fields',
              headers: ['Field', 'Type', 'Description'],
              rows: [
                ['title', 'string ✓', 'Quiz name'],
                ['questions', 'array ✓', 'Array of question objects'],
                ['description', 'string', 'Quiz description'],
                ['type', 'string', '"practice" or "exam" (default: practice)'],
                ['max_options', 'int', '2-8 (default: 4)'],
              ],
            ),
            const SizedBox(height: 16),

            // JSON Question Fields Table
            _buildTable(
              title: 'Question Fields',
              headers: ['Field', 'Type', 'Description'],
              rows: [
                ['question', 'string ✓', 'The question text'],
                ['options', 'string[] ✓', '2-8 answer choices'],
                ['answer', 'string[] ✓', 'Correct option positions (1-based)'],
                ['explanation', 'string', 'Why the answer is correct'],
                ['code', 'string', 'Code snippet to display'],
                ['language', 'string', 'Syntax highlighting (js, python, etc)'],
              ],
            ),
            const SizedBox(height: 16),

            // Answer format explanation
            _buildRulesBox(
              title: 'Answer Format Rules',
              rules: [
                'Use 1-based position: "1" = first option, "2" = second, etc.',
                'Single choice: ["2"] means 2nd option is correct',
                'Multiple choice: ["1","3"] means 1st and 3rd are correct',
                'Values must be strings in an array, even for single answers',
              ],
            ),
            const SizedBox(height: 16),

            // JSON Example
            _buildCodeBlock(
              title: 'Example',
              code: '''
{
  "title": "My Quiz",
  "type": "practice",
  "questions": [
    {
      "question": "What is 2+2?",
      "options": ["1", "2", "3", "4"],
      "answer": ["4"],
      "explanation": "2+2 equals 4"
    },
    {
      "question": "Which are even numbers?",
      "options": ["1", "2", "3", "4"],
      "answer": ["2", "4"],
      "explanation": "2 and 4 are even"
    }
  ]
}
''',
            ),
            const SizedBox(height: 32),

            // CSV Section
            const _SectionHeader(icon: Icons.table_chart, title: 'CSV Format'),
            const SizedBox(height: 12),

            // CSV Columns Table
            _buildTable(
              title: 'Columns',
              headers: ['Column', 'Type', 'Description'],
              rows: [
                ['question', 'text ✓', 'The question text'],
                ['option1-8', 'text ✓', 'Answer options (min 2 required)'],
                ['answer', 'text ✓', 'Position(s): 4 or "1,2,4"'],
                ['explanation', 'text', 'Why the answer is correct'],
                ['code', 'text', 'Code snippet to display'],
                ['language', 'text', 'Syntax highlighting language'],
              ],
            ),
            const SizedBox(height: 16),

            // CSV answer rules
            _buildRulesBox(
              title: 'CSV Answer Format',
              rules: [
                'Single choice: just the number, e.g., 4',
                'Multiple choice: quoted comma-separated, e.g., "1,2,4"',
                'Uses 1-based positions (1 = first option)',
              ],
            ),
            const SizedBox(height: 16),

            // CSV Metadata
            _buildInfoBox(
              icon: Icons.edit_note,
              title: 'Quiz Metadata',
              content:
                  "You'll be prompted to enter title, type, and max options when importing",
            ),
            const SizedBox(height: 32),

            // Answer Format Section
            const _SectionHeader(
              icon: Icons.check_circle_outline,
              title: 'Answer Format',
            ),
            const SizedBox(height: 12),

            const Row(
              children: [
                Expanded(
                  child: _AnswerTypeCard(
                    type: 'Single Choice',
                    jsonExample: '["4"]',
                    csvExample: '4',
                    description: 'One correct answer',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _AnswerTypeCard(
                    type: 'Multiple Choice',
                    jsonExample: '["1","2","4"]',
                    csvExample: '"1,2,4"',
                    description: 'Multiple correct',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // View Examples Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFullExamples(context),
                icon: const Icon(Icons.code, size: AppIconSizes.md),
                label: const Text('View Full Examples'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Card(
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(0.8),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.outline),
                    ),
                  ),
                  children: headers
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...rows.map(
                  (row) => TableRow(
                    children: row
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: e.key == 0 ? 'monospace' : null,
                                fontWeight: e.key == 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: e.value == '✓'
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock({
    required String title,
    required String code,
    bool isCSV = false,
  }) {
    return Card(
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCSV ? Icons.table_chart : Icons.data_object,
                        size: AppIconSizes.xs,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.md),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FlutterCodeView(
                source: code,
                language: isCSV ? null : Languages.json,
                themeType: ThemeType.github,
                showLineNumbers: true,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesBox({required String title, required List<String> rules}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: AppIconSizes.md,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSizes.lg, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullExamples(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Examples'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 550),
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textTertiary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'JSON'),
                    Tab(text: 'CSV'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // JSON Tab
                      SingleChildScrollView(
                        child: ClipRRect(
                          borderRadius: AppRadius.smAll,
                          child: FlutterCodeView(
                            source: '''
{
  "title": "JavaScript Basics",
  "description": "Test your JS knowledge",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "What is typeof null?",
      "options": ["null", "undefined", "object", "boolean"],
      "answer": ["3"],
      "explanation": "Returns 'object' due to JS quirk",
      "code": "console.log(typeof null);",
      "language": "javascript"
    },
    {
      "question": "Which are even?",
      "options": ["1", "2", "3", "4"],
      "answer": ["2", "4"],
      "explanation": "2 and 4 are even numbers"
    }
  ]
}
''',
                            language: Languages.json,
                            themeType: ThemeType.github,
                            showLineNumbers: true,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // CSV Tab - show as visual table
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Visual table representation
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.smAll,
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CSV Structure',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCsvRow([
                                    'question',
                                    'option1',
                                    'option2',
                                    'option3',
                                    'option4',
                                    'answer',
                                    'expl.',
                                  ], isHeader: true),
                                  const Divider(height: 1),
                                  _buildCsvRow([
                                    'What is 2+2?',
                                    '1',
                                    '2',
                                    '3',
                                    '4',
                                    '4',
                                    'Math',
                                  ]),
                                  _buildCsvRow([
                                    'Which even?',
                                    '1',
                                    '2',
                                    '3',
                                    '4',
                                    '"2,4"',
                                    'Even #s',
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Raw CSV
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.codeBackground,
                                borderRadius: AppRadius.smAll,
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Raw CSV file:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  SelectableText(
                                    'question,option1,option2,option3,option4,answer,explanation\n'
                                    '"What is 2+2?","1","2","3","4",4,"Basic math"\n'
                                    '"Which are even?","1","2","3","4","2,4","2 and 4 are even"',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      height: 1.6,
                                      color: AppColors.codeText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildCsvRow(List<String> cells, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: cells.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return Expanded(
            flex: isFirst ? 3 : 2,
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: isFirst ? 11 : 10,
                fontFamily: 'monospace',
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                color: isHeader
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.xl, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AnswerTypeCard extends StatelessWidget {
  final String type;
  final String jsonExample;
  final String csvExample;
  final String description;

  const _AnswerTypeCard({
    required this.type,
    required this.jsonExample,
    required this.csvExample,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          _buildExample('JSON', jsonExample),
          const SizedBox(height: 4),
          _buildExample('CSV', csvExample),
        ],
      ),
    );
  }

  Widget _buildExample(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.codeBackground,
              borderRadius: AppRadius.xsAll,
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.codeText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
