// lib/core/network/connectivity_providers.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// List<ConnectivityResult> -> 단일 ConnectivityResult로 압축
/// 규칙:
/// - none이 포함되면 => none
/// - wifi가 있으면 => wifi
/// - mobile이 있으면 => mobile
/// - 그 외엔 첫 요소 반환(ethernet/bluetooth 등)
ConnectivityResult _collapse(List<ConnectivityResult> results) {
  if (results.isEmpty) return ConnectivityResult.none;
  if (results.contains(ConnectivityResult.none)) return ConnectivityResult.none;
  if (results.contains(ConnectivityResult.wifi)) return ConnectivityResult.wifi;
  if (results.contains(ConnectivityResult.mobile))
    return ConnectivityResult.mobile;
  return results.first;
}

/// 초기 상태(checkConnectivity) 한 번 내보내고,
/// 이후 onConnectivityChanged 스트림을 구독해서 단일값으로 흘려보내는 Provider
final connectivityStreamProvider =
    StreamProvider<ConnectivityResult>((ref) async* {
  final connectivity = Connectivity();

  // 1) 초기값
  final initialList = await connectivity.checkConnectivity();
  yield _collapse(initialList);

  // 2) 변경 스트림
  yield* connectivity.onConnectivityChanged.map(_collapse);
});

/// 오프라인 여부 헬퍼
bool isOffline(ConnectivityResult result) => result == ConnectivityResult.none;
