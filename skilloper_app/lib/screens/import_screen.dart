import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/numbered_step.dart';
import 'import_help_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  // Constants for error processing
  static const int _maxErrorDisplayLength = 2000;
  static const int _shortErrorThreshold = 20;
  static const int _longErrorThreshold = 80;
  static const List<String> _allowedExtensions = ['json', 'csv'];

  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;

        // Secondary validation - FilePicker allowedExtensions not guaranteed on all platforms
        final extension = fileName.contains('.')
            ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
            : '';
        if (!_allowedExtensions.contains(extension)) {
          _handleError(
            'Unsupported file type. Please select a JSON or CSV file.',
          );
          return;
        }

        // Check if CSV file - show metadata dialog
        if (fileName.toLowerCase().endsWith('.csv')) {
          final metadata = await _showCsvMetadataDialog(fileName);
          if (metadata == null) return; // User cancelled

          await _uploadFile(fileBytes, fileName, metadata: metadata);
        } else {
          // JSON file - upload directly
          await _uploadFile(fileBytes, fileName);
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = false;
          _message = null;
        });
        _handleError(e.toString());
      }
    }
  }

  Future<Map<String, dynamic>?> _showCsvMetadataDialog(String fileName) async {
    // Remove extension case-insensitively
    final baseName = fileName.replaceFirst(
      RegExp(r'\.csv$', caseSensitive: false),
      '',
    );
    final titleController = TextEditingController(text: baseName);
    final descriptionController = TextEditingController();
    String selectedType = 'practice';
    int maxOptions = 4;
    String? errorMessage;

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
            title: const Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: AppColors.primary,
                  size: AppIconSizes.xxxl,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CSV Quiz Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter quiz metadata for your CSV file',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: AppIconSizes.md,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: AppIconSizes.md,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                setDialogState(() => errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Title field
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Quiz Title *',
                      hintText: 'Enter quiz title',
                      border: OutlineInputBorder(borderRadius: AppRadius.smAll),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Brief description of the quiz',
                      border: OutlineInputBorder(borderRadius: AppRadius.smAll),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Type selector
                  const Text(
                    'Quiz Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'practice',
                        label: Text('Practice'),
                        icon: Icon(Icons.school, size: AppIconSizes.md),
                      ),
                      ButtonSegment(
                        value: 'exam',
                        label: Text('Exam'),
                        icon: Icon(Icons.assignment, size: AppIconSizes.md),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (value) {
                      setDialogState(() => selectedType = value.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Max options
                  Text(
                    'Max Options per Question: $maxOptions',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Slider(
                    value: maxOptions.toDouble(),
                    min: 2,
                    max: 8,
                    divisions: 6,
                    label: maxOptions.toString(),
                    onChanged: (value) {
                      setDialogState(() => maxOptions = value.round());
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    setDialogState(() => errorMessage = 'Title is required');
                    return;
                  }
                  Navigator.pop(context, {
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'type': selectedType,
                    'maxOptions': maxOptions,
                  });
                },
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _uploadFile(
    List<int> fileBytes,
    String fileName, {
    Map<String, dynamic>? metadata,
  }) async {
    setState(() {
      _isUploading = true;
      _message = null;
    });

    try {
      final importResponse = await _apiService.importQuiz(
        fileBytes,
        fileName,
        title: metadata?['title'] as String?,
        description: metadata?['description'] as String?,
        type: metadata?['type'] as String?,
        maxOptions: metadata?['maxOptions'] as int?,
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _isSuccess = importResponse != null;
        _message = null;
      });

      if (importResponse != null) {
        _showSuccessDialog(importResponse);
        _showSnackBar('Quiz imported successfully!', true);
      }
    } on Object catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _isSuccess = false;
        _message = null;
      });

      _handleError(e.toString());
    }
  }

  void _handleError(String errorMessage) {
    final errorInfo = _processErrorMessage(errorMessage);

    if (errorInfo['shouldShowDialog'] as bool) {
      _showErrorDialog(
        errorInfo['message'] as String,
        errorInfo['type'] as String,
      );
    } else {
      _showSnackBar(errorInfo['message'] as String, false);
    }
  }

  Map<String, dynamic> _processErrorMessage(String errorMessage) {
    // Clean up the error message
    String cleanError = errorMessage;
    if (cleanError.startsWith(
      'Exception: Failed to upload file: Exception: ',
    )) {
      cleanError = cleanError.substring(
        'Exception: Failed to upload file: Exception: '.length,
      );
    } else if (cleanError.startsWith('Exception: ')) {
      cleanError = cleanError.substring('Exception: '.length);
    } else if (cleanError.startsWith('ApiException: ')) {
      cleanError = cleanError.substring('ApiException: '.length);
    }

    // Limit error message length to prevent performance issues with very long errors
    if (cleanError.length > _maxErrorDisplayLength) {
      cleanError =
          '${cleanError.substring(0, _maxErrorDisplayLength)}... (truncated)';
    }

    // Use lowercase version for comparisons (single allocation)
    final lowerError = cleanError.toLowerCase();

    // Determine error type and whether to show dialog
    String errorType = 'generic';
    bool shouldShowDialog = false;

    if (lowerError.contains('json') ||
        lowerError.contains('invalid json format')) {
      errorType = 'json';
      shouldShowDialog = true;
    } else if (lowerError.contains('validation') ||
        lowerError.contains('required') ||
        lowerError.contains('invalid file format') ||
        lowerError.contains('file validation failed')) {
      errorType = 'validation';
      shouldShowDialog = true;
    } else if (lowerError.contains('file') &&
        (lowerError.contains('large') || lowerError.contains('too large'))) {
      errorType = 'file_size';
      shouldShowDialog = true;
    } else if (lowerError.contains('server') ||
        lowerError.contains('500') ||
        lowerError.contains('server error')) {
      errorType = 'server';
      shouldShowDialog = false;
    } else if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('connect to api')) {
      errorType = 'network';
      shouldShowDialog = false;
    } else if (cleanError.length > _longErrorThreshold) {
      shouldShowDialog = true;
    } else {
      // For shorter error messages, show dialog if they seem important
      shouldShowDialog = cleanError.length > _shortErrorThreshold;
    }

    return {
      'message': cleanError,
      'type': errorType,
      'shouldShowDialog': shouldShowDialog,
    };
  }

  Map<String, String> _getErrorDetails(String errorType) {
    switch (errorType) {
      case 'json':
        return {
          'title': 'Invalid JSON Format',
          'subtitle': 'Your file contains JSON syntax errors',
        };
      case 'validation':
        return {
          'title': 'Validation Error',
          'subtitle': 'Your quiz is missing required information',
        };
      case 'file_size':
        return {
          'title': 'File Too Large',
          'subtitle': 'The uploaded file exceeds the 10MB size limit',
        };
      default:
        return {
          'title': 'Import Failed',
          'subtitle': 'Unable to process your quiz file',
        };
    }
  }

  void _showErrorDialog(String errorMessage, String errorType) {
    final errorDetails = _getErrorDetails(errorType);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppIconSizes.xxxl,
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
                style: const TextStyle(
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
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  errorMessage,
                  style: const TextStyle(
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
                  MaterialPageRoute<void>(
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: AppIconSizes.xxxl,
              ),
              SizedBox(width: 12),
              Text(
                'Import Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Successfully imported quiz:',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.quiz.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (response.quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        response.quiz.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.quiz,
                          size: AppIconSizes.sm,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${response.quiz.questionCount} questions',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        QuizModeIcon(
                          isExamMode: !response.quiz.isPracticeMode,
                          size: AppIconSizes.sm,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          response.quiz.type.toUpperCase(),
                          style: const TextStyle(
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
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('View Quizzes'),
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
              color: AppColors.textOnPrimary,
              size: AppIconSizes.lg,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ImportHelpScreen(),
                ),
              );
            },
            icon: const Icon(Icons.help_outline, color: AppColors.primary),
            tooltip: 'Import Help & Format Guide',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload a quiz file created from your study notes',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Guidance Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: AppColors.primary,
                                size: AppIconSizes.lg,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No quiz file yet?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Convert your notes with AI:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const NumberedStep.compact(
                            number: '1',
                            text: 'Copy your study notes',
                          ),
                          const NumberedStep.compact(
                            number: '2',
                            text: 'Paste into ChatGPT with our prompt',
                          ),
                          const NumberedStep.compact(
                            number: '3',
                            text: 'Download and import the file',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        const ImportHelpScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.auto_awesome,
                                size: AppIconSizes.sm,
                                color: AppColors.primary,
                              ),
                              label: const Text('Get AI Prompt'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Upload area
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.height < 700 ? 24 : 48,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.outline,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: AppRadius.lgAll,
                        color: AppColors.surfaceWhite,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: MediaQuery.of(context).size.height < 700
                                ? 48
                                : 64,
                            color: _isUploading
                                ? AppColors.primary
                                : AppColors.textDisabled,
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height < 700
                                ? 12
                                : 16,
                          ),

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
                                  'Upload quiz file',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Supports JSON and CSV formats',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height < 700
                                      ? 16
                                      : 24,
                                ),
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

                    SizedBox(
                      height: MediaQuery.of(context).size.height < 700
                          ? 16
                          : 24,
                    ),

                    // Message area
                    if (_message != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? AppColors.successContainer
                              : AppColors.errorContainer,
                          border: Border.all(
                            color: _isSuccess
                                ? AppColors.success.withValues(alpha: 0.5)
                                : AppColors.error.withValues(alpha: 0.5),
                          ),
                          borderRadius: AppRadius.smAll,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error,
                              color: _isSuccess
                                  ? AppColors.onSuccessContainer
                                  : AppColors.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _message!,
                                style: TextStyle(
                                  color: _isSuccess
                                      ? AppColors.onSuccessContainer
                                      : AppColors.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Bottom padding
                    SizedBox(
                      height: MediaQuery.of(context).size.height < 700 ? 20 : 16,
                    ),
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
