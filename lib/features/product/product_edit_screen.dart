import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/post.dart';
import '../../api_service.dart';
import 'package:kumeong_store/core/theme.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

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
    final p = widget.initialProduct;
    if (p != null) {
      _titleCtrl.text = p.title;
      _priceCtrl.text = p.price.toString();
      _descCtrl.text = p.description ?? '';
      _tags.addAll(p.category?.split(',') ?? []);
      if (p.imageUrls.isNotEmpty) _images.addAll(p.imageUrls);
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _images.add(x));
  }

  /// Web/Mobile 공용 이미지 + 데이터 업로드
  Future<Map<String, dynamic>?> createProductWithImages(
      Map<String, dynamic> data, List<dynamic> images, String token) async {
    final uri = Uri.parse('$baseUrl/products');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = data['title'];
    request.fields['price'] = data['price'].toString();
    if (data['description'] != null)
      request.fields['description'] = data['description'];
    if (data['category'] != null) request.fields['category'] = data['category'];

    for (var img in images) {
      if (kIsWeb && img is XFile) {
        final bytes = await img.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: img.name,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      } else if (!kIsWeb && img is File) {
        final stream = http.ByteStream(img.openRead());
        final length = await img.length();
        final multipartFile = http.MultipartFile(
          'images',
          stream,
          length,
          filename: img.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) return body;
      } else {
        debugPrint('❌ 이미지 등록 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ 이미지 등록 예외: $e');
    }
    return null;
  }

  /// 상품 등록
  Future<void> createProduct(String token) async {
    final productData = {
      'title': _titleCtrl.text.trim(),
      'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category': _tags.isEmpty ? null : _tags.join(','),
      'location': {'name': _locationCtrl.text.trim()},
    };

    final result = await createProductWithImages(productData, _images, token);
    if (result != null) {
      debugPrint('✅ 상품 등록 성공');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('상품이 등록되었습니다!')));
      final newProduct = Product.fromJson(result);
      if (mounted) context.pop(newProduct); // 홈 화면으로 새 상품 반환
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('상품 등록 실패')));
    }
  }

  /// 상품 수정
  Future<void> updateProduct(String token) async {
    if (widget.initialProduct == null) return;

    final productData = {
      'title': _titleCtrl.text.trim(),
      'price': int.tryParse(_priceCtrl.text.trim()) ?? 0,
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category': _tags.isEmpty ? null : _tags.join(','),
      'location': {'name': _locationCtrl.text.trim()},
    };

    final result = await updateProductApi(widget.productId, productData, token);
    if (result != null) {
      debugPrint('✅ 상품 수정 성공');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('상품 수정 완료!')));
      final updatedProduct = Product.fromJson(result);
      if (mounted) context.pop(updatedProduct); // 홈 화면으로 수정 상품 반환
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('상품 수정 실패')));
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목과 가격을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    String? token;
    if (kIsWeb) {
      token = html.window.localStorage['accessToken'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('accessToken');
    }

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      setState(() => _isLoading = false);
      context.go('/login');
      return;
    }

    try {
      if (widget.initialProduct == null) {
        await createProduct(token);
      } else {
        await updateProduct(token);
      }
    } catch (e) {
      debugPrint('❌ 상품 등록/수정 예외: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
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
        title: Text(isEditing ? '상품 수정' : '상품 등록',
            style: TextStyle(color: cs.onPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop(); // 새 Product가 없으면 그냥 뒤로
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
                _buildTextField(_priceCtrl, '원', cs, ext,
                    keyboardType: TextInputType.number),
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
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
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
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
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

  Widget _buildLabel(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface));
  }

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
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(t, style: TextStyle(color: cs.onSurface)),
                backgroundColor: ext.accentSoft.withAlpha(50),
                shape: StadiumBorder(side: BorderSide(color: ext.accentSoft)),
                deleteIcon:
                    Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
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
