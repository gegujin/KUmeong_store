// lib/core/router/app_router.dart  (파일명은 네가 쓰는 경로에 맞춰 사용)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;

// ===== Screens =====
import 'package:kumeong_store/features/auth/login_screen.dart' show LoginPage;
import 'package:kumeong_store/features/auth/school_sign_screen.dart'
    show SchoolSignUpPage;
import 'package:kumeong_store/features/auth/id_find_screen.dart'
    show IdFindPage;
import 'package:kumeong_store/features/auth/password_find_screen.dart'
    show PasswordFindPage;

import 'package:kumeong_store/features/home/home_screen.dart' show HomePage;
import 'package:kumeong_store/features/home/alarm_screen.dart' show AlarmPage;

import 'package:kumeong_store/features/product/product_detail_screen.dart';
import 'package:kumeong_store/features/product/product_edit_screen.dart';
import 'package:kumeong_store/features/product/product_list_screen.dart'
    show CategoryPage;

import 'package:kumeong_store/features/chat/chat_list_screen.dart';
import 'package:kumeong_store/features/chat/chat_room_screen.dart'
    show ChatScreen;

import 'package:kumeong_store/features/mypage/mypage_screen.dart' show MyPage;
import 'package:kumeong_store/features/mypage/point_screen.dart' show PointPage;
import 'package:kumeong_store/features/mypage/heart_screen.dart' show HeartPage;
import 'package:kumeong_store/features/mypage/buy_screen.dart' show BuyPage;
import 'package:kumeong_store/features/mypage/sell_screen.dart' show SellPage;
import 'package:kumeong_store/features/mypage/recent_post_screen.dart'
    show RecentPostPage;

import 'package:kumeong_store/features/friend/friend_screen.dart'
    show FriendScreen;
import 'package:kumeong_store/features/friend/friend_requests_screen.dart'
    show FriendRequestsScreen; // ✅ 추가

import 'package:kumeong_store/features/trade/trade_confirm_screen.dart';
import 'package:kumeong_store/features/trade/payment_method_screen.dart';
import 'package:kumeong_store/features/trade/secure_payment_screen.dart';

import 'package:kumeong_store/features/delivery/ku_delivery_alert_screen.dart'
    show KuDeliveryAlertScreen;
import 'package:kumeong_store/features/delivery/delivery_status_screen.dart'
    show DeliveryStatusScreen, DeliveryStatusArgs;
import 'package:kumeong_store/features/delivery/ku_delivery_list_screen.dart'
    show KuDeliveryFeedScreen;
import 'package:kumeong_store/features/delivery/ku_delivery_detail_screen.dart'
    show KuDeliveryDetailScreen, KuDeliveryDetailArgs;
import 'package:kumeong_store/features/delivery/ku_delivery_signup_screen.dart'
    show KuDeliverySignupPage;

// Settings
import 'package:kumeong_store/features/settings/settings_screen.dart'
    show SettingsScreen;
import 'package:kumeong_store/features/settings/payment_methods_screen.dart'
    show PaymentMethodsPage;
import 'package:kumeong_store/features/settings/refund_account_screen.dart'
    show RefundAccountPage;
import 'package:kumeong_store/features/settings/faq_screen.dart' show FaqPage;
import 'package:kumeong_store/features/settings/bug_report_screen.dart'
    show BugReportPage;
import 'package:kumeong_store/features/settings/app_info_screen.dart'
    show AppInfoPage;

import 'package:kumeong_store/models/post.dart' show Product;
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart';

