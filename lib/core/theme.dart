import 'package:flutter/material.dart';

/// === Base (사진 톤에 맞춘 주색) ===
// const Color kuPrimary        = Color(0xFF2E7D57); // 아주 진한 초록(앱바/주 버튼)
// const Color kuPrimaryDark    = Color(0xFF07281D);
// const Color kuPrimaryLight   = Color(0xFF12553E);
const Color kuPrimary = Color(0xFF3B8F68); // 산뜻한 진초록
const Color kuPrimaryDark = Color(0xFF1E5B41); // 차분한 어두운 초록
const Color kuPrimaryLight = Color(0xFF4BAE83); // 밝은 포인트 초록

const Color kuBg = Colors.white; // 배경
const Color kuSurface = Colors.white; // 카드/서피스
const Color kuTextPrimary = Color(0xFF111111); // 본문
const Color kuTextSecondary = Color(0xFF6B7280); // 보조
const Color kuOutline = Color(0xFFCED4DA); // 입력창 테두리

/// === Points (자유롭게 조합해서 사용) ===
const Color kuLime = Color(0xFFB7D63B); // 라임(배지/강조)
const Color kuYellow = Color(0xFFF1C40F); // 노랑(주의/포인트)
const Color kuAccentSoft = Color(0xFFBFD8A6); // 부드러운 연초록(칩/배경)
const Color kuMintSoft = Color(0xFFD2ECEF); // 패널 배경
const Color kuGreenSoft = Color(0xFFDCEFD2); // 패널 배경
const Color kuError = Color(0xFFB00020);
const Color kuSuccess = Color(0xFF1F9254);
const Color kuInfo = Color(0xFF147AD6);

/// 기존 변수명 호환
const Color kuGreen = kuPrimary;
const Color kuDarkGreen = kuPrimaryDark;
const Color kuLightGreen = kuLime;
const Color kuBeige = Color(0xFFF7FAF2);
const Color kuBlack = kuTextPrimary;
// ✅ 레거시 호환용 별칭 추가 (secure_payment_screen.dart에서 사용)
const Color kuAccent = kuAccentSoft;

/// ThemeExtension: 포인트 컬러/배지/태그 등 중앙 통제
@immutable
class KuColors extends ThemeExtension<KuColors> {
  final Color green;
  final Color darkGreen;
  final Color accent;
  final Color badgeBg;
  final Color badgeFg;
  final Color caution; // 경고
  final Color success;
  final Color info;
  final Color accentSoft;
  final Color beigeSoft;
  final Color mintSoft;
  final Color greenSoft;

  const KuColors({
    required this.green,
    required this.darkGreen,
    required this.accent,
    required this.badgeBg,
    required this.badgeFg,
    required this.caution,
    required this.success,
    required this.info,
    required this.accentSoft,
    required this.beigeSoft,
    required this.mintSoft,
    required this.greenSoft,
  });

  @override
  KuColors copyWith({
    Color? green,
    Color? darkGreen,
    Color? accent,
    Color? badgeBg,
    Color? badgeFg,
    Color? caution,
    Color? success,
    Color? info,
    Color? accentSoft,
    Color? beigeSoft,
    Color? mintSoft,
    Color? greenSoft,
  }) {
    return KuColors(
      green: green ?? this.green,
      darkGreen: darkGreen ?? this.darkGreen,
      accent: accent ?? this.accent,
      badgeBg: badgeBg ?? this.badgeBg,
      badgeFg: badgeFg ?? this.badgeFg,
      caution: caution ?? this.caution,
      success: success ?? this.success,
      info: info ?? this.info,
      accentSoft: accentSoft ?? this.accentSoft,
      beigeSoft: beigeSoft ?? this.beigeSoft,
      mintSoft: mintSoft ?? this.mintSoft,
      greenSoft: greenSoft ?? this.greenSoft,
    );
  }

  @override
  KuColors lerp(ThemeExtension<KuColors>? other, double t) {
    if (other is! KuColors) return this;
    return KuColors(
      green: Color.lerp(green, other.green, t)!,
      darkGreen: Color.lerp(darkGreen, other.darkGreen, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      badgeBg: Color.lerp(badgeBg, other.badgeBg, t)!,
      badgeFg: Color.lerp(badgeFg, other.badgeFg, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      beigeSoft: Color.lerp(beigeSoft, other.beigeSoft, t)!,
      mintSoft: Color.lerp(mintSoft, other.mintSoft, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
    );
  }
}

final _r8 = BorderRadius.circular(8);
final _r10 = BorderRadius.circular(10);
final _r12 = BorderRadius.circular(12);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: kuPrimary,
    onPrimary: Colors.white,
    secondary: kuLime,
    onSecondary: Colors.black,
    error: kuError,
    onError: Colors.white,
    background: kuBg,
    onBackground: kuTextPrimary,
    surface: kuSurface,
    onSurface: kuTextPrimary,
    primaryContainer: kuPrimaryLight,
    onPrimaryContainer: Colors.white,
    secondaryContainer: kuAccentSoft,
    onSecondaryContainer: kuTextPrimary,
  ),
  scaffoldBackgroundColor: kuBg,

  // 포인트 팔레트 주입
  extensions: const [
    KuColors(
      green: kuGreen,
      darkGreen: kuDarkGreen,
      accent: kuAccentSoft, // 기본 액센트 컬러
      badgeBg: kuLime,
      badgeFg: Colors.black,
      caution: kuYellow,
      success: kuSuccess,
      info: kuInfo,
      accentSoft: kuAccentSoft,
      beigeSoft: kuBeige,
      mintSoft: kuMintSoft,
      greenSoft: kuGreenSoft,
    ),
  ],

  appBarTheme: const AppBarTheme(
    backgroundColor: kuPrimary,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
    titleTextStyle: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
    iconTheme: IconThemeData(color: Colors.white),
  ),

  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(borderRadius: _r8),
    elevation: 0,
    color: kuSurface,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  ),

  bottomSheetTheme: BottomSheetThemeData(
    shape: RoundedRectangleBorder(borderRadius: _r8),
    backgroundColor: kuSurface,
  ),

  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: _r8),
    backgroundColor: kuSurface,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF7F7F7),
    hintStyle: const TextStyle(color: kuTextSecondary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: _r12,
      borderSide: const BorderSide(color: kuOutline, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: _r12,
      borderSide: const BorderSide(color: kuPrimary, width: 1.6),
    ),
  ),

  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kuPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: _r10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      elevation: 0,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kuPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: _r10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kuPrimary,
      side: const BorderSide(color: kuPrimary, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: _r10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  ),

  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: kuSurface,
    indicatorColor: Color(0x1A0A3A2A),
  ),
  listTileTheme: const ListTileThemeData(
    titleTextStyle: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, color: kuTextPrimary),
    subtitleTextStyle: TextStyle(fontSize: 13, color: kuTextSecondary),
  ),
  dividerTheme:
      const DividerThemeData(color: Color(0xFFE5E7EB), thickness: .9, space: 1),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: kuPrimary,
    contentTextStyle:
        TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
  ),
);
