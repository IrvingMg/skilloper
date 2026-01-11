class PaginationMeta {
  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;

  const PaginationMeta({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'];
    final offset = json['offset'];
    final totalCount = json['total_count'];
    final hasMore = json['has_more'];

    if (limit == null) {
      throw const FormatException(
        'PaginationMeta missing required field: limit',
      );
    }
    if (offset == null) {
      throw const FormatException(
        'PaginationMeta missing required field: offset',
      );
    }
    if (totalCount == null) {
      throw const FormatException(
        'PaginationMeta missing required field: total_count',
      );
    }
    if (hasMore == null) {
      throw const FormatException(
        'PaginationMeta missing required field: has_more',
      );
    }

    return PaginationMeta(
      limit: limit is int ? limit : int.parse(limit.toString()),
      offset: offset is int ? offset : int.parse(offset.toString()),
      totalCount: totalCount is int
          ? totalCount
          : int.parse(totalCount.toString()),
      hasMore: hasMore is bool ? hasMore : hasMore.toString() == 'true',
    );
  }

  factory PaginationMeta.initial() {
    return const PaginationMeta(
      limit: 20,
      offset: 0,
      totalCount: 0,
      hasMore: false,
    );
  }

  int get nextOffset => offset + limit;
}

class PaginatedResponse<T> {
  final List<T> data;
  final PaginationMeta pagination;

  const PaginatedResponse({required this.data, required this.pagination});
}
