class LocationItemParent {
  final int id;
  final String name;

  LocationItemParent({required this.id, required this.name});

  factory LocationItemParent.fromJson(Map<String, dynamic> json) {
    return LocationItemParent(
      id: json['id'],
      name: json['name']?.toString() ?? '',
    );
  }
}

class LocationItem {
  final int id;
  final String name;
  final String type;
  final LocationItemParent? parent;

  LocationItem({
    required this.id,
    required this.name,
    required this.type,
    this.parent,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      parent: json['parent'] != null ? LocationItemParent.fromJson(json['parent']) : null,
    );
  }

  /// A computed property to display the location in a user-friendly format.
  /// e.g., "New York, USA" for a city, or "USA" for a country.
  String get displayName {
    if (parent != null) {
      return '$name, ${parent!.name}';
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}