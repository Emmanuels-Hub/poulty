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

/// Resolves an enum by its stored `name`, falling back when the value is
/// missing or no longer part of the enum.
///
/// Cached Hive records can outlive a schema change (an enum value renamed or
/// dropped), and `Enum.values.byName` throws on those. Callers get the
/// fallback instead of a crash on startup.
T enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Maps [values] with [parse], dropping any entry that fails to decode.
List<T> parseAll<T>(
  List<Map<String, dynamic>> values,
  T Function(Map<String, dynamic>) parse,
) {
  final parsed = <T>[];
  for (final value in values) {
    try {
      parsed.add(parse(value));
    } catch (_) {
      // Skip records written by an older schema rather than losing the lot.
    }
  }
  return parsed;
}
