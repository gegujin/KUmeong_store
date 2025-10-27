// lib/features/product/products_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kumeong_store/core/network/http_client.dart'; // HttpX

/// 리스트 응답 공통 페이징 컨테이너
class ProductsPage {
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int size;
  const ProductsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });
}

/// 서버의 { ok, data, ... } 또는 비래핑 {...} 모두 대응
T _dataOr<T>(Map<String, dynamic> j, T Function(Object? d) map, {T? fallback}) {
  final hasOkWrap = j.containsKey('ok') || j.containsKey('data');
  final raw = hasOkWrap ? j['data'] : j;
  return map(raw ?? fallback);
}

Map<String, dynamic> _asMap(Object? v) =>
    (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> _asMapList(Object? v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  if (v is Map) return [v.cast<String, dynamic>()];
  return const [];
}

/// 멀티파트용 이미지 확장자 → MIME subtype
String _imgSubtype(String pathOrName) {
  final ext = pathOrName.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'jpeg';
    case 'png':
      return 'png';
    case 'gif':
      return 'gif';
    default:
      return 'jpeg';
  }
}

/// 다양한 입력(images: XFile | String path | bytes)을 MultipartFile로 변환
Future<List<http.MultipartFile>> _toMultipartFiles(List<dynamic> images) async {
  final files = <http.MultipartFile>[];
  for (final img in images) {
    if (img is XFile) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        files.add(http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: img.name,
          contentType: MediaType('image', _imgSubtype(img.name)),
        ));
      } else {
        files.add(await http.MultipartFile.fromPath(
          'images',
          img.path,
          contentType: MediaType('image', _imgSubtype(img.path)),
        ));
      }
    } else if (img is String) {
      // 로컬 파일 경로
      files.add(await http.MultipartFile.fromPath(
        'images',
        img,
        contentType: MediaType('image', _imgSubtype(img)),
      ));
    } else if (img is List<int>) {
      // 메모리 바이트
      files.add(http.MultipartFile.fromBytes(
        'images',
        img,
        filename: 'upload.${_imgSubtype('file.jpg')}',
        contentType: MediaType('image', 'jpeg'),
      ));
    }
  }
  return files;
}

class ProductsApi {
  const ProductsApi();

  /// 목록: 다양한 서버 포맷을 흡수해서 ProductsPage로 통일
  static Future<ProductsPage> list({
    int page = 1,
    int size = 20,
    String? q,
  }) async {
    final res = await HttpX.get(
      '/products',
      query: {
        'page': page,
        'size': size,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );

    // data: { items | rows | products | list, total? }
    final data = _dataOr<Map<String, dynamic>>(
      res,
      (d) => _asMap(d),
      fallback: <String, dynamic>{},
    );

    List<Map<String, dynamic>> items;
    if (data['items'] is List) {
      items = _asMapList(data['items']);
    } else if (data['rows'] is List) {
      items = _asMapList(data['rows']);
    } else if (data['products'] is List) {
      items = _asMapList(data['products']);
    } else if (data['list'] is List) {
      items = _asMapList(data['list']);
    } else if (res['data'] is List) {
      // data 자체가 배열인 케이스
      items = _asMapList(res['data']);
    } else if (res is Map && res['items'] is List) {
      // 비래핑 + items
      items = _asMapList(res['items']);
    } else {
      // 비래핑 + 단일
      items = _asMapList(res);
    }

    final total = (data['total'] as int?) ?? items.length;
    return ProductsPage(items: items, total: total, page: page, size: size);
  }

  /// 상세
  static Future<Map<String, dynamic>?> detail(String id) async {
    final res = await HttpX.get('/products/$id');
    // { ok, data } | { ... }
    if (res.containsKey('data')) {
      final d = res['data'];
      return _asMap(d);
    }
    return _asMap(res);
  }

  /// 등록 (JSON)
  static Future<Map<String, dynamic>?> create(Map<String, dynamic> dto) async {
    final res = await HttpX.postJson('/products', dto);
    return res.containsKey('data') ? _asMap(res['data']) : _asMap(res);
  }

  /// 수정 (JSON)
  static Future<Map<String, dynamic>?> update(
    String id,
    Map<String, dynamic> dto,
  ) async {
    final res = await HttpX.patchJson('/products/$id', dto);
    return res.containsKey('data') ? _asMap(res['data']) : _asMap(res);
  }

  /// 삭제
  static Future<bool> remove(String id) async {
    await HttpX.delete('/products/$id');
    return true;
  }

  /// 등록 (이미지 포함, 멀티파트)
  ///
  /// - dto: images 키는 무시됨(하단 images 파라미터 사용)
  /// - images: XFile | String(path) | List<int>(bytes)
  static Future<Map<String, dynamic>?> createWithImages({
    required Map<String, dynamic> dto,
    required List<dynamic> images,
  }) async {
    final files = await _toMultipartFiles(images);

    // 멀티파트의 fields는 문자열만 허용 → toString()
    final fields = <String, String>{};
    dto.forEach((k, v) {
      if (k != 'images' && v != null) fields[k] = v.toString();
    });

    final res = await HttpX.multipart(
      '/products',
      method: 'POST',
      withAuth: true,
      fields: fields,
      files: files.isEmpty ? null : files,
    );
    return res.containsKey('data') ? _asMap(res['data']) : _asMap(res);
  }

  /// 수정 (이미지 포함, 멀티파트)
  static Future<Map<String, dynamic>?> updateWithImages({
    required String id,
    required Map<String, dynamic> dto,
    required List<dynamic> images,
  }) async {
    final files = await _toMultipartFiles(images);

    final fields = <String, String>{};
    dto.forEach((k, v) {
      if (k != 'images' && v != null) fields[k] = v.toString();
    });

    final res = await HttpX.multipart(
      '/products/$id',
      method: 'PUT',
      withAuth: true,
      fields: fields,
      files: files.isEmpty ? null : files,
    );
    return res.containsKey('data') ? _asMap(res['data']) : _asMap(res);
  }
}

const productsApi = ProductsApi();
