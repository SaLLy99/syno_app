
class Profession {
  final int id;
  final String name;

  Profession({required this.id, required this.name});

  factory Profession.fromJson(Map<String, dynamic> json) {
    return Profession(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}