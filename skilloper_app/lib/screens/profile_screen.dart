import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({required this.onLogout, super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final _upperCaseRegex = RegExp('[A-Z]');
  static final _lowerCaseRegex = RegExp('[a-z]');
  static final _digitRegex = RegExp('[0-9]');

  final _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.username ?? 'Unknown',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (user != null)
                Text(
                  'Member since ${_formatDate(user.createdAt)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 32),
              // Account settings section
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildOptionTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: _isLoading
                          ? null
                          : () => _showChangePasswordDialog(context),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.outline.withValues(alpha: 0.2),
                    ),
                    _buildOptionTile(
                      icon: Icons.history,
                      title: 'Reset Quiz History',
                      subtitle: 'Clear all your quiz attempts',
                      onTap: _isLoading
                          ? null
                          : () => _showResetHistoryDialog(context),
                    ),
                    if (!(user?.isAdmin ?? false)) ...[
                      Divider(
                        height: 1,
                        color: AppColors.outline.withValues(alpha: 0.2),
                      ),
                      _buildOptionTile(
                        icon: Icons.delete_forever,
                        title: 'Delete Account',
                        subtitle: 'Permanently remove your account',
                        iconColor: AppColors.error,
                        textColor: AppColors.error,
                        onTap: _isLoading
                            ? null
                            : () => _showDeleteAccountDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _confirmLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color:
                    textColor?.withValues(alpha: 0.7) ??
                    AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: textColor ?? AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change Password'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        helperText:
                            'Min 8 chars with uppercase, lowercase, and digit',
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!value.contains(_upperCaseRegex)) {
                          return 'Password must contain an uppercase letter';
                        }
                        if (!value.contains(_lowerCaseRegex)) {
                          return 'Password must contain a lowercase letter';
                        }
                        if (!value.contains(_digitRegex)) {
                          return 'Password must contain a digit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );

      if ((confirmed ?? false) && mounted) {
        setState(() => _isLoading = true);
        try {
          await _authService.updatePassword(
            currentPasswordController.text,
            newPasswordController.text,
          );
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Password updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } on AuthException catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } finally {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _showResetHistoryDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Quiz History'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete all your quiz attempts and results. This action cannot be undone.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Enter your password to confirm',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reset History'),
            ),
          ],
        ),
      );

      if ((confirmed ?? false) && mounted) {
        setState(() => _isLoading = true);
        try {
          final deletedCount = await _authService.resetHistory(
            passwordController.text,
          );
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Cleared $deletedCount quiz attempt${deletedCount == 1 ? '' : 's'}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } on AuthException catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account and all associated data including:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  '  - Your profile\n  - All quizzes you created\n  - All quiz history and results',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Enter your password to confirm',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      );

      if ((confirmed ?? false) && mounted) {
        setState(() => _isLoading = true);
        try {
          await _authService.deleteAccount(passwordController.text);
          if (mounted) {
            widget.onLogout();
          }
        } on AuthException catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } on Object catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Failed to delete account: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      await _authService.logout();
      if (mounted) {
        widget.onLogout();
      }
    }
  }
}
