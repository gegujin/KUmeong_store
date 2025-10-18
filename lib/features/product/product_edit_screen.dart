// lib/features/product/product_edit_screen.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/post.dart';
import '../../api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:kumeong_store/utils/storage.dart';
import 'package:kumeong_store/core/theme.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen(
      {super.key, required this.productId, this.initialProduct});
  final String productId;
  final Product? initialProduct;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  static const int _maxTags = 8;
  static const int _maxImages = 10;
  String? _userId;
  String? _token;

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<dynamic> _images = [];
  final List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    final p = widget.initialProduct;
    if (p != null) {
      _titleCtrl.text = p.title?.toString() ?? '';
      _priceCtrl.text = p.price?.toString() ?? '';
      _descCtrl.text = p.description?.toString() ?? '';

      final categoryStr = p.category?.toString() ?? '';
      _tags.addAll(categoryStr.isEmpty ? [] : categoryStr.split(','));

      if (p.imageUrls.isNotEmpty) _images.addAll(p.imageUrls);

      _locationCtrl.text = p.location?.toString() ?? '';
    }
  }

  Future<void> _loadUserId() async {
    _token = await TokenStorage.getToken();
    if (_token != null && _token!.isNotEmpty) {
      final payload = Jwt.parseJwt(_token!);
      _userId = payload['sub']?.toString() ?? '';
      debugPrint('Loaded userId: $_userId');
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _images.add(x));
  }

  Future<Map<String, dynamic>?> createProductWithImagesSafe(
    Map<String, dynamic> data,
    List<dynamic> images,
    String token, {
    bool isUpdate = false,
    String? productId,
  }) async {
    final uri = isUpdate
        ? Uri.parse('$baseUrl/products/$productId')
        : Uri.parse('$baseUrl/products');

    final request = http.MultipartRequest(isUpdate ? 'PUT' : 'POST', uri);
    request.headers['Authorization'] =
        'Bearer ${token.replaceAll('\n', '').trim()}';

    // -----------------------------
    // 필수/선택 필드 안전 변환
    // -----------------------------
    final title = (data['title']?.toString().trim() ?? '');
    if (title.isEmpty || title.length > 100) {
      debugPrint('❌ title validation failed: "$title"');
      return null;
    }

    final priceWon = data['priceWon'] is int
        ? data['priceWon'] as int
        : int.tryParse(
                data['priceWon']?.toString().replaceAll(',', '') ?? '') ??
            -1;
    if (priceWon < 0) {
      debugPrint('❌ priceWon validation failed: $priceWon');
      return null;
    }

    final description = (data['description']?.toString().trim());
    final category = (data['category']?.toString().trim());
    final locationName = (data['location']?.toString().trim());

    // -----------------------------
// 서버 전송 필드 설정
// -----------------------------
    request.fields['title'] = title;
    request.fields['priceWon'] = priceWon.toString();

// description은 항상 fields로 전송
    if (data['description'] != null &&
        data['description'].toString().isNotEmpty) {
      request.fields['description'] = data['description']!.toString();
    }

    if (category != null && category.isNotEmpty)
      request.fields['category'] = category;
    if (locationName != null && locationName.isNotEmpty)
      request.fields['location'] = locationName;

    // -----------------------------
    // 이미지 첨부
    // -----------------------------
    for (final image in images) {
      try {
        if (kIsWeb && image is XFile) {
          final bytes = await image.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: image.name,
            contentType: MediaType('image', 'jpeg'),
          ));
        } else if (!kIsWeb && image is File) {
          if (kIsWeb && image is XFile) {
            final bytes = await image.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: image.path.split('/').last,
              contentType: MediaType('image', 'jpeg'),
            ));
          } else if (!kIsWeb && image is File) {
            final stream = http.ByteStream(image.openRead());
            final length = await image.length();
            request.files.add(http.MultipartFile(
              'images',
              stream,
              length,
              filename: image.path.split('/').last,
              contentType: MediaType('image', 'jpeg'),
            ));
          }
        }
      } catch (e) {
        debugPrint('❌ 이미지 첨부 실패: $e');
      }
    }

    // -----------------------------
    // 요청 전송
    // -----------------------------
    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ 상품 등록/수정 성공');
        final body = jsonDecode(responseBody);
        return (body['data'] ?? body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ 서버 validation 실패: $responseBody');
        return null;
      }
    } catch (e, st) {
      debugPrint('💥 상품 등록 예외: $e\n$st');
      return null;
    }
  }

