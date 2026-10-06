import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hetu_script/external/external_class.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/http/http.dart' as hetu_http;
import 'package:hetu_std/http/http.binding.dart';

class SafeHttpClient implements hetu_http.HttpClient {
  late final Dio _dio;

  SafeHttpClient([hetu_http.HttpBaseOptions? options]) {
    final defaultHeaders = <String, dynamic>{
      "User-Agent":
          "Spectra/1.0.0 (https://github.com/rodrigo47363/spectra; contact@spectra.app)",
      "Accept": "application/json",
      ...?options?.headers,
    };

    _dio = Dio(
      BaseOptions(
        baseUrl: options?.baseUrl ?? "",
        connectTimeout: options?.connectTimeout != null
            ? Duration(seconds: options!.connectTimeout!)
            : null,
        receiveTimeout: options?.receiveTimeout != null
            ? Duration(seconds: options!.receiveTimeout!)
            : null,
        sendTimeout: options?.sendTimeout != null
            ? Duration(seconds: options!.sendTimeout!)
            : null,
        followRedirects: options?.followRedirects,
        validateStatus: (status) => true,
        headers: defaultHeaders,
        queryParameters: options?.queryParameters,
      ),
    );
  }

  hetu_http.HttpResponse _buildSafeErrorResponse(
    String path,
    int statusCode,
    String message,
  ) {
    final errorObj = <String, dynamic>{
      "status": statusCode,
      "message": message,
      "error": message,
    };

    final safeDefaultData = <String, dynamic>{
      "count": 0,
      "offset": 0,
      "recordings": <dynamic>[],
      "release-groups": <dynamic>[],
      "releases": <dynamic>[],
      "artists": <dynamic>[],
      "playlists": <dynamic>[],
      "items": <dynamic>[],
      "relations": <dynamic>[],
      "media": <dynamic>[],
      "payload": <String, dynamic>{
        "data": <dynamic>[],
        "artists": <dynamic>[],
        "listens": <dynamic>[],
        "playlists": <dynamic>[],
        "events": <dynamic>[],
        "items": <dynamic>[],
        "jspf": <String, dynamic>{
          "playlist": <String, dynamic>{
            "identifier": "https://listenbrainz.org/explore/lb-radio",
            "title": "ListenBrainz",
            "date": DateTime.now().toIso8601String(),
            "creator": "listenbrainz",
            "track": <dynamic>[],
            "annotation": "Service unavailable",
            "images": <dynamic>[],
            "extension": <String, dynamic>{
              "https://musicbrainz.org/doc/jspf#playlist": <String, dynamic>{
                "public": false,
              }
            },
          }
        },
      },
      "data": <String, dynamic>{
        "releases": <dynamic>[],
        "release-groups": <dynamic>[],
        "recordings": <dynamic>[],
        "artists": <dynamic>[],
        "relations": <dynamic>[],
        "media": <dynamic>[],
      },
      "error": errorObj,
      "message": message,
      "status": statusCode,
    };

    return hetu_http.HttpResponse(
      statusCode: statusCode,
      statusMessage: message,
      data: safeDefaultData,
      headers: {},
      isRedirect: false,
    );
  }

  Map<String, dynamic> _normalizeResponseMap(
    Map rawMap,
    int statusCode,
    String statusMessage,
    String path,
  ) {
    final map = rawMap is Map<String, dynamic>
        ? rawMap
        : Map<String, dynamic>.from(rawMap);

    if (statusCode >= 400) {
      final errMsg = statusMessage.isNotEmpty ? statusMessage : "HTTP $statusCode";
      if (!map.containsKey("error")) {
        map["error"] = <String, dynamic>{
          "status": statusCode,
          "message": errMsg,
          "error": errMsg,
        };
      } else if (map["error"] is String) {
        final errStr = map["error"] as String;
        map["error"] = <String, dynamic>{
          "status": statusCode,
          "message": errStr,
          "error": errStr,
        };
      } else if (map["error"] is Map) {
        final errMap = Map<String, dynamic>.from(map["error"] as Map);
        errMap["status"] ??= statusCode;
        errMap["message"] ??= errMsg;
        map["error"] = errMap;
      }
    }

    // Ensure map['payload'] is safe
    if (!map.containsKey("payload") || map["payload"] == null || map["payload"] is! Map) {
      map["payload"] = <String, dynamic>{
        "data": <dynamic>[],
        "artists": <dynamic>[],
        "listens": <dynamic>[],
        "playlists": <dynamic>[],
        "events": <dynamic>[],
        "items": <dynamic>[],
        "jspf": <String, dynamic>{
          "playlist": <String, dynamic>{
            "track": <dynamic>[],
          }
        },
      };
    } else if (map["payload"] is Map) {
      final pMap = map["payload"] as Map;
      pMap["data"] ??= <dynamic>[];
      pMap["artists"] ??= <dynamic>[];
      pMap["listens"] ??= <dynamic>[];
      pMap["playlists"] ??= <dynamic>[];
      pMap["events"] ??= <dynamic>[];
      pMap["items"] ??= <dynamic>[];
    }

    // Ensure map['data'] is safe
    if (!map.containsKey("data") || map["data"] == null || map["data"] is! Map) {
      map["data"] = <String, dynamic>{
        "releases": <dynamic>[],
        "release-groups": <dynamic>[],
        "recordings": <dynamic>[],
        "artists": <dynamic>[],
        "relations": <dynamic>[],
        "media": <dynamic>[],
      };
    } else if (map["data"] is Map) {
      final dMap = map["data"] as Map;
      dMap["releases"] ??= <dynamic>[];
      dMap["release-groups"] ??= <dynamic>[];
      dMap["recordings"] ??= <dynamic>[];
      dMap["artists"] ??= <dynamic>[];
      dMap["relations"] ??= <dynamic>[];
      dMap["media"] ??= <dynamic>[];
    }

    map["recordings"] ??= <dynamic>[];
    map["release-groups"] ??= <dynamic>[];
    map["releases"] ??= <dynamic>[];
    map["artists"] ??= <dynamic>[];
    map["playlists"] ??= <dynamic>[];
    map["items"] ??= <dynamic>[];
    map["relations"] ??= <dynamic>[];
    map["media"] ??= <dynamic>[];
    map["count"] ??= 0;
    map["offset"] ??= 0;

    void purgeNulls(dynamic obj) {
      if (obj is List) {
        obj.removeWhere((e) => e == null);
        for (final item in obj) {
          purgeNulls(item);
        }
      } else if (obj is Map) {
        for (final val in obj.values) {
          purgeNulls(val);
        }
      }
    }

    purgeNulls(map);

    return map;
  }

