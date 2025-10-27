// lib/core/network/api_error.dart
class ApiError implements Exception {
  final String message;
  final int? status;
  ApiError(this.message, {this.status});
  @override
  String toString() => 'ApiError($status): $message';
}

String readError(dynamic e) {
  if (e is ApiError) return e.message;
  return '요청 처리 중 오류가 발생했습니다.';
}