// -----------------------------
// _submitSafe() 최종 안전 버전
// -----------------------------
  Future<void> _submitSafe() async {
    final title = _titleCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();

    if (title.isEmpty || priceText.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제목과 가격을 반드시 입력해야 합니다.')));
      }
      return;
    }

    if (title.length > 100) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제목은 100자 이하로 입력해야 합니다.')));
      }
      return;
    }

    final priceWon = int.tryParse(priceText.replaceAll(',', ''));
    if (priceWon == null || priceWon < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('가격은 0 이상의 정수여야 합니다.')));
      }
      return;
    }

    if (_userId == null || _token == null) await _loadUserId();
    if (_token == null || _token!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        context.go('/');
      }
      return;
    }

    setState(() => _isLoading = true);

    final productData = {
      'title': title,
      'priceWon': priceWon,
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      if (_tags.isNotEmpty) 'category': _tags.join(','),
      if (_locationCtrl.text.trim().isNotEmpty)
        'location': _locationCtrl.text.trim(),
    };

    Map<String, dynamic>? result;
    if (widget.initialProduct == null) {
      result = await createProductWithImagesSafe(productData, _images, _token!);
    } else {
      result = await createProductWithImagesSafe(
        productData,
        _images,
        _token!,
        isUpdate: true,
        productId: widget.productId,
      );
    }

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(widget.initialProduct == null ? '상품 등록 완료' : '상품 수정 완료')));
        final product = Product.fromJson(result);
        context.pop(product);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('상품 등록/수정 실패')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
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
        title: Text(isEditing ? '상품 수정' : '상품 등록',
            style: TextStyle(color: cs.onPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(cs, ext),
                const SizedBox(height: 24),
                _buildLabel('제목', cs),
                const SizedBox(height: 4),
                _buildTextField(_titleCtrl, '제목 작성', cs, ext),
                const SizedBox(height: 16),
                _buildLabel('가격', cs),
                const SizedBox(height: 4),
                _buildTextField(_priceCtrl, '원', cs, ext,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildLabel('상세설명', cs),
                const SizedBox(height: 4),
                _buildTextField(_descCtrl, '제품 설명', cs, ext, maxLines: 6),
                const SizedBox(height: 16),
                _buildLabel('거래 위치', cs),
                const SizedBox(height: 4),
                _buildTextField(_locationCtrl, '예: 서울 강남구 역삼동', cs, ext),
                const SizedBox(height: 32),
                _buildLabel('태그', cs),
                const SizedBox(height: 8),
                _buildTagSelector(cs, ext),
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
          onPressed: _submitSafe,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
          child:
              Text(isEditing ? '수정하기' : '등록하기', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ColorScheme cs) => Text(text,
      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface));

  Widget _buildTextField(TextEditingController controller, String hintText,
      ColorScheme cs, KuColors ext,
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
            borderSide: BorderSide(color: ext.accentSoft)),
        enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: ext.accentSoft)),
        focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: cs.primary, width: 2)),
        isDense: true,
      ),
      style: TextStyle(color: cs.onSurface),
    );
  }

  Widget _buildImagePicker(ColorScheme cs, KuColors ext) {
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
                                    if (snapshot.connectionState ==
                                        ConnectionState.done) {
                                      if (snapshot.hasError)
                                        return const Icon(Icons.error);
                                      return Image.memory(snapshot.data!,
                                          fit: BoxFit.cover);
                                    }
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2));
                                  },
                                )
                              : Image.network(img.toString(),
                                  fit: BoxFit.cover))
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
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 20, color: Colors.white),
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
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.add, size: 36, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('${_images.length}/$_maxImages',
            style: TextStyle(fontSize: 12, color: cs.onSurface)),
      ],
    );
  }

  Widget _buildTagSelector(ColorScheme cs, KuColors ext) {
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이미 선택한 태그예요.')));
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
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(t),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => setState(() => _tags.remove(t)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CategoryDialog 그대로 사용
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
                title: Text('$mainCat - 소분류 선택',
                    style: TextStyle(color: cs.onSurface)),
                children: categories[mainCat]!
                    .map((subCat) => SimpleDialogOption(
                          child: Text(subCat,
                              style: TextStyle(color: cs.onSurface)),
                          onPressed: () =>
                              Navigator.pop(context, '$mainCat > $subCat'),
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