// ──────────────────────────────────────────────────────────────
// Navigator Keys
// ──────────────────────────────────────────────────────────────
final _rootKey = GlobalKey<NavigatorState>();
final _homeKey = GlobalKey<NavigatorState>();
final _chatKey = GlobalKey<NavigatorState>();
final _favKey = GlobalKey<NavigatorState>();
final _mypageKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootKey,
  initialLocation: '/', // 로그인
  routes: [
    // ========== 인증(Auth) (하단바 숨김)
    GoRoute(
        path: '/',
        name: R.RouteNames.login,
        builder: (context, state) => const LoginPage()),
    GoRoute(
        path: '/auth/school-signup',
        name: R.RouteNames.schoolSignUp,
        builder: (context, state) => const SchoolSignUpPage()),
    GoRoute(
        path: '/auth/id-find',
        name: R.RouteNames.idFind,
        builder: (context, state) => const IdFindPage()),
    GoRoute(
        path: '/auth/password-find',
        name: R.RouteNames.passwordFind,
        builder: (context, state) => const PasswordFindPage()),

    // ========== 탭(IndexedStack)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: AppBottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(i,
                initialLocation: i == navigationShell.currentIndex),
          ),
        );
      },
      branches: [
        // ───────── 0) HOME
        StatefulShellBranch(
          navigatorKey: _homeKey,
          routes: [
            GoRoute(
              path: '/home',
              name: R.RouteNames.home,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomePage()),
              routes: [
                GoRoute(
                  path: 'product/:productId',
                  name: R.RouteNames.productDetail,
                  builder: (context, state) {
                    final id = state.pathParameters['productId']!;
                    final extra = state.extra;
                    return ProductDetailScreen(
                      productId: id,
                      initialProduct: extra is Product ? extra : null,
                    );
                  },
                ),
                GoRoute(
                  path: 'edit/:productId',
                  name: R.RouteNames.productEdit,
                  builder: (context, state) {
                    final id = state.pathParameters['productId']!;
                    final extra = state.extra;
                    return ProductEditScreen(
                      productId: id,
                      initialProduct: extra is Product ? extra : null,
                    );
                  },
                ),
                GoRoute(
                    path: 'categories',
                    name: R.RouteNames.categories,
                    builder: (context, state) => const CategoryPage()),
                GoRoute(
                    path: 'alarms',
                    name: R.RouteNames.alarms,
                    builder: (context, state) => const AlarmPage()),
              ],
            ),
          ],
        ),

        // ───────── 1) CHAT
        StatefulShellBranch(
          navigatorKey: _chatKey,
          routes: [
            GoRoute(
              path: '/chat',
              name: R.RouteNames.chat,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ChatListScreen()),
              routes: [
                GoRoute(
                  name: R.RouteNames.chatRoom,
                  path: 'room/:roomId',
                  builder: (context, state) {
                    final roomId = state.pathParameters['roomId']!;
                    final ex = (state.extra as Map?) ?? const {};
                    return ChatScreen(
                      roomId: roomId,
                      partnerName: (ex['partnerName'] as String?) ?? '상대방',
                      isKuDelivery: ex['isKuDelivery'] as bool? ?? false,
                      securePaid: ex['securePaid'] as bool? ?? false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ───────── 2) FAVORITES
        StatefulShellBranch(
          navigatorKey: _favKey,
          routes: [
            GoRoute(
              path: '/favorites',
              name: R.RouteNames.favorites,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HeartPage()),
            ),
          ],
        ),

        // ───────── 3) MYPAGE
        StatefulShellBranch(
          navigatorKey: _mypageKey,
          routes: [
            GoRoute(
              path: '/mypage',
              name: R.RouteNames.mypage,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MyPage()),
              routes: [
                GoRoute(
                    path: 'points',
                    name: R.RouteNames.points,
                    builder: (context, state) => const PointPage()),
                GoRoute(
                    path: 'buy',
                    name: R.RouteNames.buyHistory,
                    builder: (context, state) => const BuyPage()),
                GoRoute(
                    path: 'sell',
                    name: R.RouteNames.sellHistory,
                    builder: (context, state) => const SellPage()),
                GoRoute(
                    path: 'recent',
                    name: R.RouteNames.recentPosts,
                    builder: (context, state) => const RecentPostPage()),

                // ✅ 친구 목록 (meUserId를 state.extra로 전달받음)
                GoRoute(
                  path: 'friends',
                  name: R.RouteNames.friends,
                  builder: (context, state) {
                    // extra 없이 열고, FriendScreen 안에서 sessionProvider로 현재 사용자 ID를 읽도록 권장
                    return const FriendScreen();
                  },
                ),

                // ✅ 친구 요청함 (MyPage 브랜치 하위 경로)
                GoRoute(
                  name: R.RouteNames.friendRequests,
                  path: 'friends/requests',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final meId =
                        extra?['meUserId'] as String? ?? ''; // 👈 전달값 수신
                    return FriendRequestsScreen(meUserId: meId);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ========== 탭 외부(하단바 숨김)
    GoRoute(
      path: '/overlay/chat/room/:roomId',
      name: R.RouteNames.chatRoomOverlay,
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        final ex = (state.extra as Map?) ?? const {};
        return ChatScreen(
          roomId: roomId,
          partnerName: (ex['partnerName'] as String?) ?? '상대방',
          isKuDelivery: ex['isKuDelivery'] as bool? ?? false,
          securePaid: ex['securePaid'] as bool? ?? false,
        );
      },
    ),

    // ── Delivery
    GoRoute(
        path: '/delivery/signup',
        name: R.RouteNames.kuDeliverySignup,
        builder: (context, state) => const KuDeliverySignupPage()),
    GoRoute(
        path: '/delivery/feed',
        name: R.RouteNames.kuDeliveryFeed,
        builder: (context, state) => const KuDeliveryFeedScreen()),
    GoRoute(
      path: '/delivery/detail',
      name: R.RouteNames.kuDeliveryDetail,
      builder: (context, state) =>
          KuDeliveryDetailScreen(args: state.extra as KuDeliveryDetailArgs),
    ),
    GoRoute(
      path: '/delivery/status',
      name: R.RouteNames.deliveryStatus,
      builder: (context, state) =>
          DeliveryStatusScreen(args: state.extra as DeliveryStatusArgs),
    ),
    GoRoute(
        path: '/delivery/alerts',
        name: R.RouteNames.kuDeliveryAlerts,
        builder: (context, state) => const KuDeliveryAlertScreen()),

    // ── Trade
    GoRoute(
      path: '/trade/confirm',
      name: R.RouteNames.tradeConfirm,
      builder: (context, state) {
        final qp = state.uri.queryParameters;
        return TradeConfirmScreen(
            productId: qp['productId'], roomId: qp['roomId']);
      },
    ),
    GoRoute(
      path: '/trade/payment',
      name: R.RouteNames.paymentMethod,
      builder: (context, state) {
        final qp = state.uri.queryParameters;
        bool parseBool(String? v) => (v ?? 'false').toLowerCase() == 'true';
        int? parseInt(String? v) => v == null ? null : int.tryParse(v);
        return PaymentMethodScreen(
          isDelivery: parseBool(qp['delivery']),
          roomId: qp['roomId'] ?? 'room-demo',
          productId: qp['productId'],
          partnerName: qp['partnerName'],
          productTitle: qp['productTitle'],
          price: parseInt(qp['price']),
          imageUrl: qp['imageUrl'],
          categoryTop: qp['categoryTop'],
          categorySub: qp['categorySub'],
          availablePoints: parseInt(qp['availablePoints']),
        );
      },
    ),
    GoRoute(
      path: '/trade/secure/:roomId/:productId',
      name: R.RouteNames.securePay,
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        final productId = state.pathParameters['productId']!;
        final ex = (state.extra is Map) ? (state.extra as Map) : const {};
        T _get<T>(String k, T def) {
          final v = ex[k];
          if (v is T) return v;
          if (T == int && v is String) return int.tryParse(v) as T? ?? def;
          return def;
        }

        return SecurePaymentScreen(
          roomId: roomId,
          productId: productId,
          productTitle: _get<String>('productTitle', '상품 이름'),
          price: _get<int>('price', 0),
          imageUrl: _get<String?>('imageUrl', null),
          categoryTop: _get<String?>('categoryTop', null),
          categorySub: _get<String?>('categorySub', null),
          availablePoints: _get<int>('availablePoints', 0),
          availableMoney: _get<int>('availableMoney', 0),
          defaultAddress:
              _get<String>('defaultAddress', '서울특별시 성동구 왕십리로 00, 101동 1001호'),
          partnerName: _get<String>('partnerName', '판매자1'),
        );
      },
    ),

    // ── Settings overlay (하단바 숨김)
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/settings',
      name: R.RouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'payment-methods',
            name: R.RouteNames.paymentMethods,
            builder: (context, state) => const PaymentMethodsPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'refund-account',
            name: R.RouteNames.refundAccount,
            builder: (context, state) => const RefundAccountPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'faq',
            name: R.RouteNames.faq,
            builder: (context, state) => const FaqPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'bug-report',
            name: R.RouteNames.bugReport,
            builder: (context, state) => const BugReportPage()),
        GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'app-info',
            name: R.RouteNames.appInfo,
            builder: (context, state) => const AppInfoPage()),
      ],
    ),
  ],
);
