String extractJsonObject(String s) {
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return '{}';
  return s.substring(start, end + 1);
}

String extractJsonArray(String s) {
  final start = s.indexOf('[');
  final end = s.lastIndexOf(']');
  if (start == -1 || end == -1 || end <= start) return '[]';
  return s.substring(start, end + 1);
}

