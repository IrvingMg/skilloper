import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/models/pagination.dart';

void main() {
  group('PaginationMeta.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'limit': 20,
        'offset': 40,
        'total_count': 100,
        'has_more': true,
      };

      final meta = PaginationMeta.fromJson(json);

      expect(meta.limit, 20);
      expect(meta.offset, 40);
      expect(meta.totalCount, 100);
      expect(meta.hasMore, isTrue);
    });

    test('parses has_more as false', () {
      final json = {
        'limit': 20,
        'offset': 80,
        'total_count': 100,
        'has_more': false,
      };

      final meta = PaginationMeta.fromJson(json);

      expect(meta.hasMore, isFalse);
    });

    test('handles string values by parsing to int', () {
      final json = {
        'limit': '20',
        'offset': '40',
        'total_count': '100',
        'has_more': true,
      };

      final meta = PaginationMeta.fromJson(json);

      expect(meta.limit, 20);
      expect(meta.offset, 40);
      expect(meta.totalCount, 100);
    });

    test('handles string has_more value', () {
      final json = {
        'limit': 20,
        'offset': 0,
        'total_count': 50,
        'has_more': 'true',
      };

      final meta = PaginationMeta.fromJson(json);

      expect(meta.hasMore, isTrue);
    });

    test('throws FormatException when limit is null', () {
      final json = {'offset': 0, 'total_count': 50, 'has_more': true};

      expect(
        () => PaginationMeta.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('limit'),
          ),
        ),
      );
    });

    test('throws FormatException when offset is null', () {
      final json = {'limit': 20, 'total_count': 50, 'has_more': true};

      expect(
        () => PaginationMeta.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('offset'),
          ),
        ),
      );
    });

    test('throws FormatException when total_count is null', () {
      final json = {'limit': 20, 'offset': 0, 'has_more': true};

      expect(
        () => PaginationMeta.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('total_count'),
          ),
        ),
      );
    });

    test('throws FormatException when has_more is null', () {
      final json = {'limit': 20, 'offset': 0, 'total_count': 50};

      expect(
        () => PaginationMeta.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('has_more'),
          ),
        ),
      );
    });
  });

  group('PaginationMeta.initial', () {
    test('creates initial state with default values', () {
      final meta = PaginationMeta.initial();

      expect(meta.limit, 20);
      expect(meta.offset, 0);
      expect(meta.totalCount, 0);
      expect(meta.hasMore, isFalse);
    });
  });

  group('PaginationMeta.nextOffset', () {
    test('calculates next offset correctly', () {
      const meta = PaginationMeta(
        limit: 20,
        offset: 0,
        totalCount: 100,
        hasMore: true,
      );

      expect(meta.nextOffset, 20);
    });

    test('calculates next offset for subsequent pages', () {
      const meta = PaginationMeta(
        limit: 20,
        offset: 40,
        totalCount: 100,
        hasMore: true,
      );

      expect(meta.nextOffset, 60);
    });
  });

  group('PaginatedResponse', () {
    test('holds data and pagination together', () {
      const pagination = PaginationMeta(
        limit: 10,
        offset: 0,
        totalCount: 25,
        hasMore: true,
      );

      const response = PaginatedResponse<String>(
        data: ['a', 'b', 'c'],
        pagination: pagination,
      );

      expect(response.data, ['a', 'b', 'c']);
      expect(response.pagination.totalCount, 25);
      expect(response.pagination.hasMore, isTrue);
    });
  });
}
