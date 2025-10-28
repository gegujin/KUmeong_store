// lib/features/delivery/ku_delivery_gate.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // web

import 'package:kumeong_store/core/router/route_names.dart' as R;

class KuDeliveryGate extends StatefulWidget {
  const KuDeliveryGate({super.key});
  @override
  State<KuDeliveryGate> createState() => _KuDeliveryGateState();
}

class _KuDeliveryGateState extends State<KuDeliveryGate> {
  static const String _base = 'http://127.0.0.1:3000/api/v1'; // 에뮬레이터면 10.0.2.2

  // ── 토큰 로딩
  Future<String?> _loadToken() async {
    const keys = ['accessToken', 'access_token', 'token'];
    if (kIsWeb) {
      for (final k in keys) {
        final v = html.window.localStorage[k];
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    } else {
      final prefs = await SharedPreferences.getInstance();
      for (final k in keys) {
        final v = prefs.getString(k);
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }
  }

  // ── 캐시 읽기/쓰기
  Future<void> _cacheDeliveryMembership({
    required bool isMember,
    String? transport,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('delivery.isMember', isMember);
    if (transport != null && transport.isNotEmpty) {
      await prefs.setString('delivery.transport', transport);
    }
    if (kIsWeb) {
      html.window.localStorage['delivery.isMember'] =
          isMember ? 'true' : 'false';
      if (transport != null && transport.isNotEmpty) {
        html.window.localStorage['delivery.transport'] = transport;
      }
    }
  }

  Future<({bool? isMember, String? transport})> _readCachedMembership() async {
    bool? cachedMember;
    String? transport;

    if (kIsWeb) {
      final v = html.window.localStorage['delivery.isMember'];
      if (v != null) cachedMember = (v == 'true');
      transport = html.window.localStorage['delivery.transport'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('delivery.isMember')) {
        cachedMember = prefs.getBool('delivery.isMember');
      }
      transport = prefs.getString('delivery.transport');
    }
    return (isMember: cachedMember, transport: transport);
  }

  // ── 서버 멤버십 확인
  Future<({bool ok, bool isMember, String? transport})>
      _fetchMembership() async {
    final token = await _loadToken();
    if (token == null) {
      return (ok: false, isMember: false, transport: null);
    }

    try {
      final resp = await http.get(
        Uri.parse('$_base/delivery/membership'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return (ok: false, isMember: false, transport: null);
      }

      final body = jsonDecode(resp.body);
      final data = body is Map ? (body['data'] ?? body) : {};
      final ok = (data['ok'] == true) || (body is Map && body['ok'] == true);
      final isMember = (data['isMember'] == true) ||
          (body is Map && body['isMember'] == true);
      final transport = (data['transport'] ?? body['transport'])?.toString();

      return (ok: ok, isMember: isMember, transport: transport);
    } catch (_) {
      return (ok: false, isMember: false, transport: null);
    }
  }

  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    // 1) 캐시 기반 빠른 분기
    final cached = await _readCachedMembership();
    if (mounted && cached.isMember != null) {
      context.goNamed(
        cached.isMember == true
            ? R.RouteNames.kuDeliveryFeed
            : R.RouteNames.kuDeliverySignup,
      );
    }

    // 2) 서버 정답으로 분기 확정 + 캐시 갱신
    final result = await _fetchMembership();
    await _cacheDeliveryMembership(
        isMember: result.isMember, transport: result.transport);

    if (!mounted) return;
    context.goNamed(
      result.isMember
          ? R.RouteNames.kuDeliveryFeed
          : R.RouteNames.kuDeliverySignup,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
