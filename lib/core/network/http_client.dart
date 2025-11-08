// lib/core/network/http_client.dart
import 'dart:convert';
import 'dart:io' show HttpHeaders;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../base_url.dart'; // apiUrl(path, query)

class ApiException implements Exception {
  final int? status;
  final String message;
  final String? bodyPreview;
  ApiException(this.message, {this.status, this.bodyPreview});
  @override
  String toString() => 'ApiException(status=$status, message=$message, body=${bodyPreview ?? ""})';
}

class HttpX {
  HttpX._();
  static const Duration _timeout = Duration(seconds: 20);

  // ── 모든 쿼리 값을 String으로 변환 ─────────────────────────────
  static Map<String, String> _stringifyQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return const {};
    final out = <String, String>{};
    query.forEach((k, v) {
      if (k == null || v == null) return;
      out[k.toString()] = v.toString();
    });
    return out;
  }

  static Future<String?> _loadToken() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('session.v1');
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) {
          final t = (j['accessToken'] ?? j['token']) as String?;
          if (t != null && t.isNotEmpty) return t;
        }
      }
      final legacy = sp.getString('accessToken');
      if (legacy != null && legacy.isNotEmpty) return legacy;
    } catch (_) {}
    return null;
  }

  static void Function()? _onUnauthorized;
  static void setOnUnauthorized(void Function() cb) => _onUnauthorized = cb;

  static Future<Map<String, String>> _headers({
    Map<String, String>? extra,
    bool withAuth = true,
    bool noCache = false,
  }) async {
    final map = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      ...?extra,
    };
    if (withAuth) {
      final token = await _loadToken();
      if (token != null && token.isNotEmpty) {
        map[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    // 웹에서는 no-cache 헤더로 preflight 늘리지 않기
    if (noCache && !kIsWeb) {
      map['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      map['Pragma'] = 'no-cache';
      map['Expires'] = '0';
    }
    return map;
  }

  static Map<String, dynamic> _parseJson(http.Response r) {
    if (r.body.isEmpty || r.statusCode == 204) return <String, dynamic>{};
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (ct.contains('application/json')) {
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'data': decoded};
      throw ApiException('JSON root is not an object/array', status: r.statusCode);
    }
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'data': decoded};
    } catch (_) {}
    final head = r.body.length > 300 ? r.body.substring(0, 300) : r.body;
    throw ApiException('Non-JSON response', status: r.statusCode, bodyPreview: head);
  }

  static void _log(String method, Uri url, http.Response r, {Object? body}) {
    final bodyPreview = r.body.length > 400 ? '${r.body.substring(0, 400)}…' : r.body;
    debugPrint(
      '[$method] $url  => ${r.statusCode}\n'
      'REQ:${body is String ? body : (body != null ? jsonEncode(body) : '-')}\n'
      'RESP:$bodyPreview',
    );
  }

  static void _ensureOk(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 419) {
      try {
        _onUnauthorized?.call();
      } catch (_) {}
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final head = r.body.length > 400 ? r.body.substring(0, 400) : r.body;
      throw ApiException('HTTP ${r.statusCode}', status: r.statusCode, bodyPreview: head);
    }
  }

  // ──────────────────────────────────────────────────────
  // 기본 메서드
  // ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
    bool noCache = true,
  }) async {
    try {
      final q = Map<String, dynamic>.from(query ?? const {});
      if (noCache) q['__ts'] = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = apiUrl(path, _stringifyQuery(q));
      final h = await _headers(extra: headers, withAuth: withAuth, noCache: noCache);

      final res = await http.get(uri, headers: h).timeout(_timeout);
      _log('GET', uri, res);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('GET $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
    bool noCache = true,
  }) async {
    try {
      final q = Map<String, dynamic>.from(query ?? const {});
      if (noCache) q['__ts'] = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = apiUrl(path, _stringifyQuery(q));
      final h = await _headers(extra: headers, withAuth: withAuth, noCache: noCache);

      final res = await http.delete(uri, headers: h).timeout(_timeout);
      _log('DELETE', uri, res);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('DELETE $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Object body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    try {
      final uri = apiUrl(path, _stringifyQuery(query));
      final h = await _headers(extra: headers, withAuth: withAuth);
      final res = await http.post(uri, headers: h, body: jsonEncode(body)).timeout(_timeout);
      _log('POST', uri, res, body: body);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('POST $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> putJson(
    String path,
    Object body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    try {
      final uri = apiUrl(path, _stringifyQuery(query));
      final h = await _headers(extra: headers, withAuth: withAuth);
      final res = await http.put(uri, headers: h, body: jsonEncode(body)).timeout(_timeout);
      _log('PUT', uri, res, body: body);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('PUT $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> patchJson(
    String path,
    Object body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
  }) async {
    try {
      final uri = apiUrl(path, _stringifyQuery(query));
      final h = await _headers(extra: headers, withAuth: withAuth);
      final res = await http.patch(uri, headers: h, body: jsonEncode(body)).timeout(_timeout);
      _log('PATCH', uri, res, body: body);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('PATCH $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> multipart(
    String path, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool withAuth = true,
    String method = 'POST',
  }) async {
    try {
      final uri = apiUrl(path, _stringifyQuery(query));
      final token = withAuth ? await _loadToken() : null;

      final req = http.MultipartRequest(method, uri);
      if (token != null && token.isNotEmpty) {
        req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
      if (headers != null) req.headers.addAll(headers);
      if (fields != null) req.fields.addAll(fields);
      if (files != null) req.files.addAll(files);

      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      _log('MULTIPART-$method', uri, res, body: fields);
      _ensureOk(res);
      return _parseJson(res);
    } catch (e) {
      throw ApiException('MULTIPART $path 실패: $e');
    }
  }

  static Future<Map<String, dynamic>?> me() async {
    try {
      final j = await get('/auth/me');
      return j['user'] ?? j['data'] ?? j;
    } on ApiException catch (e) {
      debugPrint('[ME] fail: $e');
      return null;
    }
  }
}
