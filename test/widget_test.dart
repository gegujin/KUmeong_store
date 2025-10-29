import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumeong_store/main.dart'; // 패키지명 수정

void main() {
  testWidgets('앱이 로드되고 AppBar 타이틀이 보이는지 확인', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('상품 상세페이지'), findsOneWidget);
  });

  testWidgets('거래 진행하기 버튼이 존재하는지 확인', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('거래 진행하기'), findsOneWidget);
  });
}
