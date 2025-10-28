// // lib/models/post.dart
// import 'latlng.dart';

// /// 판매자 정보 모델
// class Seller {
//   final String id;
//   final String name;
//   final String avatarUrl; // 백엔드 연동 시 URL 문자열
//   final String locationName;
//   final double rating; // 0.0 ~ 5.0

//   const Seller({
//     required this.id,
//     required this.name,
//     required this.avatarUrl,
//     required this.locationName,
//     required this.rating,
//   });

//   Seller copyWith({
//     String? id,
//     String? name,
//     String? avatarUrl,
//     String? locationName,
//     double? rating,
//   }) {
//     return Seller(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       avatarUrl: avatarUrl ?? this.avatarUrl,
//       locationName: locationName ?? this.locationName,
//       rating: rating ?? this.rating,
//     );
//   }

//   factory Seller.fromJson(Map<String, dynamic> json) {
//     return Seller(
//       id: (json['id'] ?? '').toString(),
//       name: (json['name'] ?? '').toString(),
//       avatarUrl: (json['avatarUrl'] ?? '').toString(),
//       locationName: (json['locationName'] ?? '').toString(),
//       rating:
//           (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'id': id,
//         'name': name,
//         'avatarUrl': avatarUrl,
//         'locationName': locationName,
//         'rating': rating,
//       };

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Seller &&
//           runtimeType == other.runtimeType &&
//           id == other.id &&
//           name == other.name &&
//           avatarUrl == other.avatarUrl &&
//           locationName == other.locationName &&
//           rating == other.rating;

//   @override
//   int get hashCode =>
//       id.hashCode ^
//       name.hashCode ^
//       avatarUrl.hashCode ^
//       locationName.hashCode ^
//       rating.hashCode;
// }

// /// 상품 정보 모델
// class Product {
//   final String id;
//   final String title;
//   final String description;
//   final int price; // 원 단위 정수
//   final List<String> imageUrls; // 기존 이미지 URL
//   final DateTime createdAt;
//   final Seller seller;
//   final LatLng location; // 위경도
//   final String? category; // 카테고리
//   final List<dynamic>? images; // 🔹 Web: XFile, Mobile: File, 등록/수정용

//   const Product({
//     required this.id,
//     required this.title,
//     required this.price,
//     required this.description,
//     required this.imageUrls,
//     required this.createdAt,
//     required this.seller,
//     required this.location,
//     this.category,
//     this.images,
//   });

//   /// 대표 이미지(없으면 null)
//   String? get mainImage => imageUrls.isNotEmpty ? imageUrls.first : null;

//   Product copyWith({
//     String? id,
//     String? title,
//     String? description,
//     int? price,
//     List<String>? imageUrls,
//     DateTime? createdAt,
//     Seller? seller,
//     LatLng? location,
//     String? category,
//     List<dynamic>? images,
//   }) {
//     return Product(
//       id: id ?? this.id,
//       title: title ?? this.title,
//       price: price ?? this.price,
//       description: description ?? this.description,
//       imageUrls: imageUrls ?? this.imageUrls,
//       createdAt: createdAt ?? this.createdAt,
//       seller: seller ?? this.seller,
//       location: location ?? this.location,
//       category: category ?? this.category,
//       images: images ?? this.images,
//     );
//   }

//   factory Product.fromJson(Map<String, dynamic> json) {
//     final imgs = (json['imageUrls'] as List?)
//             ?.where((e) => e != null)
//             .map((e) => e.toString())
//             .toList(growable: false) ??
//         const <String>[];

//     DateTime parseCreatedAt(dynamic v) {
//       if (v is int) {
//         return v > 1e12
//             ? DateTime.fromMillisecondsSinceEpoch(v)
//             : DateTime.fromMillisecondsSinceEpoch(v * 1000);
//       }
//       if (v is String && v.isNotEmpty) {
//         return DateTime.tryParse(v) ?? DateTime.now();
//       }
//       return DateTime.now();
//     }

