import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'create_quiz/create_quiz_screen.dart';
import 'import_screen.dart';

class AddQuizScreen extends StatelessWidget {
  const AddQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Quiz',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Build from scratch or import from your study notes',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              // Options grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use row layout for wider screens, column for narrow
                    final isWide = constraints.maxWidth > 500;

                    if (isWide) {
                      return Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _OptionCard(
                                    icon: Icons.edit_note,
                                    title: 'Build',
                                    description:
                                        'Build questions one at a time with the wizard',
                                    color: AppColors.primary,
                                    onTap: () => _navigateToCreate(context),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _OptionCard(
                                    icon: Icons.upload_file,
                                    title: 'Import',
                                    description:
                                        'Paste JSON or upload a file from your notes',
                                    color: AppColors.info,
                                    onTap: () => _navigateToImport(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _TipBanner(),
                        ],
                      );
                    } else {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 180),
                              child: _OptionCard(
                                icon: Icons.edit_note,
                                title: 'Create',
                                description:
                                    'Build questions one at a time with the wizard',
                                color: AppColors.primary,
                                onTap: () => _navigateToCreate(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 180),
                              child: _OptionCard(
                                icon: Icons.upload_file,
                                title: 'Import',
                                description:
                                    'Paste JSON or upload a file from your notes',
                                color: AppColors.info,
                                onTap: () => _navigateToImport(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _TipBanner(),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const CreateQuizScreen()),
    );
  }

  void _navigateToImport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const ImportScreen()),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.lgAll,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Icon(Icons.arrow_forward, color: color, size: AppIconSizes.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: AppColors.primary,
            size: AppIconSizes.lg,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Tip: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Convert your study notes into quizzes using ChatGPT or Claude. Tap Import for instructions.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
