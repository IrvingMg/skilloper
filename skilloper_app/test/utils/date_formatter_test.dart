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
}
