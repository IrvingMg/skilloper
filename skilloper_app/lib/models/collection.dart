class Collection {
  final int id;
  final String name;
  final int quizCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Collection({
    required this.id,
    required this.name,
    required this.quizCount,
    required this.createdAt,
    required this.updatedAt,
  });

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

    return Collection(
      id: id is int ? id : int.parse(id.toString()),
      name: name.toString(),
      quizCount: (json['quiz_count'] as int?) ?? 0,
      createdAt: DateTime.parse(createdAt.toString()),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt.toString())
          : DateTime.parse(createdAt.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name};
  }
}
