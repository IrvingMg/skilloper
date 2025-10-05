import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

class ImportHelpScreen extends StatelessWidget {
  const ImportHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.psychology,
                color: Colors.white,
                size: AppIconSizes.large,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Skilloper'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Guide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn how to import questionnaire JSON files',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Quick tips
                    _buildSimpleSection(
                      'Quick Tips',
                      [
                        'Files must be in JSON format with .json extension',
                        'Maximum file size is 10MB',
                        'Use double quotes for all strings in JSON',
                        'Answer indices are 0-based (0 = first option)',
                        'Test your JSON file with an online validator first',
                      ],
                      AppColors.primary,
                    ),

                    const SizedBox(height: 16),

                    // JSON structure
                    _buildCodeSection(
                      'Required Structure',
                      '''{
  "title": "Your Quiz Title",
  "description": "Quiz description (optional)",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question_type": "single_choice",
      "question": "Your question text",
      "options": ["Option A", "Option B", "Option C"],
      "correctAnswer": 1,
      "explanation": "Why this answer is correct (optional)"
    }
  ]
}''',
                    ),

                    const SizedBox(height: 16),

                    // Question types
                    _buildSimpleSection(
                      'Question Types',
                      [
                        'single_choice: One correct answer (use "correctAnswer": number)',
                        'multiple_choice: Multiple correct answers (use "correct_answers": [0, 2])',
                      ],
                      AppColors.primary,
                    ),

                    const SizedBox(height: 24),

                    // Single comprehensive example button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showCompleteExample(context),
                        icon: const Icon(Icons.code),
                        label: const Text('View Complete Example'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Bottom padding for small screens
                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 20 : 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSection(String title, List<String> points, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            ...points.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSection(String title, String code) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.codeBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.codeBorder),
              ),
              child: _buildSyntaxHighlightedText(code),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyntaxHighlightedText(String code) {
    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          height: 1.4,
          color: AppColors.codeText,
        ),
        children: _parseJsonSyntax(code),
      ),
    );
  }

  List<TextSpan> _parseJsonSyntax(String text) {
    final List<TextSpan> spans = [];
    final RegExp jsonRegex = RegExp(r'"[^"]*":|"[^"]*"|\b(?:true|false|null)\b|\b\d+(?:\.\d+)?\b|[{}\[\],:}]');
    int lastEnd = 0;

    for (final match in jsonRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: AppColors.codeText),
        ));
      }

      final matchText = match.group(0)!;
      Color color = AppColors.codeText;

      if (matchText.startsWith('"') && matchText.endsWith(':')) {
        color = AppColors.codeKeyword; // Property names
      } else if (matchText.startsWith('"') && matchText.endsWith('"')) {
        color = AppColors.codeString; // String values
      } else if (matchText == 'true' || matchText == 'false' || matchText == 'null') {
        color = AppColors.warning; // Boolean/null
      } else if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(matchText)) {
        color = AppColors.achievement; // Numbers
      } else if (RegExp(r'^[{}\[\],:}]$').hasMatch(matchText)) {
        color = AppColors.codeComment; // Brackets and punctuation
      }

      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: AppColors.codeText),
      ));
    }

    return spans;
  }


  void _showCompleteExample(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Example'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.codeBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.codeBorder),
              ),
              child: _buildSyntaxHighlightedText(
                '''{
  "title": "JavaScript Fundamentals",
  "description": "Test your JavaScript knowledge",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question_type": "single_choice",
      "question": "What is the output of typeof null?",
      "code": "console.log(typeof null);",
      "language": "javascript",
      "options": ["null", "undefined", "object", "boolean"],
      "correctAnswer": 2,
      "explanation": "typeof null returns 'object' due to a JavaScript quirk"
    },
    {
      "question_type": "multiple_choice",
      "question": "Which are valid JavaScript data types?",
      "options": ["string", "number", "boolean", "undefined", "symbol"],
      "correct_answers": [0, 1, 2, 3, 4],
      "explanation": "All listed options are valid JavaScript data types"
    },
    {
      "question_type": "single_choice",
      "question": "Which method adds an element to the end of an array?",
      "options": ["push()", "pop()", "shift()", "unshift()"],
      "correctAnswer": 0,
      "explanation": "push() adds elements to the end of an array"
    }
  ]
}''',
              ),
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
}