class ContentRangeHeader {
  final int start;
  final int end;
  final int total;

  ContentRangeHeader(this.start, this.end, this.total);

  factory ContentRangeHeader.parse(String value) {
    if (value.isEmpty) {
      return ContentRangeHeader(0, 0, 0);
    }

    try {
      final parts = value.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) return ContentRangeHeader(0, 0, 0);

      final rangeParts = parts[1].split('/');
      if (rangeParts.length != 2) return ContentRangeHeader(0, 0, 0);

      final range = rangeParts[0].split('-');
      if (range.length != 2) return ContentRangeHeader(0, 0, 0);

      final start = int.tryParse(range[0]) ?? 0;
      final end = int.tryParse(range[1]) ?? 0;
      final total = int.tryParse(rangeParts[1]) ?? 0;

      return ContentRangeHeader(start, end, total);
    } catch (_) {
      return ContentRangeHeader(0, 0, 0);
    }
  }

  @override
  String toString() {
    return 'bytes $start-$end/$total';
  }
}

class RangeHeader {
  final int start;
  final int? end;

  RangeHeader(this.start, this.end);

  factory RangeHeader.parse(String value) {
    if (value.isEmpty) {
      return RangeHeader(0, null);
    }

    try {
      final parts = value.split('=');
      if (parts.length != 2) {
        return RangeHeader(0, null);
      }

      final ranges = parts[1].split('-');

      return RangeHeader(
        int.tryParse(ranges[0]) ?? 0,
        ranges.elementAtOrNull(1) != null && ranges[1].isNotEmpty
            ? int.tryParse(ranges[1])
            : null,
      );
    } catch (_) {
      return RangeHeader(0, null);
    }
  }

  @override
  String toString() {
    return 'bytes=$start-${end ?? ""}';
  }
}
