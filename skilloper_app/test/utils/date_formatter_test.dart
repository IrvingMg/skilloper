import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/utils/date_formatter.dart';

void main() {
  group('formatRelativeDate', () {
    test('returns Today for current time', () {
      final now = DateTime.now();
      expect(formatRelativeDate(now), 'Today');
    });

    test('returns Today for time earlier today', () {
      final now = DateTime.now();
      final earlierToday = now.subtract(const Duration(hours: 2));
      expect(formatRelativeDate(earlierToday), 'Today');
    });

    test('returns Today for future date (timezone mismatch handling)', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 1));
      expect(formatRelativeDate(future), 'Today');
    });

    test('returns Yesterday for 1 day ago', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      expect(formatRelativeDate(yesterday), 'Yesterday');
    });

    test('returns X days ago for 2-6 days', () {
      final now = DateTime.now();

      final twoDaysAgo = now.subtract(const Duration(days: 2));
      expect(formatRelativeDate(twoDaysAgo), '2 days ago');

      final sixDaysAgo = now.subtract(const Duration(days: 6));
      expect(formatRelativeDate(sixDaysAgo), '6 days ago');
    });

    test('returns 1 week ago for exactly 7 days', () {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      expect(formatRelativeDate(oneWeekAgo), '1 week ago');
    });

    test('returns X weeks ago for 8-29 days', () {
      final now = DateTime.now();

      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      expect(formatRelativeDate(twoWeeksAgo), '2 weeks ago');

      final threeWeeksAgo = now.subtract(const Duration(days: 21));
      expect(formatRelativeDate(threeWeeksAgo), '3 weeks ago');
    });

    test('returns month and day for 30+ days', () {
      final now = DateTime.now();
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));
      final result = formatRelativeDate(sixtyDaysAgo);

      // Should be in format "Mon D" like "Nov 11"
      expect(result, isNot('Today'));
      expect(result, isNot(contains('days ago')));
      expect(result, isNot(contains('weeks ago')));
      // Verify it matches month abbreviation format
      expect(
        RegExp(
          r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{1,2}$',
        ).hasMatch(result),
        isTrue,
        reason: 'Expected format like "Nov 11", got "$result"',
      );
    });

    test('handles UTC dates by converting to local', () {
      // Create a UTC date from yesterday
      final now = DateTime.now();
      final yesterdayUtc = now.subtract(const Duration(days: 1)).toUtc();
      expect(formatRelativeDate(yesterdayUtc), 'Yesterday');
    });
  });

  group('formatFullDate', () {
    test('formats date with time correctly', () {
      final date = DateTime(2024, 3, 15, 14, 30);
      expect(formatFullDate(date), '15/3/2024 at 14:30');
    });

    test('pads hour and minute with zeros', () {
      final date = DateTime(2024, 1, 5, 9, 5);
      expect(formatFullDate(date), '5/1/2024 at 09:05');
    });

    test('handles midnight correctly', () {
      final date = DateTime(2024, 12, 25, 0, 0);
      expect(formatFullDate(date), '25/12/2024 at 00:00');
    });

    test('handles UTC dates by converting to local', () {
      final utcDate = DateTime.utc(2024, 6, 15, 12, 30);
      final result = formatFullDate(utcDate);
      // Result should be in local time format
      expect(result, contains('at'));
      expect(
        RegExp(r'^\d{1,2}/\d{1,2}/\d{4} at \d{2}:\d{2}$').hasMatch(result),
        isTrue,
      );
    });
  });

  group('formatRelativeDateWithTime', () {
    test('returns Today at HH:MM for current date', () {
      final now = DateTime.now();
      final result = formatRelativeDateWithTime(now);

      expect(result, startsWith('Today at '));
      expect(
        RegExp(r'^Today at \d{2}:\d{2}$').hasMatch(result),
        isTrue,
        reason: 'Expected format like "Today at 14:30", got "$result"',
      );
    });

    test('returns Yesterday at HH:MM for yesterday', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 15, 45);
      final result = formatRelativeDateWithTime(yesterday);

      expect(result, 'Yesterday at 15:45');
    });

    test('returns D/M/YYYY at HH:MM for older dates', () {
      final date = DateTime(2024, 3, 15, 9, 5);
      final result = formatRelativeDateWithTime(date);

      expect(result, '15/3/2024 at 09:05');
    });

    test('pads hour and minute with zeros', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 8, 3);
      final result = formatRelativeDateWithTime(today);

      expect(result, 'Today at 08:03');
    });

    test('handles UTC dates by converting to local', () {
      final now = DateTime.now();
      final yesterdayUtc = DateTime.utc(
        now.year,
        now.month,
        now.day - 1,
        12,
        0,
      );
      final result = formatRelativeDateWithTime(yesterdayUtc);

      // Should start with Yesterday (after local conversion)
      expect(result, startsWith('Yesterday at '));
    });

    test('handles midnight correctly', () {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0);
      final result = formatRelativeDateWithTime(todayMidnight);

      expect(result, 'Today at 00:00');
    });
  });

  group('formatErrorMessage', () {
    test('strips Exception: prefix', () {
      expect(
        formatErrorMessage('Exception: Something went wrong'),
        'Something went wrong',
      );
    });

    test('preserves message without Exception: prefix', () {
      expect(
        formatErrorMessage('Something went wrong'),
        'Something went wrong',
      );
    });

    test('handles empty string', () {
      expect(formatErrorMessage(''), '');
    });

    test('handles string that starts with Exception but not Exception:', () {
      expect(
        formatErrorMessage('Exceptional error occurred'),
        'Exceptional error occurred',
      );
    });

    test('only strips first Exception: prefix', () {
      expect(
        formatErrorMessage('Exception: Exception: Nested error'),
        'Exception: Nested error',
      );
    });
  });
}
