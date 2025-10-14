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
  final int price;
  final List<String> imageUrls;
  final DateTime createdAt;
  final Seller seller;
  final LatLng location;
  final String? category;
  final List<dynamic>? images; // Web: XFile, Mobile: File

  // 🔹 홈 화면용 필드

  int likes;
  int views;
  bool isLiked;

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
    this.likes = 0,
    this.views = 0,
    this.isLiked = false,
  });

  String? get mainImage => imageUrls.isNotEmpty ? imageUrls.first : null;

  Product copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    List<String>? imageUrls,
    DateTime? createdAt,
    Seller? seller,
    LatLng? location,
    String? category,
    List<dynamic>? images,
    int? likes,
    int? views,
    bool? isLiked,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      seller: seller ?? this.seller,
      location: location ?? this.location,
      category: category ?? this.category,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // 이미지 처리
    final imgs = (json['imageUrls'] as List?)
            ?.where((e) => e != null)
            .map((e) => e.toString())
            .toList(growable: false) ??
        (json['thumbnail'] != null ? [json['thumbnail'].toString()] : const []);

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

    return Product(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      price: (json['price'] is num)
          ? (json['price'] as num).toInt()
          : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      description: (json['description'] ?? '').toString(),
      imageUrls: imgs,
      createdAt: parseCreatedAt(json['createdAt']),
      seller: Seller.fromJson(
          (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {}),
      location: parseLatLng(json['location']),
      category: (json['category'] != null) ? json['category'].toString() : null,
      images: json['images'] != null ? List<dynamic>.from(json['images']) : [],
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'description': description,
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'seller': seller.toJson(),
        'location': {'lat': location.lat, 'lng': location.lng},
        'category': category,
        'images': images ?? [],
        'likes': likes,
        'views': views,
        'isLiked': isLiked,
      };
}

// 🔹 홈 화면용 Map 변환 확장
extension ProductMap on Product {
  Map<String, dynamic> toMapForHome() {
    final imageUrl = (imageUrls.isNotEmpty)
        ? imageUrls.first
        : 'https://via.placeholder.com/150?text=No+Image';
    final locationName =
        seller.locationName.isNotEmpty ? seller.locationName : '위치 정보 없음';
    return {
      'id': id,
      'title': title,
      'location': locationName,
      'time': _formatTime(createdAt),
      'likes': likes,
      'views': views,
      'price': '${price}원',
      'isLiked': isLiked,
      'imageUrls': imageUrls,
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
