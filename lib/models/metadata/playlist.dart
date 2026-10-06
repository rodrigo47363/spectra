part of 'metadata.dart';

@freezed
class SpotubeFullPlaylistObject with _$SpotubeFullPlaylistObject {
  factory SpotubeFullPlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SpotubeUserObject owner,
    @Default([]) List<SpotubeImageObject> images,
    @Default([]) List<SpotubeUserObject> collaborators,
    @Default(false) bool collaborative,
    @Default(false) bool public,
  }) = _SpotubeFullPlaylistObject;

  factory SpotubeFullPlaylistObject.fromJson(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);
    sanitized['id'] = (sanitized['id'] ?? '').toString();
    sanitized['name'] = (sanitized['name'] ?? 'Playlist').toString();
    sanitized['description'] = (sanitized['description'] ?? '').toString();
    sanitized['externalUri'] = (sanitized['externalUri'] ?? '').toString();
    sanitized['images'] = sanitized['images'] is List ? sanitized['images'] : [];
    if (sanitized['owner'] is! Map) {
      sanitized['owner'] = <String, dynamic>{
        'id': 'unknown',
        'displayName': 'Spectra',
        'externalUri': '',
      };
    }
    return _$SpotubeFullPlaylistObjectFromJson(sanitized);
  }
}

@freezed
class SpotubeSimplePlaylistObject with _$SpotubeSimplePlaylistObject {
  factory SpotubeSimplePlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SpotubeUserObject owner,
    @Default([]) List<SpotubeImageObject> images,
  }) = _SpotubeSimplePlaylistObject;

  factory SpotubeSimplePlaylistObject.fromJson(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);
    sanitized['id'] = (sanitized['id'] ?? '').toString();
    sanitized['name'] = (sanitized['name'] ?? 'Playlist').toString();
    sanitized['description'] = (sanitized['description'] ?? '').toString();
    sanitized['externalUri'] = (sanitized['externalUri'] ?? '').toString();
    sanitized['images'] = sanitized['images'] is List ? sanitized['images'] : [];
    if (sanitized['owner'] is! Map) {
      sanitized['owner'] = <String, dynamic>{
        'id': 'unknown',
        'displayName': 'Spectra',
        'externalUri': '',
      };
    }
    return _$SpotubeSimplePlaylistObjectFromJson(sanitized);
  }
}
