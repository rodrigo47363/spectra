part of 'metadata.dart';

@freezed
class SpotubeFullArtistObject with _$SpotubeFullArtistObject {
  factory SpotubeFullArtistObject({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SpotubeImageObject> images,
    List<String>? genres,
    int? followers,
  }) = _SpotubeFullArtistObject;

  factory SpotubeFullArtistObject.fromJson(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);
    final id = (sanitized['id'] ?? '').toString();
    sanitized['id'] = id;
    final rawName = sanitized['name']?.toString().trim();
    final extractedYtName = id.startsWith('yt-')
        ? Uri.decodeComponent(
            id.replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '').replaceFirst(RegExp(r'^yt:'), ''),
          ).split('::')[0].trim()
        : '';
    sanitized['name'] = (rawName != null && rawName.isNotEmpty && rawName != 'Unknown Artist')
        ? rawName
        : (extractedYtName.isNotEmpty ? extractedYtName : 'Artist');
    final cleanId = id.split('::')[0];
    sanitized['externalUri'] = (sanitized['externalUri'] ??
            (cleanId.isNotEmpty ? 'https://musicbrainz.org/artist/$cleanId' : ''))
        .toString();
    var images = sanitized['images'] is List ? (sanitized['images'] as List) : [];
    if (images.isEmpty && id.contains('::img:')) {
      final parts = id.split('::img:');
      if (parts.length > 1) {
        try {
          final imgUrl = Uri.decodeComponent(parts[1].split('::')[0]);
          if (imgUrl.isNotEmpty) {
            images = [
              {'url': imgUrl, 'height': 300, 'width': 300}
            ];
          }
        } catch (_) {}
      }
    }
    sanitized['images'] = images;
    return _$SpotubeFullArtistObjectFromJson(sanitized);
  }
}

@freezed
class SpotubeSimpleArtistObject with _$SpotubeSimpleArtistObject {
  factory SpotubeSimpleArtistObject({
    required String id,
    required String name,
    required String externalUri,
    List<SpotubeImageObject>? images,
  }) = _SpotubeSimpleArtistObject;

  factory SpotubeSimpleArtistObject.fromJson(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);
    final id = (sanitized['id'] ?? '').toString();
    sanitized['id'] = id;
    final rawName = sanitized['name']?.toString().trim();
    final extractedYtName = id.startsWith('yt-')
        ? Uri.decodeComponent(
            id.replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '').replaceFirst(RegExp(r'^yt:'), ''),
          ).split('::')[0].trim()
        : '';
    sanitized['name'] = (rawName != null && rawName.isNotEmpty && rawName != 'Unknown Artist')
        ? rawName
        : (extractedYtName.isNotEmpty ? extractedYtName : 'Artist');
    final cleanId = id.split('::')[0];
    sanitized['externalUri'] = (sanitized['externalUri'] ??
            (cleanId.isNotEmpty ? 'https://musicbrainz.org/artist/$cleanId' : ''))
        .toString();
    if ((sanitized['images'] == null ||
            (sanitized['images'] is List && (sanitized['images'] as List).isEmpty)) &&
        id.contains('::img:')) {
      final parts = id.split('::img:');
      if (parts.length > 1) {
        try {
          final imgUrl = Uri.decodeComponent(parts[1].split('::')[0]);
          if (imgUrl.isNotEmpty) {
            sanitized['images'] = [
              {'url': imgUrl, 'height': 300, 'width': 300}
            ];
          }
        } catch (_) {}
      }
    }
    return _$SpotubeSimpleArtistObjectFromJson(sanitized);
  }
}

extension SpotubeFullArtistObjectAsString on List<SpotubeFullArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}

extension SpotubeSimpleArtistObjectAsString on List<SpotubeSimpleArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}
