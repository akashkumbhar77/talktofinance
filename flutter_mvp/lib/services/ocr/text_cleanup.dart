String cleanOcrText(String input) {
  var s = input;
  // Normalize newlines.
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // Join hyphenated line breaks: "transac-\ntion" -> "transaction"
  s = s.replaceAll(RegExp(r'(\w)-\n(\w)'), r'$1$2');
  // Replace remaining single newlines inside paragraphs with space.
  s = s.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
  // Collapse multiple whitespace.
  s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  // Collapse multiple blank lines.
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

