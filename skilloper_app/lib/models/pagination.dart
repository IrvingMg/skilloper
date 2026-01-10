/// Pagination metadata from API responses
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
    return PaginationMeta(
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      totalCount: json['total_count'] as int,
      hasMore: json['has_more'] as bool,
    );
  }

  /// Initial empty state (hasMore is false until first load succeeds)
  factory PaginationMeta.initial() {
    return const PaginationMeta(
      limit: 20,
      offset: 0,
      totalCount: 0,
      hasMore: false,
    );
  }

  /// Get next offset for loading more
  int get nextOffset => offset + limit;
}

/// Generic paginated response wrapper
class PaginatedResponse<T> {
  final List<T> data;
  final PaginationMeta pagination;

  const PaginatedResponse({required this.data, required this.pagination});
}
