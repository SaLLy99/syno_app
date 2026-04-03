class CoreValue {
  final int id;
  final String key;
  final String translationKey;

  CoreValue({required this.id, required this.key, required this.translationKey});

  factory CoreValue.fromJson(Map<String, dynamic> json) {
    return CoreValue(
      id: json['id'],
      key: json['key'],
      translationKey: json['translation_key'],
    );
  }
}

class Intention {
  final int id;
  final String key;
  final String translationKey;

  Intention({required this.id, required this.key, required this.translationKey});

  factory Intention.fromJson(Map<String, dynamic> json) {
    return Intention(
      id: json['id'],
      key: json['key'],
      translationKey: json['translation_key'],
    );
  }
}