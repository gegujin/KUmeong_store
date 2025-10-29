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

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      locationName: (json['locationName'] ?? '').toString(),
      rating:
          (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
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

  /// UI/서버 혼용 대응
  final int price; // UI에서 사용
  final int? priceWon; // 서버 정식 필드

  final List<String> imageUrls;
  final DateTime createdAt;
  final Seller seller;
  final LatLng location;

  /// 서버/클라이언트가 내려주는 텍스트 위치
  final String? locationText;

  final String? category;
  final List<dynamic>? images; // Web: XFile, Mobile: File

  final bool isFavorited; // ✅ 추가
  final int favoriteCount; // ✅ 추가

  // 🔹 홈 화면용 필드
  int likes;
  int views;
  bool isLiked;
  int get priceKRW => priceWon ?? price;

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
    this.isFavorited = false, // ✅ 기본값
    this.favoriteCount = 0, // ✅ 기본값
    this.locationText,
    this.category,
    this.images,
    this.likes = 0,
    this.views = 0,
    this.isLiked = false,
  });

  String? get mainImage =>
      imageUrls.firstWhere((e) => e.trim().isNotEmpty, orElse: () => '');

  Product copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    int? priceWon, // ✅ 추가
    List<String>? imageUrls,
    DateTime? createdAt,
    Seller? seller,
    LatLng? location,
    String? category,
    List<dynamic>? images,
    String? locationText, // ✅ 추가
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
      priceWon: priceWon ?? this.priceWon, // ✅ 반영
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      seller: seller ?? this.seller,
      location: location ?? this.location,
      category: category ?? this.category,
      images: images ?? this.images,
      locationText: locationText ?? this.locationText, // ✅ 반영
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      favoriteCount: favoriteCount ?? this.favoriteCount,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // 이미지 처리 (우선순위: imageUrls → images[].url → thumbnail)
    List<String> imgs = (json['imageUrls'] as List?)
            ?.where((e) => e != null)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    if (imgs.isEmpty) {
      final imgsRel = (json['images'] as List?)
              ?.where((e) => e is Map && (e as Map)['url'] != null)
              .map((e) => ((e as Map)['url']).toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      if (imgsRel.isNotEmpty) imgs = imgsRel;
    }

    if (imgs.isEmpty && json['thumbnail'] != null) {
      final thumb = json['thumbnail'].toString();
      if (thumb.trim().isNotEmpty) imgs = [thumb];
    }

    // createdAt 처리
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

    // location 처리
    LatLng parseLatLng(dynamic v) {
      if (v is Map<String, dynamic>) {
        final lat = (v['lat'] is num) ? (v['lat'] as num).toDouble() : 0.0;
        final lng = (v['lng'] is num) ? (v['lng'] as num).toDouble() : 0.0;
        return LatLng(lat: lat, lng: lng);
      } else if (v is String && v.isNotEmpty) {
        return const LatLng(lat: 37.5665, lng: 126.9780);
      }
      return const LatLng(lat: 0, lng: 0);
    }

    // ✅ 위치 텍스트: locationText → location → seller.locationName
    final sellerMap =
        (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sellerLocName = (sellerMap['locationName'] ?? '').toString();
    final locText = (json['locationText'] ??
            json['location'] ??
            (sellerLocName.isNotEmpty ? sellerLocName : null))
        ?.toString();

    // ✅ 가격: price / priceWon 모두 수용
    final priceAny = json['price'] ?? json['priceWon'] ?? 0;
    final priceInt = (priceAny is num)
        ? priceAny.toInt()
        : int.tryParse(priceAny.toString().replaceAll(RegExp(r'[, ]'), '')) ??
            0;

    final priceWonAny = json['priceWon'];
    final priceWonInt = (priceWonAny is num)
        ? priceWonAny.toInt()
        : int.tryParse('${priceWonAny ?? ''}');

    return Product(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      price: priceInt, // ✅ 정수화
      priceWon: priceWonInt, // ✅ 보존
      description: (json['description'] ?? '').toString(),
      imageUrls: imgs,
      createdAt: parseCreatedAt(json['createdAt']),
      seller: Seller.fromJson(sellerMap),
      location: parseLatLng(json['location']),
      category: (json['category'] != null) ? json['category'].toString() : null,
      images: json['images'] != null ? List<dynamic>.from(json['images']) : [],
      locationText: locText, // ✅ 반영
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isFavorited:
          json['isFavorited'] == true || json['isFavorited'] == 1, // ✅ 서버 응답 반영
      // ✅ favoriteCount: 서버가 number|string|null 어떤 형태로 와도 안전 파싱
      favoriteCount: (() {
        final fc = json['favoriteCount'];
        final alt = json['favCount'];
        int? asInt(dynamic v) {
          if (v is num) return v.toInt();
          if (v is String && v.isNotEmpty) {
            return int.tryParse(v.replaceAll(RegExp(r'[, ]'), ''));
          }
          return null;
        }

        final parsed = asInt(fc) ?? asInt(alt) ?? 0;
        return parsed < 0 ? 0 : parsed; // 음수 방지
      })(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'priceWon': priceWon, // ✅ 추가
        'description': description,
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'seller': seller.toJson(),
        'location': {'lat': location.lat, 'lng': location.lng},
        'locationText': locationText, // ✅ 추가
        'category': category,
        'images': images ?? [],
        'likes': likes,
        'views': views,
        'isLiked': isLiked,
        'isFavorited': isFavorited, // ✅
        'favoriteCount': favoriteCount, // ✅
      };
}

// 🔹 홈 화면용 Map 변환 확장
extension ProductMap on Product {
  Map<String, dynamic> toMapForHome() {
    final imageUrl = (imageUrls.isNotEmpty)
        ? imageUrls.first
        : 'https://via.placeholder.com/150?text=No+Image';

    // ✅ 위치 우선순위: locationText → seller.locationName → 기본값
    final locationName = (locationText != null && locationText!.isNotEmpty)
        ? locationText!
        : (seller.locationName.isNotEmpty ? seller.locationName : '위치 정보 없음');

    return {
      'id': id,
      'title': title,
      'location': locationName, // ← 여기로 “모시래”가 들어옴
      'time': _formatTime(createdAt),
      'likes': likes,
      'views': views,
      'price': price, // ✅ 숫자로 유지 (라벨링은 UI에서)
      'priceWon': priceWon ?? price, // ✅ 서버/클라 호환
      'isLiked': isLiked,
      'imageUrls': imageUrls,
      'thumbnailUrl': imageUrl, // (옵션) 썸네일 키도 같이 제공
      'locationText': locationText, // (옵션) alias
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

// 더미 상품 데이터
final demoProduct = Product(
  id: 'p-001',
  title: 'Willson 농구공 팝니다!',
  price: 25000,
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
  images: [],
  likes: 1,
  views: 5,
  isLiked: true,
);
