const _extraMarkerPrefix = '[[extra_product_id:';
const _extraMarkerSuffix = ']]';

class OrderExtraNote {
  const OrderExtraNote({required this.id, required this.name});

  final String id;
  final String name;
}

String? buildOrderItemNotes({
  String? baseNotes,
  String? extraProductId,
  String? extraProductName,
  List<OrderExtraNote>? extras,
}) {
  final lines = <String>[];
  final extraNotes = <OrderExtraNote>[];

  if (baseNotes != null && baseNotes.trim().isNotEmpty) {
    lines.add(baseNotes.trim());
  }

  if (extraProductId != null &&
      extraProductId.trim().isNotEmpty &&
      extraProductName != null &&
      extraProductName.trim().isNotEmpty) {
    extraNotes.add(
      OrderExtraNote(id: extraProductId.trim(), name: extraProductName.trim()),
    );
  }

  if (extras != null && extras.isNotEmpty) {
    for (final extra in extras) {
      if (extra.id.trim().isEmpty || extra.name.trim().isEmpty) {
        continue;
      }
      extraNotes.add(OrderExtraNote(id: extra.id.trim(), name: extra.name));
    }
  }

  final seenExtraIds = <String>{};
  for (final extra in extraNotes) {
    if (!seenExtraIds.add(extra.id)) continue;
    lines.add('Extra: ${extra.name.trim()}');
    lines.add('$_extraMarkerPrefix${extra.id}$_extraMarkerSuffix');
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
  final ids = extractExtraProductIds(rawNotes);
  if (ids.isEmpty) return null;
  return ids.first;
}

List<String> extractExtraProductIds(String? rawNotes) {
  if (rawNotes == null || rawNotes.trim().isEmpty) return const [];

  final ids = <String>[];
  for (final line in rawNotes.split('\n')) {
    if (!line.startsWith(_extraMarkerPrefix) ||
        !line.endsWith(_extraMarkerSuffix)) {
      continue;
    }

    final id = line
        .substring(
          _extraMarkerPrefix.length,
          line.length - _extraMarkerSuffix.length,
        )
        .trim();
    if (id.isEmpty) continue;
    ids.add(id);
  }

  return ids;
}
