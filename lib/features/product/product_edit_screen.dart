//C:\Users\82105\KU-meong Store\lib\features\product\product_edit_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:jwt_decode/jwt_decode.dart';

import 'package:kumeong_store/core/network/http_client.dart'; // HttpX
import 'package:kumeong_store/core/theme.dart';
import '../../models/post.dart';

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

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final String productId;
  final Product? initialProduct;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  static const int _maxTags = 8;
  static const int _maxImages = 10;
  String? _userId;

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _locationCtrl = TextEditingController();

  final List<dynamic> _images = []; // Web: XFile, Mobile: File
  final List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    final p = widget.initialProduct;
    if (p != null) {
      _titleCtrl.text = p.title;
      _priceCtrl.text = p.price.toString();
      _descCtrl.text = p.description ?? '';
      _tags.addAll(p.category?.split(',') ?? []);
      if (p.imageUrls.isNotEmpty) _images.addAll(p.imageUrls);
    }
  }

  /// Web/Mobile 공용: 로그인 토큰에서 userId 추출
  Future<void> _loadUserId() async {
    final sp = await SharedPreferences.getInstance();
    // 우리가 저장하는 표준: session.v1(JSON) { accessToken, me? }
    final raw = sp.getString('session.v1');
    String? token;
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw);
        if (j is Map) {
          token = (j['accessToken'] ?? j['token']) as String?;
          // 이미 me가 있으면 우선 사용
          final me = j['me'];
          if (me is Map && me['id'] != null) {
            _userId = me['id'].toString();
            debugPrint('💬 Loaded userId from session.me: $_userId');
            return;
          }
        }
      } catch (_) {}
    }

    // me가 없으면 JWT에서 추출(백엔드 클레임 이름에 따라 보강)
    if (token != null && token.isNotEmpty) {
      try {
        final payload = Jwt.parseJwt(token);
        _userId = (payload['id'] ?? payload['sub'] ?? payload['userId'])?.toString();
        debugPrint('💬 Loaded userId from JWT: $_userId');
      } catch (e) {
        debugPrint('❌ JWT decode 실패: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _images.add(x));
  }

  /// Web/Mobile 공용 이미지 + 데이터 업로드 (ownerId 포함)
  Future<Map<String, dynamic>?> createProductWithImages(
    Map<String, dynamic> data,
    List<dynamic> images,
    String _token, // <- 시그니처 유지 (내부에선 HttpX가 SharedPreferences의 토큰을 씀)
  ) async {
    // 1) 필드(문자열만 허용) 정규화
    final fields = <String, String>{
      'title': (data['title'] ?? '').toString(),
      'price': (data['price'] ?? 0).toString(),
      if (data['description'] != null) 'description': data['description'].toString(),
      if (data['category'] != null) 'category': data['category'].toString(),
      if (data['location'] != null)
        'location':
            data['location'] is String ? data['location'] as String : jsonEncode(data['location']),
      if (data['sellerId'] != null) 'sellerId': data['sellerId'].toString(),
    };

    // 2) 파일 배열 구성 (XFile / File 지원)
    final files = <http.MultipartFile>[];
    for (final img in images) {
      try {
        if (img is XFile) {
          final bytes = await img.readAsBytes();
          files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else if (img is File) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        } else if (img is String) {
          // 기존 URL 문자열이면 서버 스펙에 따라 별도 필드로 넘겨야 할 수 있음.
          // 필요 시:
          // fields.putIfAbsent('existingImageUrls', () => jsonEncode([img]));
        }
      } catch (e) {
        debugPrint('이미지 준비 실패: $e');
      }
    }

    // 3) 공통 클라이언트 사용 (하드코딩 baseUrl 제거)
    final resp = await HttpX.multipart(
      '/products',
      method: 'POST',
      withAuth: true, // SharedPreferences의 token 자동 주입
      fields: fields,
      files: files.isEmpty ? null : files,
    );

    // 4) 서버 응답 통일 처리 (data 래핑/비래핑 모두 수용)
    final map = (resp['data'] ?? resp);
    return map is Map<String, dynamic> ? map : null;
  }

  /// 상품 등록
  Future<void> createProduct(String token) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보가 없습니다. 로그인 후 다시 시도해주세요.')),
      );
      return;
    }

    final productData = {
      'title': _titleCtrl.text.trim(),
      'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category': _tags.isEmpty ? null : _tags.join(','),
      'location': jsonEncode({'name': _locationCtrl.text.trim()}), // 문자열 필드화
      // ⚠️ 보통 서버가 토큰으로 seller를 식별하므로 sellerId 전송이 불필요할 수 있음
      // 필요하면 아래를 유지:
      // 'sellerId': _userId,
    };

    // 파일 배열 구성
    final files = <http.MultipartFile>[];
    for (final img in _images) {
      try {
        if (img is XFile) {
          final bytes = await img.readAsBytes();
          files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else if (img is File) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        } else if (img is String) {
          // 서버가 기존 URL을 그대로 유지하도록 하고 싶다면, images 대신 별도 필드 사용 필요
          // 여기서는 무시하거나, server 스펙에 맞춰 'existingImageUrls' 등으로 전송
        }
      } catch (e) {
        debugPrint('이미지 준비 실패: $e');
      }
    }

    // HttpX.multipart 사용 (토큰은 SharedPrefs에서 자동 주입되므로 withAuth: true)
    final resp = await HttpX.multipart(
      '/products',
      method: 'POST',
      withAuth: true,
      fields: productData.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      files: files.isEmpty ? null : files,
    );

    // ✅ resp에서 data를 추출해서 Product로 매핑
    final data = (resp['data'] ?? resp) as Map<String, dynamic>;
    final newProduct = Product.fromJson(data);

    debugPrint('✅ 상품 등록 성공');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상품이 등록되었습니다!')),
    );
    context.pop(newProduct);
  }

  /// 상품 수정
  Future<void> updateProduct(String token) async {
    if (widget.initialProduct == null) return;

    final productData = {
      'title': _titleCtrl.text.trim(),
      'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category': _tags.isEmpty ? null : _tags.join(','),
      'location': jsonEncode({'name': _locationCtrl.text.trim()}), // 문자열 필드화
    };

    final files = <http.MultipartFile>[];
    for (final img in _images) {
      try {
        if (img is XFile) {
          final bytes = await img.readAsBytes();
          files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else if (img is File) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        }
      } catch (e) {
        debugPrint('이미지 준비 실패: $e');
      }
    }

    final resp = await HttpX.multipart(
      '/products/${widget.productId}',
      method: 'PUT',
      withAuth: true,
      fields: productData.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      files: files.isEmpty ? null : files,
    );

    // ⛳ 여기가 중요: resp 루트가 아니라 resp['data']가 실제 Product인 경우가 대부분
    final data = (resp['data'] ?? resp) as Map<String, dynamic>;
    final updatedProduct = Product.fromJson(data);

    debugPrint('✅ 상품 수정 성공');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상품 수정 완료!')),
    );
    context.pop(updatedProduct);
  }

  /// _submit() 수정: sellerId 자동 포함 + 로그인/라우팅 안전 처리
  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목과 가격을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 토큰 읽기 (SharedPreferences만 사용)
      String? token;
      final prefs = await SharedPreferences.getInstance();
      // 표준 저장 형태(session.v1 JSON) 우선
      final raw = prefs.getString('session.v1');
      if (raw != null && raw.isNotEmpty) {
        try {
          final j = jsonDecode(raw);
          if (j is Map) {
            token = (j['accessToken'] ?? j['token']) as String?;
          }
        } catch (_) {}
      }
      // 레거시 키 호환
      token ??= prefs.getString('accessToken');

      // 🔹 로그인 상태 체크
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        context.go('/'); // 로그인 화면 이동
        return;
      }

      // 🔹 JWT에서 userId 추출
      if (_userId == null) {
        final payload = Jwt.parseJwt(token);
        _userId = payload['id']?.toString();
      }

      // 🔹 상품 등록 / 수정 분기
      if (widget.initialProduct == null) {
        await createProduct(token); // 🔹 상품 등록
      } else {
        await updateProduct(token); // 🔹 상품 수정
      }
    } catch (e) {
      debugPrint('❌ 상품 등록/수정 예외: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<KuColors>()!;
    final isEditing = widget.initialProduct != null;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: Text(isEditing ? '상품 수정' : '상품 등록', style: TextStyle(color: cs.onPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(context, cs, ext),
                const SizedBox(height: 24),
                _buildLabel(context, '제목'),
                const SizedBox(height: 4),
                _buildTextField(_titleCtrl, '제목 작성', cs, ext),
                const SizedBox(height: 16),
                _buildLabel(context, '가격'),
                const SizedBox(height: 4),
                _buildTextField(_priceCtrl, '원', cs, ext, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildLabel(context, '상세설명'),
                const SizedBox(height: 4),
                _buildTextField(_descCtrl, '제품 설명, 상세설명', cs, ext, maxLines: 6),
                const SizedBox(height: 16),
                _buildLabel(context, '거래 위치'),
                const SizedBox(height: 4),
                _buildTextField(_locationCtrl, '예: 서울 강남구 역삼동', cs, ext),
                const SizedBox(height: 32),
                _buildLabel(context, '태그'),
                const SizedBox(height: 8),
                _buildTagSelector(context, cs, ext),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: _submit,
          child: Text(isEditing ? '수정하기' : '등록하기',
              style: TextStyle(fontSize: 18, color: cs.onPrimary)),
        ),
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context, ColorScheme cs, KuColors ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._images.map((img) {
              return Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border.all(color: ext.accentSoft),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? (img is XFile
                              ? FutureBuilder<Uint8List>(
                                  future: img.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done) {
                                      if (snapshot.hasError) return const Icon(Icons.error);
                                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                    }
                                    return const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                )
                              : Image.network(img.toString(), fit: BoxFit.cover))
                          : Image.file(img as File, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.remove(img)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
            if (_images.length < _maxImages)
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: ext.accentSoft),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 36, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('${_images.length}/$_maxImages', style: TextStyle(fontSize: 12, color: cs.onSurface)),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface));
  }

  Widget _buildTextField(
      TextEditingController controller, String hintText, ColorScheme cs, KuColors ext,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ext.accentSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: ext.accentSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        isDense: true,
      ),
      style: TextStyle(color: cs.onSurface),
    );
  }

  Widget _buildTagSelector(BuildContext context, ColorScheme cs, KuColors ext) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              if (_tags.length >= _maxTags) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('태그는 최대 $_maxTags개까지 선택할 수 있어요.')),
                );
                return;
              }
              final tag = await showDialog<String>(
                  context: context, builder: (_) => const CategoryDialog());
              if (tag == null || _tags.contains(tag)) {
                if (_tags.contains(tag)) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('이미 선택한 태그예요.')));
                }
                return;
              }
              setState(() => _tags.add(tag));
            },
            child: const Text('필터 +'),
          ),
          const SizedBox(width: 8),
          ..._tags.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(t, style: TextStyle(color: cs.onSurface)),
                backgroundColor: ext.accentSoft.withAlpha(50),
                shape: StadiumBorder(side: BorderSide(color: ext.accentSoft)),
                deleteIcon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                onDeleted: () => setState(() => _tags.remove(t)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryDialog extends StatelessWidget {
  const CategoryDialog({super.key});

  static const Map<String, List<String>> categories = {
    '디지털기기': ['스마트폰', '태블릿/노트북', '데스크탑/모니터', '카메라/촬영장비', '게임기기', '웨어러블/주변기기'],
    '가전제품': ['TV/모니터', '냉장고', '세탁기/청소기', '에어컨/공기청정기', '주방가전', '뷰티가전'],
    '의류/패션': ['남성의류', '여성의류', '아동의류', '신발', '가방', '액세서리'],
    '가구/인테리어': ['침대/매트리스', '책상/의자', '소파', '수납/테이블', '조명/인테리어 소품'],
    '생활/주방': ['주방용품', '청소/세탁용품', '욕실/수납용품', '생활잡화', '기타 생활소품'],
    '유아/아동': ['유아의류', '장난감/유모차/카시트', '육아용품', '침구/가구'],
    '취미/게임/음반': ['게임', '운동용품', '음반/LP', '악기', '아웃도어용품'],
    '도서/문구': ['소설/에세이', '참고서/전공서적', '만화책', '문구/사무용품', '기타 도서류'],
    '반려동물': ['사료/간식', '장난감/용품', '이동장/하우스', '의류/목줄', '기타 반려용품'],
    '기타 중고물품': ['티켓/상품권', '피규어/프라모델', '공구/작업도구', '수집품', '기타'],
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SimpleDialog(
      backgroundColor: cs.surface,
      title: Text('대분류 선택', style: TextStyle(color: cs.onSurface)),
      children: categories.keys.map((mainCat) {
        return SimpleDialogOption(
          child: Text(mainCat, style: TextStyle(color: cs.onSurface)),
          onPressed: () async {
            final sub = await showDialog<String>(
              context: context,
              builder: (_) => SimpleDialog(
                backgroundColor: cs.surface,
                title: Text('$mainCat - 소분류 선택', style: TextStyle(color: cs.onSurface)),
                children: categories[mainCat]!
                    .map((subCat) => SimpleDialogOption(
                          child: Text(subCat, style: TextStyle(color: cs.onSurface)),
                          onPressed: () => Navigator.pop(context, '$mainCat > $subCat'),
                        ))
                    .toList(),
              ),
            );
            if (sub != null && context.mounted) Navigator.pop(context, sub);
          },
        );
      }).toList(),
    );
  }
}
