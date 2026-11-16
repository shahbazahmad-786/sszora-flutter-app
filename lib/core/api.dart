import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.errors = const {}});

  final String message;
  final int? status;
  final Map<String, List<String>> errors;

  String get display {
    for (final list in errors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return message;
  }

  @override
  String toString() => display;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.deviceId});

  String baseUrl;
  String deviceId;
  String? token;
  String country = 'US';

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$root$normalized').replace(
      queryParameters: query == null || query.isEmpty ? null : _query(query),
    );
  }

  Map<String, dynamic> _query(Map<String, dynamic> query) {
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is List) {
        final values = value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
        if (values.isEmpty) return;
        out[key.endsWith('[]') ? key : '$key[]'] = values;
        return;
      }
      if (value is bool) {
        if (value) out[key] = '1';
        return;
      }
      final text = value.toString();
      if (text.isEmpty) return;
      out[key] = text;
    });
    return out;
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    return {
      'Accept': 'application/json',
      'X-Device-Id': deviceId,
      'X-Country': country,
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) {
    return _send(() => http.get(uri(path, query), headers: _headers(jsonBody: false)));
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) {
    return _send(() => http.post(uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) {
    return _send(() => http.put(uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) {
    return _send(() => http.patch(uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> delete(String path) {
    return _send(() => http.delete(uri(path), headers: _headers(jsonBody: false)));
  }

  Future<dynamic> upload(
    String path, {
    Map<String, String> fields = const {},
    String? fileField,
    String? filePath,
  }) async {
    final request = http.MultipartRequest('POST', uri(path));
    request.headers.addAll(_headers(jsonBody: false));
    request.fields.addAll(fields);
    if (fileField != null && filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      return await _attempt(call);
    } on ApiException catch (error) {
      if (!_retryable(error)) rethrow;
      return _attempt(call);
    }
  }

  bool _retryable(ApiException error) {
    final text = error.message.toLowerCase();
    return text.contains('connection closed') || text.contains('connection reset') || text.contains('broken pipe');
  }

  Future<dynamic> _attempt(Future<http.Response> Function() call) async {
    try {
      return _decode(await call().timeout(const Duration(seconds: 40)));
    } on ApiException {
      rethrow;
    } on HandshakeException {
      throw ApiException('This device does not trust the store certificate.');
    } on SocketException {
      throw ApiException('Cannot reach the store. Check the server address and your connection.');
    } on TimeoutException {
      throw ApiException('The store request timed out. Check your internet connection and try again.');
    } on http.ClientException catch (error) {
      throw ApiException('The store request failed: ${error.message}');
    } on FormatException catch (error) {
      throw ApiException('The server returned invalid data: ${error.message}');
    } catch (error) {
      final text = error.toString();
      if (text.contains('CERTIFICATE_VERIFY_FAILED') || text.contains('HandshakeException')) {
        throw ApiException('This device does not trust the store certificate.');
      }
      throw ApiException('Request failed (${error.runtimeType}): $error');
    }
  }

  dynamic _decode(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {'message': response.body};
      }
    }

    if (response.statusCode >= 400) {
      final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      final errors = <String, List<String>>{};
      final rawErrors = map['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value.map((item) => item.toString()).toList();
          }
        });
      }
      throw ApiException(
        (map['message'] ?? 'Request failed').toString(),
        status: response.statusCode,
        errors: errors,
      );
    }

    return body ?? <String, dynamic>{};
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<dynamic> asList(dynamic value) => value is List ? value : const [];

String str(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text == 'null' ? fallback : text;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String plainText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
