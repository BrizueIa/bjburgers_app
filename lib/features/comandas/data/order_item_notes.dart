const _extraMarkerPrefix = '[[extra_product_id:';
const _extraMarkerSuffix = ']]';

String? buildOrderItemNotes({
  String? baseNotes,
  String? extraProductId,
  String? extraProductName,
}) {
  final lines = <String>[];

  if (baseNotes != null && baseNotes.trim().isNotEmpty) {
    lines.add(baseNotes.trim());
  }

  if (extraProductName != null && extraProductName.trim().isNotEmpty) {
    lines.add('Extra: ${extraProductName.trim()}');
  }

  if (extraProductId != null && extraProductId.trim().isNotEmpty) {
    lines.add('$_extraMarkerPrefix${extraProductId.trim()}$_extraMarkerSuffix');
  }

  if (lines.isEmpty) return null;
  return lines.join('\n');
}

String? displayOrderItemNotes(String? rawNotes) {
  if (rawNotes == null || rawNotes.trim().isEmpty) return null;

  final visibleLines = rawNotes
      .split('\n')
      .where((line) => !line.startsWith(_extraMarkerPrefix))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (visibleLines.isEmpty) return null;
  return visibleLines.join('\n');
}

String? extractExtraProductId(String? rawNotes) {
  if (rawNotes == null || rawNotes.trim().isEmpty) return null;

  for (final line in rawNotes.split('\n')) {
    if (!line.startsWith(_extraMarkerPrefix) ||
        !line.endsWith(_extraMarkerSuffix)) {
      continue;
    }

    return line
        .substring(
          _extraMarkerPrefix.length,
          line.length - _extraMarkerSuffix.length,
        )
        .trim();
  }

  return null;
}
