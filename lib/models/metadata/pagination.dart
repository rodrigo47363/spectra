part of 'metadata.dart';

@Freezed(genericArgumentFactories: true)
class SpotubePaginationResponseObject<T>
    with _$SpotubePaginationResponseObject<T> {
  factory SpotubePaginationResponseObject({
    required int limit,
    required int? nextOffset,
    required int total,
    required bool hasMore,
    required List<T> items,
  }) = _SpotubePaginationResponseObject<T>;

  factory SpotubePaginationResponseObject.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    final sanitized = Map<String, dynamic>.from(json);
    sanitized['limit'] = (sanitized['limit'] as num?)?.toInt() ?? 20;
    sanitized['total'] = (sanitized['total'] as num?)?.toInt() ?? 0;
    sanitized['hasMore'] = sanitized['hasMore'] as bool? ?? false;
    sanitized['items'] = (sanitized['items'] as List<dynamic>?) ?? [];
    return _$SpotubePaginationResponseObjectFromJson<T>(
      sanitized,
      (item) => fromJsonT(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}),
    );
  }
}