//     LatLng parseLatLng(dynamic v) {
//       if (v is Map<String, dynamic>) {
//         final lat = (v['lat'] is num) ? (v['lat'] as num).toDouble() : 0.0;
//         final lng = (v['lng'] is num) ? (v['lng'] as num).toDouble() : 0.0;
//         return LatLng(lat: lat, lng: lng);
//       }
//       return const LatLng(lat: 0, lng: 0);
//     }

//     return Product(
//       id: (json['id'] ?? '').toString(),
//       title: (json['title'] ?? '').toString(),
//       price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
//       description: (json['description'] ?? '').toString(),
//       imageUrls: imgs,
//       createdAt: parseCreatedAt(json['createdAt']),
//       seller: Seller.fromJson(
//           (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {}),
//       location: parseLatLng(json['location']),
//       category: (json['category'] != null) ? json['category'].toString() : null,
//       images: json['images'] != null ? List<dynamic>.from(json['images']) : [],
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'id': id,
//         'title': title,
//         'price': price,
//         'description': description,
//         'imageUrls': imageUrls,
//         'createdAt': createdAt.toIso8601String(),
//         'seller': seller.toJson(),
//         'location': {'lat': location.lat, 'lng': location.lng},
//         'category': category,
//         'images': images ?? [],
//       };

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Product &&
//           runtimeType == other.runtimeType &&
//           id == other.id &&
//           title == other.title &&
//           description == other.description &&
//           price == other.price &&
//           _listEquals(imageUrls, other.imageUrls) &&
//           createdAt == other.createdAt &&
//           seller == other.seller &&
//           location == other.location &&
//           category == other.category;

//   @override
//   int get hashCode =>
//       id.hashCode ^
//       title.hashCode ^
//       description.hashCode ^
//       price.hashCode ^
//       imageUrls.hashCode ^
//       createdAt.hashCode ^
//       seller.hashCode ^
//       location.hashCode ^
//       (category?.hashCode ?? 0);
// }

// /// 작은 리스트 비교 유틸
// bool _listEquals<E>(List<E> a, List<E> b) {
//   if (identical(a, b)) return true;
//   if (a.length != b.length) return false;
//   for (var i = 0; i < a.length; i++) {
//     if (a[i] != b[i]) return false;
//   }
//   return true;
// }

// /// 더미 상품 데이터 (UI 테스트용)
// final demoProduct = Product(
//   id: 'p-001',
//   title: 'Wilson 농구공 팝니다!',
//   price: 25000,
//   description: '''
// 모델명: NCAA Replica Game Ball
// 크기: Size 7 (연습/캐주얼 경기용)
// 소재: 합성가죽
// 신제품가: 4만원 초반
// ''',
//   imageUrls: const [
//     'https://cdn.pixabay.com/photo/2017/09/07/09/58/basketball-2724391_1280.png',
//     'https://m.media-amazon.com/images/I/818IYKETb0L._AC_SX466_.jpg',
//   ],
//   createdAt: DateTime.now().subtract(const Duration(days: 2)),
//   seller: const Seller(
//     id: 'seller1',
//     name: '판매자',
//     avatarUrl:
//         'https://raw.githubusercontent.com/flutter/website/master/src/_assets/image/flutter-lockup-bg.jpg',
//     locationName: '서울 강남구 역삼동',
//     rating: 3.4,
//   ),
//   location: const LatLng(lat: 37.500613, lng: 127.036431),
//   category: '스포츠',
//   images: [], // 🔹 초기값 비어있게
// );

// lib/models/post.dart
import 'dart:developer' as dev; // 디버그 로그용
import 'latlng.dart';

/// 판매자 정보 모델
class Seller {
  final String id;
  final String name;
  final String avatarUrl;
  final String locationName;
  final double rating;

  const Seller({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.locationName,
    required this.rating,
  });

