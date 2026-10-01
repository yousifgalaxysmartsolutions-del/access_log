/// Small readers for CAP payloads.
///
/// CAP is not consistent about numeric types or empty values across endpoints,
/// so every model funnels through these instead of using raw casts. Keeping them
/// in one place means a malformed field degrades to a sensible default rather
/// than throwing halfway through parsing a screen's data.
library;

/// Reads a JSON object, tolerating loosely typed maps.
Map<String, dynamic> capMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

/// Reads a whole-number field.
int capCount(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a decimal field without collapsing it to an `int`.
double capDecimal(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a text field, trimming and normalizing null to an empty string.
String capText(Object? value) => (value ?? '').toString().trim();

/// Formats a date as `yyyy-MM-dd`, the format both CAP date filters expect.
String formatCapDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
