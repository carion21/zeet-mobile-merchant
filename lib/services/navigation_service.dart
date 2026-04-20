// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:merchant/screens/splash/index.dart';
import 'package:merchant/screens/auth/login/index.dart';
import 'package:merchant/screens/order_details/index.dart';
import 'package:merchant/screens/menu/index.dart';
import 'package:merchant/screens/opening_hours/index.dart';
import 'package:merchant/screens/payouts/index.dart';
import 'package:merchant/screens/permissions/index.dart';
import 'package:merchant/screens/product_categories/index.dart';
import 'package:merchant/screens/products/index.dart';
import 'package:merchant/screens/root/index.dart';
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
  static const String root = '/root';
  static const String home = '/home';
  static const String login = '/login';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String menu = '/menu';
  static const String permissions = '/permissions';
  static const String productCategories = '/product-categories';
  static const String products = '/products';
  static const String payouts = '/payouts';
  static const String openingHours = '/opening-hours';

  // Définition des constructeurs de widgets pour chaque route.
  // Les routes `home`, `orders`, `profile` pointent TOUTES sur
  // [RootScaffold] pour préserver la cohérence de navigation (tout
  // accès passe par le bottom bar) tout en restant compatible avec
  // les anciens `Routes.navigateTo(Routes.home/...)` historiques.
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    root: (context) => const RootScaffold(),
    home: (context) => const RootScaffold(),
    orders: (context) => const RootScaffold(),
    profile: (context) => const RootScaffold(),
    menu: (context) => const MenuScreen(),
    permissions: (context) => const PermissionsScreen(),
    productCategories: (context) => const ProductCategoriesScreen(),
    products: (context) => const ProductsScreen(),
    payouts: (context) => const PayoutsScreen(),
    openingHours: (context) => const OpeningHoursScreen(),
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

  static Future<T?> pushOrderDetails<T>(int orderId) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => OrderDetailsScreen(orderId: orderId)),
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
        (_) => Scaffold(
          appBar: AppBar(title: const Text('Page introuvable')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wrong_location_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'La route "${settings.name}" n\'existe pas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => navigateAndRemoveAll(home),
                  child: const Text('Retour a l\'accueil'),
                ),
              ],
            ),
          ),
        ),
        settings: settings,
      );
    }

    return _buildRoute(routeBuilder, settings: settings);
  }
}