  @override
  Future<hetu_http.HttpResponse> request({
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
    int attempt = 0,
  }) async {
    try {
      final dioOptions = options != null
          ? hetu_http.optionsWrapperToDioOptions(options)
          : Options();
      dioOptions.validateStatus = (status) => true;

      final res = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: dioOptions,
      );

      var responseData = res.data;
      final statusCode = res.statusCode ?? 200;
      final statusMessage = res.statusMessage ?? (statusCode >= 400 ? "HTTP $statusCode" : "OK");

      if ((statusCode == 503 || statusCode == 429) && attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 1000));
        return await request(
          path: path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          attempt: attempt + 1,
        );
      }

      if (responseData is String) {
        try {
          final decoded = jsonDecode(responseData);
          if (decoded is Map) {
            responseData = decoded;
          }
        } catch (_) {}
      }

      if (responseData == null || (responseData is! Map && statusCode >= 400)) {
        return _buildSafeErrorResponse(path, statusCode, statusMessage);
      }

      if (responseData is Map) {
        responseData = _normalizeResponseMap(
          responseData,
          statusCode,
          statusMessage,
          path,
        );
      } else {
        responseData = <String, dynamic>{};
      }

      return hetu_http.HttpResponse(
        statusCode: statusCode,
        statusMessage: statusMessage,
        data: responseData,
        headers: res.headers.map,
        isRedirect: res.isRedirect,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 500;
      final statusMessage = e.message ?? "HTTP $statusCode";

      if (e.response != null && e.response!.data != null) {
        var responseData = e.response!.data;
        if (responseData is String) {
          try {
            final decoded = jsonDecode(responseData);
            if (decoded is Map) responseData = decoded;
          } catch (_) {}
        }
        if (responseData is Map) {
          responseData = _normalizeResponseMap(
            responseData,
            statusCode,
            statusMessage,
            path,
          );
          return hetu_http.HttpResponse(
            statusCode: statusCode,
            statusMessage: e.response!.statusMessage ?? statusMessage,
            data: responseData,
            headers: e.response!.headers.map,
            isRedirect: e.response!.isRedirect,
          );
        }
      }

      return _buildSafeErrorResponse(path, statusCode, statusMessage);
    } catch (e) {
      return _buildSafeErrorResponse(path, 500, e.toString());
    }
  }

  @override
  Future<hetu_http.HttpResponse> head(
    String path, {
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      queryParameters: queryParameters,
      options: options.copyWith(method: "HEAD"),
    );
  }

  @override
  Future<hetu_http.HttpResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      queryParameters: queryParameters,
      options: options.copyWith(method: "GET"),
    );
  }

  @override
  Future<hetu_http.HttpResponse> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      data: data,
      queryParameters: queryParameters,
      options: options.copyWith(method: "POST"),
    );
  }

  @override
  Future<hetu_http.HttpResponse> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      data: data,
      queryParameters: queryParameters,
      options: options.copyWith(method: "PUT"),
    );
  }

  @override
  Future<hetu_http.HttpResponse> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      data: data,
      queryParameters: queryParameters,
      options: options.copyWith(method: "DELETE"),
    );
  }

  @override
  Future<hetu_http.HttpResponse> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    hetu_http.RequestOptions? options,
  }) async {
    options ??= const hetu_http.RequestOptions();
    return await request(
      path: path,
      data: data,
      queryParameters: queryParameters,
      options: options.copyWith(method: "PATCH"),
    );
  }
}

class SafeHttpClientClassBinding extends HTExternalClass {
  SafeHttpClientClassBinding() : super('HttpClient');

  @override
  dynamic memberGet(String varName, {String? from}) {
    switch (varName) {
      case 'HttpClient':
        return (HTEntity entity, {positionalArgs, namedArgs, typeArgs}) {
          final options =
              positionalArgs != null && positionalArgs.isNotEmpty
                  ? positionalArgs[0]
                  : null;
          return SafeHttpClient(
            options is hetu_http.HttpBaseOptions ? options : null,
          );
        };
      default:
        throw HTError.undefined(varName);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic object, String varName) {
    var i = object as SafeHttpClient;
    return i.htFetch(varName);
  }
}
