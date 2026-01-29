class CollectionBreadcrumb {
  final int id;
  final String name;

  const CollectionBreadcrumb({required this.id, required this.name});

  factory CollectionBreadcrumb.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];

    if (id == null || name == null) {
      throw const FormatException('CollectionBreadcrumb missing required field');
    }

    return CollectionBreadcrumb(
      id: id is int ? id : int.parse(id.toString()),
      name: name.toString(),
    );
  }
}

class Collection {
  final int id;
  final int? parentId;
  final String name;
  final int quizCount;
  final int totalQuizCount;
  final int childCount;
  final List<CollectionBreadcrumb> ancestors;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Collection({
    required this.id,
    required this.name,
    required this.quizCount,
    required this.totalQuizCount,
    required this.childCount,
    required this.ancestors,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  bool get hasChildren => childCount > 0;

  factory Collection.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['created_at'];

    if (id == null) {
      throw const FormatException('Collection missing required field: id');
    }
    if (name == null) {
      throw const FormatException('Collection missing required field: name');
    }
    if (createdAt == null) {
      throw const FormatException(
        'Collection missing required field: created_at',
      );
    }

    final updatedAt = json['updated_at'];
    final ancestorsJson = json['ancestors'] as List<dynamic>?;

    return Collection(
      id: id is int ? id : int.parse(id.toString()),
      parentId: json['parent_id'] != null
          ? (json['parent_id'] is int
              ? json['parent_id'] as int
              : int.parse(json['parent_id'].toString()))
          : null,
      name: name.toString(),
      quizCount: (json['quiz_count'] as int?) ?? 0,
      totalQuizCount: (json['total_quiz_count'] as int?) ?? 0,
      childCount: (json['child_count'] as int?) ?? 0,
      ancestors: ancestorsJson
              ?.map(
                (a) => CollectionBreadcrumb.fromJson(a as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: DateTime.parse(createdAt.toString()),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt.toString())
          : DateTime.parse(createdAt.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (parentId != null) 'parent_id': parentId,
    };
  }
}
