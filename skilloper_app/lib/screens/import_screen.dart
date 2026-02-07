import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/snackbar_helper.dart';
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
  static const List<String> _allowedExtensions = ['json'];

  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  String? _message;
  bool _isSuccess = false;

  // Paste JSON mode state
  bool _isPasteMode = true;
  final TextEditingController _jsonController = TextEditingController();
  String? _jsonError;
  bool _isJsonValid = false;

  @override
  void initState() {
    super.initState();
    _jsonController.addListener(_onJsonTextChanged);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_onJsonTextChanged);
    _jsonController.dispose();
    super.dispose();
  }

  void _onJsonTextChanged() {
    _validateJson(_jsonController.text);
  }

  void _validateJson(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _jsonError = null;
        _isJsonValid = false;
      });
      return;
    }

    try {
      json.decode(text);
      setState(() {
        _jsonError = null;
        _isJsonValid = true;
      });
    } on FormatException catch (e) {
      setState(() {
        _jsonError = e.message;
        _isJsonValid = false;
      });
    }
  }

  void _formatJson() {
    try {
      final decoded = json.decode(_jsonController.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      _jsonController.text = formatted;
    } on FormatException {
      // Invalid JSON, do nothing - validation errors shown elsewhere
    }
  }

  Future<void> _importPastedJson() async {
    final jsonText = _jsonController.text.trim();
    final bytes = utf8.encode(jsonText);
    await _uploadFile(bytes, 'pasted-quiz.json');
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;

        // Secondary validation - FilePicker allowedExtensions not guaranteed on all platforms
        final extension = fileName.contains('.')
            ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
            : '';
        if (!_allowedExtensions.contains(extension)) {
          _handleError('Unsupported file type. Please select a JSON file.');
          return;
        }

        await _uploadFile(fileBytes, fileName);
      }
    } on Exception catch (e) {
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

  Future<void> _uploadFile(List<int> fileBytes, String fileName) async {
    setState(() {
      _isUploading = true;
      _message = null;
    });

    try {
      final importResponse = await _apiService.importQuiz(fileBytes, fileName);

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _isSuccess = importResponse != null;
        _message = null;
      });

      if (importResponse != null) {
        _jsonController.clear();
        _showSuccessDialog(importResponse);
      }
    } on Exception catch (e) {
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
      showErrorSnackBar(context, errorInfo['message'] as String);
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

  void _showSuccessDialog(QuizSummary quiz) {
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
              Flexible(
                child: Text(
                  'Import Successful!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
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
                      quiz.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quiz.description,
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
                          '${quiz.questionCount} questions',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          quiz.type.toUpperCase(),
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

  Widget _buildPasteJsonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text area for pasting JSON
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _jsonError != null
                  ? AppColors.error
                  : _isJsonValid
                  ? AppColors.success
                  : AppColors.outline,
              width: 2,
            ),
            borderRadius: AppRadius.lgAll,
            color: AppColors.surfaceWhite,
          ),
          child: TextField(
            controller: _jsonController,
            maxLines: 10,
            enabled: !_isUploading,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Paste your quiz JSON here...',
              hintStyle: TextStyle(
                color: AppColors.textDisabled,
                fontFamily: 'monospace',
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Validation status and Format button row
        Row(
          children: [
            // Validation status
            if (_jsonController.text.trim().isNotEmpty) ...[
              if (_isJsonValid)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: AppIconSizes.md,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Valid JSON',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error,
                        color: AppColors.error,
                        size: AppIconSizes.md,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _jsonError ?? 'Invalid JSON',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const Spacer(),

            // Format button
            if (_isJsonValid)
              TextButton.icon(
                onPressed: _formatJson,
                icon: const Icon(
                  Icons.format_align_left,
                  size: AppIconSizes.sm,
                ),
                label: const Text('Format'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Import button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isJsonValid && !_isUploading ? _importPastedJson : null,
            icon: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(_isUploading ? 'Importing...' : 'Import Quiz'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
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
              'Paste JSON or upload a quiz file from your study notes',
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
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
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
                            text: 'Paste JSON or import file',
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode toggle
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Paste JSON'),
                            icon: Icon(Icons.paste, size: AppIconSizes.md),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Upload File'),
                            icon: Icon(
                              Icons.upload_file,
                              size: AppIconSizes.md,
                            ),
                          ),
                        ],
                        selected: {_isPasteMode},
                        onSelectionChanged: (value) {
                          setState(() => _isPasteMode = value.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Paste JSON area or Upload area based on mode
                    if (_isPasteMode) ...[
                      _buildPasteJsonSection(),
                    ] else ...[
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
                                    'Supports JSON format',
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
                    ],

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
                      height: MediaQuery.of(context).size.height < 700
                          ? 20
                          : 16,
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
