import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../models/questionnaire.dart';
import 'import_help_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isUploading = true;
          _message = null;
        });

        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        final importResponse = await _apiService.importQuestionnaire(fileBytes, fileName);

        setState(() {
          _isUploading = false;
          _isSuccess = importResponse != null;
          _message = null; // Remove the simple message
        });

        // Show success dialog and snackbar if import was successful
        if (importResponse != null && mounted) {
          _showSuccessDialog(importResponse);
          _showSnackBar('Questionnaire imported successfully!', true);
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isSuccess = false;
        _message = null;
      });

      if (mounted) {
        _handleError(e.toString());
      }
    }
  }

  void _handleError(String errorMessage) {
    final errorInfo = _processErrorMessage(errorMessage);

    if (errorInfo['shouldShowDialog']) {
      _showErrorDialog(errorInfo['message']!, errorInfo['type']!);
    } else {
      _showSnackBar(errorInfo['message']!, false);
    }
  }

  Map<String, dynamic> _processErrorMessage(String errorMessage) {
    // Clean up the error message
    String cleanError = errorMessage;
    if (cleanError.startsWith('Exception: Failed to upload file: Exception: ')) {
      cleanError = cleanError.substring('Exception: Failed to upload file: Exception: '.length);
    } else if (cleanError.startsWith('Exception: ')) {
      cleanError = cleanError.substring('Exception: '.length);
    } else if (cleanError.startsWith('ApiException: ')) {
      cleanError = cleanError.substring('ApiException: '.length);
    }

    // Determine error type and whether to show dialog
    String errorType = 'generic';
    bool shouldShowDialog = false;

    if (cleanError.toLowerCase().contains('json') ||
        cleanError.toLowerCase().contains('invalid json format')) {
      errorType = 'json';
      shouldShowDialog = true;
    } else if (cleanError.toLowerCase().contains('validation') ||
               cleanError.toLowerCase().contains('required') ||
               cleanError.toLowerCase().contains('invalid file format') ||
               cleanError.toLowerCase().contains('file validation failed')) {
      errorType = 'validation';
      shouldShowDialog = true;
    } else if (cleanError.toLowerCase().contains('file') &&
               (cleanError.toLowerCase().contains('large') ||
                cleanError.toLowerCase().contains('too large'))) {
      errorType = 'file_size';
      shouldShowDialog = true;
    } else if (cleanError.toLowerCase().contains('server') ||
               cleanError.toLowerCase().contains('500') ||
               cleanError.toLowerCase().contains('server error')) {
      errorType = 'server';
      shouldShowDialog = false;
    } else if (cleanError.toLowerCase().contains('network') ||
               cleanError.toLowerCase().contains('connection') ||
               cleanError.toLowerCase().contains('connect to api')) {
      errorType = 'network';
      shouldShowDialog = false;
    } else if (cleanError.length > 80) {
      shouldShowDialog = true;
    } else {
      // For shorter error messages, show dialog if they seem important
      shouldShowDialog = cleanError.length > 20;
    }

    return {
      'message': cleanError,
      'type': errorType,
      'shouldShowDialog': shouldShowDialog,
    };
  }

  Map<String, dynamic> _getErrorDetails(String errorMessage, String errorType) {
    String title = 'Import Failed';
    String subtitle = 'Unable to process your questionnaire file';
    String quickTip = 'Check the file format and try again';

    // Customize based on error type
    switch (errorType) {
      case 'json':
        title = 'Invalid JSON Format';
        subtitle = 'Your file contains JSON syntax errors';
        quickTip = 'Validate your JSON syntax and ensure proper formatting';
        break;
      case 'validation':
        title = 'Validation Error';
        subtitle = 'Your questionnaire is missing required information';
        quickTip = 'Check that all required fields are present and correctly formatted';
        break;
      case 'file_size':
        title = 'File Too Large';
        subtitle = 'The uploaded file exceeds the 10MB size limit';
        quickTip = 'Reduce your file size by removing unnecessary content';
        break;
      default:
        title = 'Import Failed';
        subtitle = 'Unable to process your questionnaire file';
        quickTip = 'Review the file format requirements and try again';
    }

    return {
      'title': title,
      'subtitle': subtitle,
      'quickTip': quickTip,
    };
  }

  void _showErrorDialog(String errorMessage, String errorType) {
    final errorDetails = _getErrorDetails(errorMessage, errorType);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorDetails['title']!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorDetails['subtitle']!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Error message in a clean container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: AppColors.onErrorContainer,
                    height: 1.4,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Try Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ImportHelpScreen(),
                  ),
                );
              },
              child: const Text('View Help'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(ImportResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Import Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully imported questionnaire:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.questionnaire.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (response.questionnaire.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        response.questionnaire.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.quiz,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${response.questionnaire.questionCount} questions',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          response.questionnaire.isPracticeMode
                              ? Icons.school
                              : Icons.assignment,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          response.questionnaire.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Import Another'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              child: const Text('View Questionnaires'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Questionnaires',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload JSON files to add new questionnaires',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ImportHelpScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.help_outline,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  tooltip: 'Import Help & JSON Schema',
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Upload area
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(MediaQuery.of(context).size.height < 700 ? 24 : 48),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: MediaQuery.of(context).size.height < 700 ? 48 : 64,
                            color: _isUploading
                                ? Theme.of(context).primaryColor
                                : const Color(0xFF9CA3AF),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height < 700 ? 12 : 16),

                          if (_isUploading)
                            const Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Uploading...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                const Text(
                                  'Upload questionnaire file',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Supports JSON format',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: MediaQuery.of(context).size.height < 700 ? 16 : 24),
                                ElevatedButton.icon(
                                  onPressed: _pickAndUploadFile,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Choose File'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 16 : 24),

                    // Message area
                    if (_message != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          border: Border.all(
                            color: _isSuccess
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFECACA),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error,
                              color: _isSuccess
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _message!,
                                style: TextStyle(
                                  color: _isSuccess
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF991B1B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 20 : 32),

                    // Requirements Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rtl,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'File Requirements',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _RequirementItem(
                            icon: Icons.description_outlined,
                            text: 'JSON files should follow the questionnaire schema',
                          ),
                          const SizedBox(height: 12),
                          _RequirementItem(
                            icon: Icons.file_present_outlined,
                            text: 'Maximum file size: 10MB',
                          ),
                          const SizedBox(height: 12),
                          _RequirementItem(
                            icon: Icons.flash_on_outlined,
                            text: 'Files will be processed immediately',
                          ),
                        ],
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
}

class _RequirementItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RequirementItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
