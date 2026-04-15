// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:merchant/screens/splash/index.dart';
import 'package:merchant/screens/auth/login/index.dart';
import 'package:merchant/screens/auth/verify_otp/index.dart';
import 'package:merchant/screens/home/index.dart';
import 'package:merchant/screens/orders/index.dart';
import 'package:merchant/screens/order_details/index.dart';
import 'package:merchant/screens/profile/index.dart';
import 'package:merchant/screens/menu/index.dart';
import 'package:merchant/screens/food_details/index.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Service de navigation centralisé de l'app Merchant.
///
/// Toutes les transitions passent par [ZeetPageRoute] (package partagé
/// `zeet_ui`) avec style shared axis horizontal par défaut pour garantir
/// une grammaire cohérente avec client et rider.
///
/// Respect automatique de `MediaQuery.disableAnimations`.
///
/// Voir skills : `zeet-motion-system` §4, `zeet-pos-ergonomics` §2bis.
class Routes {
  // GlobalKey unique pour le Navigator
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Définition des routes statiques
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String menu = '/menu';

  // Définition des constructeurs de widgets pour chaque route
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    home: (context) => const HomeScreen(),
    orders: (context) => const OrdersScreen(),
    profile: (context) => const ProfileScreen(),
    menu: (context) => const MenuScreen(),
  };

  // ─── Helpers ZeetPageRoute ────────────────────────────────────────

  static ZeetPageRoute<T> _buildRoute<T>(
    WidgetBuilder builder, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
    RouteSettings? settings,
  }) {
    return ZeetPageRoute<T>(
      builder: builder,
      style: style,
      settings: settings,
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────

  static void navigateTo(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!.pushNamed(routeName);
  }

  static Future<T?> push<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => page, style: style),
    );
  }

  static Future<T?> pushVerifyOtp<T>({
    required String phoneNumber,
    String? fullName,
    required String type,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => VerifyOtpScreen(
            phoneNumber: phoneNumber,
            fullName: fullName,
            type: type,
          )),
    );
  }

  static Future<T?> pushOrderDetails<T>(int orderId) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => OrderDetailsScreen(orderId: orderId)),
    );
  }

  static Future<T?> pushFoodDetails<T>(String foodId) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => FoodDetailsScreen(foodId: foodId)),
    );
  }

  static void navigateAndReplace(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!.pushReplacementNamed(routeName);
  }

  static Future<T?> pushReplacement<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.pushReplacement<T, T>(
      _buildRoute<T>((_) => page, style: style),
    );
  }

  static void navigateAndRemoveAll(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!
        .pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
  }

  static Future<T?> pushAndRemoveAll<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.pushAndRemoveUntil<T>(
      _buildRoute<T>((_) => page, style: style),
      (Route<dynamic> route) => false,
    );
  }

  static void goBack<T>([T? result]) {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop<T>(result);
    }
  }

  // ─── Génération des routes (MaterialApp.onGenerateRoute) ──────────

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final routeBuilder = routes[settings.name];

    if (routeBuilder == null) {
      return _buildRoute(
        routes[splash] ??
            (_) => const Scaffold(
                  body: Center(child: Text('Route non trouvée')),
                ),
        settings: const RouteSettings(name: splash),
      );
    }

    return _buildRoute(routeBuilder, settings: settings);
  }
}
