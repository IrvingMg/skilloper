import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/code_block.dart';
import '../widgets/numbered_step.dart';
import '../widgets/prompt_card.dart';

class ImportHelpScreen extends StatelessWidget {
  const ImportHelpScreen({super.key});

  static const String _universalPrompt = '''
Convert the following study notes into a quiz in JSON format.

Requirements:
- Generate 10-15 questions based on the key concepts
- Include an explanation for why each answer is correct
- Mix single-choice and multiple-choice questions where appropriate
- If my notes include code or technical content, include code snippets using "code" and "language" fields

Use this exact JSON format:
{
  "title": "Quiz Title Here",
  "type": "practice",
  "questions": [
    {
      "question": "Question text here",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "answer": ["2"],
      "explanation": "Explanation of why this answer is correct"
    }
  ]
}

Important:
- "answer" uses 1-based positions: ["1"] = first option, ["2"] = second option
- For multiple correct answers: ["1", "3"] means options 1 and 3 are both correct
- For code questions, add: "code": "your code here", "language": "javascript" (or python, etc.)

My study notes:
---
[PASTE YOUR NOTES HERE]
---''';

  static const String _jsonExample = r'''
{
  "title": "Go Fundamentals",
  "description": "Test your Go knowledge",
  "type": "practice",
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
            // Step 1: Prepare
            const NumberedStep(
              number: '1',
              text: 'Prepare your notes',
              description:
                  'Gather the study material you want to turn into a quiz. '
                  'This can be notes, textbook excerpts, or any text content.',
            ),
            const SizedBox(height: 24),

            // Step 2: Generate with AI
            const NumberedStep(
              number: '2',
              text: 'Generate with AI',
              description:
                  'Copy the prompt below and paste it into ChatGPT or Claude, '
                  'then add your notes at the end.',
            ),
            const SizedBox(height: 12),
            const PromptCard(
              title: 'Quiz Generator Prompt',
              description: 'Generates JSON format (recommended)',
              prompt: _universalPrompt,
            ),
            const SizedBox(height: 24),

            // Step 3: Import
            const NumberedStep(
              number: '3',
              text: 'Import the file',
              description:
                  'Save the AI output as a .json file, then import it. '
                  'You can also create CSV files manually.',
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
