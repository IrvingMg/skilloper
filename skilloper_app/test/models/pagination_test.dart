import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/models/pagination.dart';

void main() {
  group('PaginationMeta', () {
    group('fromJson', () {
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

      test('parses when has_more is false', () {
        final json = {
          'limit': 10,
          'offset': 90,
          'total_count': 100,
          'has_more': false,
        };

        final meta = PaginationMeta.fromJson(json);

        expect(meta.hasMore, isFalse);
      });

      test('parses zero offset', () {
        final json = {
          'limit': 20,
          'offset': 0,
          'total_count': 50,
          'has_more': true,
        };

        final meta = PaginationMeta.fromJson(json);

        expect(meta.offset, 0);
        expect(meta.nextOffset, 20);
      });
    });

    group('initial', () {
      test('creates correct default values', () {
        final meta = PaginationMeta.initial();

        expect(meta.limit, 20);
        expect(meta.offset, 0);
        expect(meta.totalCount, 0);
        expect(meta.hasMore, isFalse);
      });
    });

    group('nextOffset', () {
      test('calculates offset + limit', () {
        final meta = PaginationMeta(
          limit: 20,
          offset: 40,
          totalCount: 100,
          hasMore: true,
        );

        expect(meta.nextOffset, 60);
      });

      test('works with zero offset', () {
        final meta = PaginationMeta(
          limit: 10,
          offset: 0,
          totalCount: 50,
          hasMore: true,
        );

        expect(meta.nextOffset, 10);
      });

      test('calculates correctly even when would exceed total', () {
        final meta = PaginationMeta(
          limit: 20,
          offset: 90,
          totalCount: 100,
          hasMore: false,
        );

        // nextOffset is still computed, caller uses hasMore to decide
        expect(meta.nextOffset, 110);
      });
    });
  });
}
