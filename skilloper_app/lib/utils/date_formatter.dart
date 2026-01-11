/// Format date as relative time or short date
/// Used for displaying creation dates in list items
/// Converts to local time to handle UTC timestamps from server
String formatRelativeDate(DateTime date) {
  final localDate = date.toLocal();
  final now = DateTime.now();
  final difference = now.difference(localDate);

  // Handle today and future dates (e.g., server timezone mismatch)
  if (difference.inDays <= 0) {
    return 'Today';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  } else {
    // Show month and day for older dates
    return _formatShortDate(localDate);
  }
}

/// Format date as full date with time (e.g., "15/3/2024 at 14:30")
/// Used for displaying detailed timestamps
String formatFullDate(DateTime date) {
  final localDate = date.toLocal();
  final day = localDate.day;
  final month = localDate.month;
  final year = localDate.year;
  final hour = localDate.hour.toString().padLeft(2, '0');
  final minute = localDate.minute.toString().padLeft(2, '0');
  return '$day/$month/$year at $hour:$minute';
}

/// Format date as short date (e.g., "Jan 15")
String _formatShortDate(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}';
}

/// Format date as "Today at HH:MM", "Yesterday at HH:MM", or "D/M/YYYY at HH:MM"
/// Used for displaying timestamps in history lists with relative day context
String formatRelativeDateWithTime(DateTime date) {
  final localDate = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

  final time = _formatTime(localDate);

  if (dateOnly == today) {
    return 'Today at $time';
  } else if (dateOnly == today.subtract(const Duration(days: 1))) {
    return 'Yesterday at $time';
  } else {
    return '${localDate.day}/${localDate.month}/${localDate.year} at $time';
  }
}

/// Format time as HH:MM with zero-padding
String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Strips "Exception: " prefix from error messages for cleaner display
String formatErrorMessage(String error) {
  if (error.startsWith('Exception: ')) {
    return error.substring('Exception: '.length);
  }
  return error;
}
