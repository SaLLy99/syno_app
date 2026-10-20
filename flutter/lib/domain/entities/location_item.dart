import 'package:easy_localization/easy_localization.dart';

class LocationItemParent {
  final int id;
  final String name;
  final String translationKey;

  LocationItemParent({required this.id, required this.name, required this.translationKey});

  factory LocationItemParent.fromJson(Map<String, dynamic> json) {
    return LocationItemParent(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      translationKey: json['translation_key']?.toString() ?? json['translationKey']?.toString() ?? '',
    );
  }
}

class LocationItem {
  final int id;
  final String name;
  final String type;
  final String translationKey;
  final LocationItemParent? parent;
  final double? latitude;
  final double? longitude;
  final String? timezone;

  LocationItem({
    required this.id,
    required this.name,
    required this.type,
    required this.translationKey,
    this.parent,
    this.latitude,
    this.longitude,
    this.timezone,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      translationKey: json['translation_key']?.toString() ?? json['translationKey']?.toString() ?? '',
      parent: json['parent'] != null ? LocationItemParent.fromJson(json['parent']) : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
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

  /// A computed property to display the location in a localized user-friendly format.
  String get localizedDisplayName {
    final String translatedName = (translationKey.isNotEmpty && translationKey.tr() != translationKey)
        ? translationKey.tr()
        : name;
    if (parent != null) {
      final String parentTranslatedName = (parent!.translationKey.isNotEmpty && parent!.translationKey.tr() != parent!.translationKey)
          ? parent!.translationKey.tr()
          : parent!.name;
      return '$translatedName, $parentTranslatedName';
    }
    return translatedName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}