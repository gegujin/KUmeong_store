// lib/core/utils/email.dart
/// 앞뒤 공백 제거 + 소문자 통일
String normalizeEmail(String input) => input.trim().toLowerCase();

/// 한국 학교 이메일(@*.ac.kr) 형태인지 단순 체크
bool looksLikeAcKr(String email) => RegExp(r'@.+\.ac\.kr$').hasMatch(email);
