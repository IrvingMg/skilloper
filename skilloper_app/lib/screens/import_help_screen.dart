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
Number of questions: 10-20

## JSON Format

{
  "title": "Quiz Title",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "What protocol operates at the transport layer?",
      "alternative_questions": ["Which protocol works at OSI Layer 4?"],
      "question_type": "single_choice",
      "options": ["HTTP", "TCP", "IP", "Ethernet"],
      "option_variants": [[], ["Transmission Control Protocol"], [], []],
      "answer": ["2"],
      "explanation": "TCP operates at Layer 4 (transport)."
    },
    {
      "question": "Which are valid HTTP methods?",
      "alternative_questions": ["Which HTTP verbs are part of the standard?"],
      "question_type": "multiple_choice",
      "options": ["GET", "POST", "FETCH", "DELETE"],
      "option_variants": [["Retrieve data"], ["Submit data"], [], ["Remove resource"]],
      "answer": ["1", "2", "4"],
      "explanation": "GET, POST, DELETE are HTTP methods. FETCH is a browser API."
    }
  ]
}

### Required Fields
- question_type: "single_choice" or "multiple_choice"
- answer: 1-based indices (["2"] = second option, ["1","3"] = first and third)
- explanation: Say WHY the answer is correct, don't just restate it

### Variant Fields (required)
- alternative_questions: 1-2 rephrased versions per question
- option_variants: ALWAYS expand acronyms (TCP, UDP, HTTP, TLS, gRPC); word reorder OK; no interpretive descriptions
- extra_options: Additional wrong answers for shuffling

### Other Fields
- code + language: For code-based questions

## Information Integrity (Critical)

- Every fact must come directly from the notes — do NOT add "common knowledge"
- Use technical terms exactly as written — do NOT paraphrase
- NEVER reference "the notes" in questions OR explanations — write standalone content
- Base wrong options on logical inversions, not invented terms
- If unsure whether something is correct, skip it

## Question Quality

- Test ONE clear concept per question
- Keep all options similar in length and form
- Start with foundational concepts, progress to harder questions

## Multi-Choice Rules

- Vary the correct count: some with 2, some with 3, some with all correct
- Check EVERY option against the notes — include ALL correct answers
- If you can't find multiple correct answers, use single-choice instead

## Variant Rules (Required)

For EVERY question:
- alternative_questions: 1-2 rephrased versions
- option_variants: MUST expand acronyms (TCP, UDP, HTTP, TLS, gRPC, API)

Safe: "TCP" → "Transmission Control Protocol", "Host-based routing" → "Routing based on host"
NOT safe: "Kubelet" → "Node agent", "Scheduler" → "Pod placer" (interpretations)

## My Notes

[paste below]
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
      "alternative_questions": ["How do you declare a constant in Go?"],
      "question_type": "single_choice",
      "options": ["var", "let", "const", "define"],
      "option_variants": [["variable"], [], ["constant"], []],
      "answer": ["3"],
      "explanation": "The 'const' keyword declares constants in Go."
    },
    {
      "question": "Which are valid ways to declare a variable?",
      "alternative_questions": ["What are valid variable declaration syntaxes in Go?"],
      "question_type": "multiple_choice",
      "options": ["var x int", "x := 10", "int x = 10", "let x = 10"],
      "answer": ["1", "2"],
      "explanation": "Go supports 'var x int' and short declaration 'x := 10'."
    },
    {
      "question": "What does this code print?",
      "question_type": "single_choice",
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
      appBar: AppBar(
        title: const Text('Import Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (_) => false),
            tooltip: 'Home',
          ),
        ],
      ),
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
