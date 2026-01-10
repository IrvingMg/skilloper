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
    return '${months[localDate.month - 1]} ${localDate.day}';
  }
}
