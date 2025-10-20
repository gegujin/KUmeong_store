// lib/models/post.dart
import 'latlng.dart';

/// 판매자 정보 모델
class Seller {
  final String id;
  final String name;
  final String avatarUrl; // 프로필 이미지 URL
  final String locationName; // 사람이 읽는 위치명
  final double rating; // 0.0 ~ 5.0

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

  /// 여러 스키마에 대응하는 유연 파서
  factory Seller.fromJson(Map<String, dynamic> json) {
    String _pickNameFlat(Map<String, dynamic> m) {
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

    String _pickNameDeep(Map<String, dynamic> m) {
      final flat = _pickNameFlat(m);
      if (flat.isNotEmpty) return flat;

      for (final parent in [
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
        final v = m[parent];
        if (v is Map<String, dynamic>) {
          final hit = _pickNameFlat(v);
          if (hit.isNotEmpty) return hit;
        }
      }

      // 깊이 2 일반 스캔
      for (final e in m.entries) {
        final v = e.value;
        if (v is Map<String, dynamic>) {
          final hit = _pickNameFlat(v);
          if (hit.isNotEmpty) return hit;
          for (final e2 in v.entries) {
            if (e2.value is Map<String, dynamic>) {
              final hit2 = _pickNameFlat(e2.value as Map<String, dynamic>);
              if (hit2.isNotEmpty) return hit2;
            }
          }
        }
      }
      return '';
    }

    String _pickStringDeep(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
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

    final pickedName = _pickNameDeep(json);
    final avatar =
        _pickStringDeep(json, ['avatarUrl', 'profileImageUrl', 'imageUrl']);
    final locName =
        _pickStringDeep(json, ['locationName', 'regionName', 'addressText']);

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

  /// UI/서버 혼용 대응: price(기본), priceWon(서버 정식 필드가 따로 올 수 있음)
  final int price;
  final int? priceWon;

  final List<String> imageUrls;
  final DateTime createdAt;
  final Seller seller;
  final LatLng location;

  /// 서버/클라이언트에서 내려오는 위치 문자열
  final String? locationText;

  final String? category;

  /// 원본 업로드용 이미지 배열(Web: XFile, Mobile: File 등)
  final List<dynamic>? images;

  // ---- 홈/상세 보조 필드 (mutable) ----
  int likes;
  int views;
  bool isLiked;

  /// 서버와 동기화되는 찜 상태/카운트
  bool isFavorited;
  int favoriteCount;

  Product({
    required this.id,
    required this.title,
    required this.price,
    this.priceWon,
    required this.description,
    required this.imageUrls,
    required this.createdAt,
    required this.seller,
    required this.location,
    this.locationText,
    this.category,
    this.images,
    this.likes = 0,
    this.views = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.favoriteCount = 0,
  });

  /// 대표 이미지(없으면 null)
  String? get mainImage => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// 표기용 원화 가격
  int get priceKRW => priceWon ?? price;

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
    // 이미지 정규화
    final imageUrls = (json['imageUrls'] as List?)
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

    DateTime _parseCreatedAt(dynamic v) {
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

    LatLng _parseLatLng(dynamic v) {
      if (v is Map<String, dynamic>) {
        final lat = (v['lat'] is num) ? (v['lat'] as num).toDouble() : 0.0;
        final lng = (v['lng'] is num) ? (v['lng'] as num).toDouble() : 0.0;
        return LatLng(lat: lat, lng: lng);
      } else if (v is String && v.isNotEmpty) {
        // 문자열 좌표가 올 경우 임시 폴백
        return const LatLng(lat: 37.5665, lng: 126.9780);
      }
      return const LatLng(lat: 0, lng: 0);
    }

    // 판매자
    final sellerMap =
        (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {};

    // 위치 텍스트: locationText → location → seller.locationName
    final sellerLocName = (sellerMap['locationName'] ?? '').toString();
    final locText = (json['locationText'] ??
            json['location'] ??
            (sellerLocName.isNotEmpty ? sellerLocName : null))
        ?.toString();

    // 가격: price / priceWon 안전 파싱
    final priceAny = json['price'] ?? json['priceWon'] ?? 0;
    final priceInt = (priceAny is num)
        ? priceAny.toInt()
        : int.tryParse(priceAny.toString().replaceAll(RegExp(r'[, ]'), '')) ??
            0;

    final priceWonAny = json['priceWon'];
    final priceWonInt = (priceWonAny is num)
        ? priceWonAny.toInt()
        : int.tryParse('${priceWonAny ?? ''}');

    // 찜/조회수/좋아요
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) {
        return int.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
      }
      return 0;
    }

    final favCount = (() {
      final fc = json['favoriteCount'];
      final alt = json['favCount'];
      final parsed = (fc != null ? _asInt(fc) : _asInt(alt));
      return parsed < 0 ? 0 : parsed;
    })();

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
      imageUrls: imageUrls,
      createdAt: _parseCreatedAt(json['createdAt']),
      seller: Seller.fromJson(sellerMap),
      location: _parseLatLng(json['location']),
      category: (json['category'] != null) ? json['category'].toString() : null,
      images: json['images'] != null ? List<dynamic>.from(json['images']) : [],
      locationText: locText,
      likes: _asInt(json['likes']),
      views: _asInt(json['views']),
      isLiked: json['isLiked'] == true,
      isFavorited: json['isFavorited'] == true || json['isFavorited'] == 1,
      favoriteCount: favCount,
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
        'locationText': locationText,
        'category': category,
        'images': images ?? [],
        'likes': likes,
        'views': views,
        'isLiked': isLiked,
        'isFavorited': isFavorited,
        'favoriteCount': favoriteCount,
      };
}

/// 홈 화면 카드용 Map 변환
extension ProductMap on Product {
  Map<String, dynamic> toMapForHome() {
    final imageUrl = (imageUrls.isNotEmpty)
        ? imageUrls.first
        : 'https://via.placeholder.com/150?text=No+Image';

    // 위치 우선순위: locationText → seller.locationName → 기본값
    final locationName = (locationText != null && locationText!.isNotEmpty)
        ? locationText!
        : (seller.locationName.isNotEmpty ? seller.locationName : '위치 정보 없음');

    return {
      'id': id,
      'title': title,
      'location': locationName, // ← Home에서 이 값 표시
      'time': _formatTime(createdAt),
      'likes': likes,
      'views': views,
      'price': price, // 숫자 그대로 (UI에서 포맷팅)
      'priceWon': priceWon ?? price,
      'isLiked': isLiked,
      'isFavorited': isFavorited,
      'favoriteCount': favoriteCount,
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

// 더미 상품 (홈에서 서버 비었을 때 사용 가능)
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
