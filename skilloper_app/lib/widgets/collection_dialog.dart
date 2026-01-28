import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CollectionDialog extends StatefulWidget {
  final String? initialName;

  const CollectionDialog({super.key, this.initialName});

  @override
  State<CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<CollectionDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.initialName != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Rename Collection' : 'Create Collection'),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g., Go Fundamentals',
          ),
          autofocus: true,
          maxLength: 100,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Name is required')));
              return;
            }
            Navigator.pop(context, {'name': name});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