  Seller copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? locationName,
    double? rating,
  }) {
    return Seller(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locationName: locationName ?? this.locationName,
      rating: rating ?? this.rating,
    );
  }

  /// 중첩 객체까지 스캔해서 이름/아바타/지역을 추출
  factory Seller.fromJson(Map<String, dynamic> json) {
    String pickNameFlat(Map<String, dynamic> m) {
      for (final k in [
        'name',
        'fullName',
        'realName',
        'displayName',
        'display_name',
        'userName',
        'username',
        'nickname'
      ]) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    // 중첩 객체들까지 훑어서 이름 뽑기 (profile, account, user 등)
    String pickNameDeep(Map<String, dynamic> m) {
      final flat = pickNameFlat(m);
      if (flat.isNotEmpty) return flat;

      for (final k in [
        'profile',
        'account',
        'user',
        'owner',
        'author',
        'creator',
        'createdBy',
        'registrant',
        'member'
      ]) {
        final v = m[k];
        if (v is Map<String, dynamic>) {
          final hit = pickNameFlat(v);
          if (hit.isNotEmpty) return hit;
        }
      }

      // 일반화된 중첩 스캔(깊이 2)
      for (final entry in m.entries) {
        final v = entry.value;
        if (v is Map<String, dynamic>) {
          final hit = pickNameFlat(v);
          if (hit.isNotEmpty) return hit;
          for (final e2 in v.entries) {
            if (e2.value is Map<String, dynamic>) {
              final hit2 = pickNameFlat(e2.value as Map<String, dynamic>);
              if (hit2.isNotEmpty) return hit2;
            }
          }
        }
      }
      return '';
    }

    // 아바타/지역 중첩 추출 헬퍼
    String pickStringDeep(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // profile/account 등에서 재시도
      for (final parent in ['profile', 'account', 'user']) {
        final v = m[parent];
        if (v is Map<String, dynamic>) {
          for (final k in keys) {
            final vv = v[k];
            if (vv is String && vv.trim().isNotEmpty) return vv.trim();
          }
        }
      }
      return '';
    }

    final pickedName = pickNameDeep(json);
    final avatar =
        pickStringDeep(json, ['avatarUrl', 'profileImageUrl', 'imageUrl']);
    final locName =
        pickStringDeep(json, ['locationName', 'regionName', 'addressText']);

    return Seller(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: pickedName,
      avatarUrl: avatar,
      locationName: locName,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : (json['trustScore'] is num)
              ? (json['trustScore'] as num).toDouble()
              : (json['reliability'] is num)
                  ? (json['reliability'] as num).toDouble()
                  : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'locationName': locationName,
        'rating': rating,
      };
}

/// 상품 정보 모델
class Product {
  final String id;
  final String title;
  final String description;

  /// 서버 price 또는 priceWon을 흡수해 저장(원)
  final int price;

  /// 서버가 별도로 주면 보관
  final int? priceWon;
  final List<String> imageUrls;
  final DateTime createdAt;
  final Seller seller;
  final LatLng location;
  final String? category;

  /// 원본 이미지 배열(Web: XFile, Mobile: File 등)
  final List<dynamic>? images;

  /// 서버 locationText 보관
  final String? locationText;

  // 홈/상세 보조 필드
  int likes;
  int views;
  bool isLiked;
  bool isFavorited; // 서버 isFavorited 동기화
  int favoriteCount; // 서버 favoriteCount/favCount 합산

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrls,
    required this.createdAt,
    required this.seller,
    required this.location,
    this.category,
    this.images,
    this.priceWon,
    this.locationText,
    this.likes = 0,
    this.views = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.favoriteCount = 0,
  });

  String? get mainImage => imageUrls.isNotEmpty ? imageUrls.first : null;

  Product copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    int? priceWon,
    List<String>? imageUrls,
    DateTime? createdAt,
    Seller? seller,
    LatLng? location,
    String? category,
    List<dynamic>? images,
    String? locationText,
    int? likes,
    int? views,
    bool? isLiked,
    bool? isFavorited,
    int? favoriteCount,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      priceWon: priceWon ?? this.priceWon,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      seller: seller ?? this.seller,
      location: location ?? this.location,
      category: category ?? this.category,
      images: images ?? this.images,
      locationText: locationText ?? this.locationText,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      favoriteCount: favoriteCount ?? this.favoriteCount,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // ===== 로컬 헬퍼들 =====
    String _pickFirstNonEmptyString(List<dynamic> xs) {
      for (final v in xs) {
        if (v == null) continue;
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is Map) {
          final n = v['name'] ??
              v['fullName'] ??
              v['realName'] ??
              v['displayName'] ??
              v['display_name'] ??
              v['userName'] ??
              v['username'] ??
              v['nickname'];
          if (n is String && n.trim().isNotEmpty) return n.trim();
        }
      }
      return '';
    }

    String _nameFromMap(Map m) {
      final excludeExact = {'productname', 'categoryname'};
      final excludeContains = ['product_name', 'category_name'];
      String? best;
      bool _shouldUseKey(String key) {
        final k = key.toLowerCase();
        if (excludeExact.contains(k)) return false;
        if (excludeContains.any((s) => k.contains(s))) return false;
        return k.endsWith('name') ||
            k.contains('fullname') ||
            k.contains('realname') ||
            k.contains('display_name') ||
            k.contains('displayname') ||
            k.contains('username') ||
            k.contains('nickname');
      }

      for (final entry in m.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is String && val.trim().isNotEmpty && _shouldUseKey(key)) {
          final v = val.trim();
          if (best == null || key.toLowerCase().endsWith('name')) best = v;
        }
      }

      best ??= (() {
        final n = m['name'] ??
            m['fullName'] ??
            m['realName'] ??
            m['displayName'] ??
            m['display_name'] ??
            m['userName'] ??
            m['username'] ??
            m['nickname'];
        if (n is String && n.trim().isNotEmpty) return n.trim();
        return null;
      })();

      return best ?? '';
    }

    // 재귀(깊이 4)로 이름 후보 찾기
    String _deepScanForName(dynamic node, {int depth = 0}) {
      if (depth > 4 || node == null) return '';
      const hotKeys = [
        'seller',
        'user',
        'owner',
        'author',
        'created',
        'creator',
        'registrant',
        'account',
        'profile',
        'writer',
        'poster',
        'member',
        'publisher',
        'shop',
        'store'
      ];

      if (node is Map) {
        final direct = _nameFromMap(node);
        if (direct.isNotEmpty) return direct;

        for (final entry in node.entries) {
          final k = entry.key.toString().toLowerCase();
          final v = entry.value;
          if (v is Map && hotKeys.any((h) => k.contains(h))) {
            final hit = _deepScanForName(v, depth: depth + 1);
            if (hit.isNotEmpty) return hit;
          }
        }
        for (final v in node.values) {
          final hit = _deepScanForName(v, depth: depth + 1);
          if (hit.isNotEmpty) return hit;
        }
        return '';
      }

      if (node is List) {
        for (final it in node) {
          final hit = _deepScanForName(it, depth: depth + 1);
          if (hit.isNotEmpty) return hit;
        }
        return '';
      }
      return '';
    }

    // 이미지
    final imgs = (json['imageUrls'] as List?)
            ?.where((e) => e != null)
            .map((e) => e.toString())
            .toList(growable: false) ??
        (json['images'] is List
            ? (json['images'] as List)
                .map((e) {
                  if (e is String) return e;
                  if (e is Map) {
                    final url = e['url'] ?? e['path'] ?? e['src'];
                    return (url ?? '').toString();
                  }
                  return '';
                })
                .where((s) => s.isNotEmpty)
                .toList(growable: false)
            : (json['thumbnail'] != null
                ? [json['thumbnail'].toString()]
                : const <String>[]));

    // createdAt
    DateTime parseCreatedAt(dynamic v) {
      if (v is int) {
        return v > 1e12
            ? DateTime.fromMillisecondsSinceEpoch(v)
            : DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    // location
    LatLng parseLatLng(dynamic v) {
      if (v is Map<String, dynamic>) {
        final lat = (v['lat'] is num) ? (v['lat'] as num).toDouble() : 0.0;
        final lng = (v['lng'] is num) ? (v['lng'] as num).toDouble() : 0.0;
        return LatLng(lat: lat, lng: lng);
      } else if (v is String && v.isNotEmpty) {
        // 문자열 좌표가 오면 대략 좌표(임시 폴백)
        return const LatLng(lat: 37.5665, lng: 126.9780);
      }
      return const LatLng(lat: 0, lng: 0);
    }

    // seller 확장 탐색
    final dynamic rawSeller = json['seller'] ??
        json['user'] ??
        json['owner'] ??
        json['author'] ??
        json['createdBy'] ??
        json['creator'] ??
        json['registrant'] ??
        json['account'] ??
        json['profile'] ??
        json['writer'] ??
        json['publisher'] ??
        json['shop'] ??
        json['store'];

    Map<String, dynamic> sellerMap = const {};
    if (rawSeller is Map) {
      sellerMap = rawSeller.cast<String, dynamic>();
    } else if (rawSeller is String && rawSeller.trim().isNotEmpty) {
      sellerMap = {'name': rawSeller.trim()};
    } else {
      final nameAlias = (json['sellerName'] ??
          json['userName'] ??
          json['ownerName'] ??
          json['authorName'] ??
          json['creatorName'] ??
          json['registrantName'] ??
          json['profileName'] ??
          json['accountName'] ??
          json['displayName'] ??
          json['nickname'] ??
          json['nickName']);
      if (nameAlias is String && nameAlias.trim().isNotEmpty) {
        sellerMap = {'name': nameAlias.trim()};
      } else {
        sellerMap = const {};
      }
    }

    // sellerId 보강
    final sellerIdStr =
        (json['sellerId'] ?? json['seller_id'] ?? json['sellerID'] ?? '')
            .toString();
    if (sellerMap.isEmpty && sellerIdStr.isNotEmpty) {
      sellerMap = {'id': sellerIdStr, 'name': ''};
    } else if (!sellerMap.containsKey('id') && sellerIdStr.isNotEmpty) {
      sellerMap = {...sellerMap, 'id': sellerIdStr};
    }

    // 위치 텍스트: locationText → location → seller.locationName
    final sellerLocName = (sellerMap['locationName'] ?? '').toString();
    final String? locText = (json['locationText'] ??
            json['location'] ??
            (sellerLocName.isNotEmpty ? sellerLocName : null))
        ?.toString();

    // 디버그 로그 (원하면 주석처리)
    dev.log('TOP_KEYS=${json.keys.toList()}', name: 'Product.fromJson');
    dev.log('SELLER_RAW=${json['seller']}', name: 'Product.fromJson');
    dev.log('SELLER_KEYS=${sellerMap.keys.toList()}', name: 'Product.fromJson');

    // 가격: price / priceWon 모두 수용
    final priceAny = json['price'] ?? json['priceWon'] ?? 0;
    final int priceInt = (priceAny is num)
        ? priceAny.toInt()
        : int.tryParse(priceAny.toString().replaceAll(RegExp(r'[, ]'), '')) ??
            0;

    final priceWonAny = json['priceWon'];
    final int? priceWonInt = (priceWonAny is num)
        ? priceWonAny.toInt()
        : int.tryParse('${priceWonAny ?? ''}');

    // 판매자 이름 해석 보강
    String resolvedSellerName = _pickFirstNonEmptyString([
      sellerMap['name'],
      sellerMap['nickname'],
      sellerMap['displayName'],
      sellerMap['userName'],
    ]);

    if (resolvedSellerName.isEmpty) {
      resolvedSellerName = _pickFirstNonEmptyString([
        // 탑레벨 별칭
        json['sellerName'],
        json['userName'],
        json['ownerName'],
        json['authorName'],
        json['writerName'],
        json['posterName'],
        json['memberName'],
        json['accountName'],
        json['profileName'],
        json['creatorName'],
        json['registrantName'],
        json['publisherName'],
        json['shopName'],
        json['storeName'],
        json['nickname'],
        json['nickName'],

        // 대체 객체
        json['createdBy'],
        json['creator'],
        json['registrant'],
        json['user'],
        json['owner'],
        json['author'],
        json['account'],
        json['profile'],
        json['writer'],
        json['publisher'],
        json['shop'],
        json['store'],
      ]);
    }

    // 그래도 없으면 JSON 전체 재귀 스캔
    if (resolvedSellerName.isEmpty && json.isNotEmpty) {
      try {
        resolvedSellerName = _deepScanForName(json.cast<String, dynamic>());
      } catch (_) {}
    }

    Seller parsedSeller = Seller.fromJson(sellerMap);
    if ((parsedSeller.name).trim().isEmpty) {
      parsedSeller = parsedSeller.copyWith(
        name: resolvedSellerName.isNotEmpty ? resolvedSellerName : '알 수 없음',
      );
    }

    // 좋아요/즐겨찾기/조회수
    final int likes = (json['likes'] is num)
        ? (json['likes'] as num).toInt()
        : int.tryParse('${json['likes'] ?? 0}') ?? 0;
    final int views = (json['views'] is num)
        ? (json['views'] as num).toInt()
        : int.tryParse('${json['views'] ?? 0}') ?? 0;
    final bool isLiked = json['isLiked'] == true;
    final bool isFavorited =
        json['isFavorited'] == true || json['isFavorited'] == 1;
    int favoriteCount = 0;
    int? asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) {
        return int.tryParse(v.replaceAll(RegExp(r'[, ]'), ''));
      }
      return null;
    }

    favoriteCount =
        asInt(json['favoriteCount']) ?? asInt(json['favCount']) ?? 0;
    if (favoriteCount < 0) favoriteCount = 0;

    return Product(
      id: (json['id'] ??
              json['productId'] ??
              json['uuid'] ??
              json['postId'] ??
              'unknown')
          .toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      price: priceInt,
      priceWon: priceWonInt,
      description: (json['description'] ?? '').toString(),
      imageUrls: imgs,
      createdAt: parseCreatedAt(json['createdAt']),
      seller: parsedSeller,
      location: parseLatLng(json['location']),
      category: (json['category'] != null) ? json['category'].toString() : null,
      images: json['images'] != null ? List<dynamic>.from(json['images']) : [],
      locationText: locText,
      likes: likes,
      views: views,
      isLiked: isLiked,
      isFavorited: isFavorited,
      favoriteCount: favoriteCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'priceWon': priceWon,
        'description': description,
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'seller': seller.toJson(),
        'location': {'lat': location.lat, 'lng': location.lng},
        'category': category,
        'images': images ?? [],
        'locationText': locationText,
        'likes': likes,
        'views': views,
        'isLiked': isLiked,
        'isFavorited': isFavorited,
        'favoriteCount': favoriteCount,
      };
}

