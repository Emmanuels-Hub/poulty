Map<String, dynamic> asJsonMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  if (value == null) return [];
  return (value as List).map(asJsonMap).toList();
}

Map<String, String> asStringMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, String>) return value;
  return Map<String, String>.from(value as Map);
}
