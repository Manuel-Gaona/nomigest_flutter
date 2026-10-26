/// Objeto JSON tal como lo devuelve la API.
typedef Json = Map<String, dynamic>;

/// Lectura segura de valores del JSON de la API.
extension JsonX on Json {
  String str(String key) => this[key]?.toString() ?? '';

  num numero(String key) {
    final v = this[key];
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  int? entero(String key) {
    final v = this[key];
    if (v is int) return v;
    return int.tryParse('${v ?? ''}');
  }

  bool flag(String key) => this[key] == true;

  Json? obj(String key) => this[key] is Map ? Json.from(this[key] as Map) : null;

  List<Json> lista(String key) => asJsonList(this[key]);
}

List<Json> asJsonList(dynamic value) =>
    value is List ? [for (final e in value) Json.from(e as Map)] : <Json>[];