// 홈 화면용 Map 변환
extension ProductMap on Product {
  Map<String, dynamic> toMapForHome() {
    final imageUrl = (imageUrls.isNotEmpty)
        ? imageUrls.first
        : 'https://via.placeholder.com/150?text=No+Image';
    final locText = locationText?.trim();
    final sellerLoc = seller.locationName.trim();
    final locationForList = (locText != null && locText.isNotEmpty)
        ? locText
        : (sellerLoc.isNotEmpty ? sellerLoc : '위치 정보 없음');

    return {
      'id': id,
      'title': title,
      'location': locationForList,
      'time': _formatTime(createdAt),
      'likes': likes,
      'views': views,
      'price': price, // 숫자 유지 (UI에서 포맷팅)
      'priceWon': priceWon ?? price, // 서버가 주면 함께 제공
      'isLiked': isLiked,
      'imageUrls': imageUrls,
      'thumbnailUrl': imageUrl,
      'locationText': locationText,
      'seller': seller.toJson(),
    };
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// 더미 상품 데이터 (HomePage에서 사용)
final demoProduct = Product(
  id: 'p-001',
  title: 'Willson 농구공 팝니다!',
  price: 25000,
  priceWon: 25000,
  description:
      '모델명: NCAA Replica Game Ball\n크기: Size 7\n소재: 합성가죽\n신제품가: 4만원 초반',
  imageUrls: const [
    'https://cdn.pixabay.com/photo/2017/09/07/09/58/basketball-2724391_1280.png',
  ],
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  seller: const Seller(
    id: 'seller1',
    name: '판매자',
    avatarUrl:
        'https://raw.githubusercontent.com/flutter/website/master/src/_assets/image/flutter-lockup-bg.jpg',
    locationName: '서울 강남구 역삼동',
    rating: 3.4,
  ),
  location: const LatLng(lat: 37.500613, lng: 127.036431),
  category: '스포츠',
  images: const [],
  likes: 1,
  views: 5,
  isLiked: true,
  isFavorited: true,
  favoriteCount: 1,
  locationText: '서울 강남구 역삼동',
);
