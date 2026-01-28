import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/code_block.dart';
import '../widgets/numbered_step.dart';
import '../widgets/prompt_card.dart';

class ImportHelpScreen extends StatelessWidget {
  const ImportHelpScreen({super.key});

  static const String _universalPrompt = '''
Convert my study notes into a quiz using JSON format.

## Settings [customize these]

Quiz type: practice
Max options per question: 4
Number of questions: 10-15

My rules [edit or delete these]:
- Make questions progressively harder
- Avoid trivial or obvious questions

## Requirements

- Include an explanation for each correct answer
- Mix single-choice and multiple-choice questions
- For multiple-choice: typically 20-75% of options should be correct (not all)
- Include plausible but incorrect distractors (wrong answers that seem reasonable)
- For code/technical content, use "code" and "language" fields
- Add alternative texts for variety on repeat attempts

## JSON format

{
  "title": "Quiz Title",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "Question text",
      "alternative_questions": ["Rephrased question", "Another phrasing"],
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "extra_options": ["Extra wrong option", "Another distractor"],
      "answer": ["2"],
      "option_variants": [[], ["Option B rephrased"], [], []],
      "explanation": "Why this is correct"
    }
  ]
}

Format notes:
- "type": use "practice" (immediate feedback) or "exam" (results at end)
- "max_options": limits options per question (2-8, default 4)
- "answer" is 1-based: ["1"] = first option, ["2"] = second
- Multiple correct: ["1", "3"] means options 1 and 3
- Code questions: add "code": "...", "language": "python"
- "alternative_questions": different phrasings of the same question
- "extra_options": additional wrong answers for shuffling variety
- "option_variants": text variants per option (option_variants[i] = variants for options[i])

## My notes [paste below]

[Paste your notes here]
''';

  static const String _jsonExample = r'''
{
  "title": "Go Fundamentals",
  "description": "Test your Go knowledge",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "Which keyword declares a constant in Go?",
      "options": ["var", "let", "const", "define"],
      "answer": ["3"],
      "explanation": "The 'const' keyword declares constants in Go."
    },
    {
      "question": "Which are valid ways to declare a variable?",
      "options": ["var x int", "x := 10", "int x = 10", "let x = 10"],
      "answer": ["1", "2"],
      "explanation": "Go supports 'var x int' and short declaration 'x := 10'."
    },
    {
      "question": "What does this code print?",
      "code": "func main() {\n  x := []int{1, 2, 3}\n  fmt.Println(len(x))\n}",
      "language": "go",
      "options": ["1", "2", "3", "error"],
      "answer": ["3"],
      "explanation": "len() returns the slice length, which is 3."
    }
  ]
}''';

  static const String _csvExample =
      'question,option1,option2,option3,option4,answer,explanation\n'
      '"Which keyword declares a constant?","var","let","const","define",3,"const declares constants"\n'
      '"Which are valid variable declarations?","var x int","x := 10","int x","let x","1,2","var and := are valid"';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Guide')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NumberedStep(
              number: '1',
              text: 'Prepare your notes',
              description:
                  'Gather the study material you want to turn into a quiz. '
                  'This can be notes, textbook excerpts, or any text content.',
            ),
            const SizedBox(height: 24),
            const NumberedStep(
              number: '2',
              text: 'Generate with AI',
              description:
                  'Copy the prompt below into ChatGPT or Claude. '
                  'Adjust the settings if needed, then paste your notes at the end.',
            ),
            const SizedBox(height: 12),
            const PromptCard(
              title: 'Quiz Generator Prompt',
              description: 'Generates JSON format (recommended)',
              prompt: _universalPrompt,
            ),
            const SizedBox(height: 24),
            const NumberedStep(
              number: '3',
              text: 'Import the quiz',
              description:
                  'Copy the JSON and paste it directly, or save as a file and upload. '
                  'CSV files are also supported.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showFullExamples(context),
                icon: const Icon(Icons.code, size: AppIconSizes.sm),
                label: const Text('View Format Examples'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showFullExamples(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Format Examples'),
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
                      const SingleChildScrollView(
                        child: CodeBlock(code: _jsonExample, language: 'json'),
                      ),
                      // CSV Tab
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Required columns:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.smAll,
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'question, option1, option2, ..., answer, explanation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supports 2-8 options (option1 through option8)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Example:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const CodeBlock(code: _csvExample, language: 'csv'),
                            const SizedBox(height: 12),
                            const Text(
                              'Note: Quiz title and type are set during import.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
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
}
