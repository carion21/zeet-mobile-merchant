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

  // Navigation standard avec animation personnalisée
  static void navigateTo(String routeName) {
    if (navigatorKey.currentState == null) return;

    navigatorKey.currentState!.pushNamed(routeName);
  }

  // Navigation avec paramètres et animation personnalisée
  static Future<T?> push<T>(Widget page) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Navigation spéciale pour l'écran de vérification OTP avec paramètres
  static Future<T?> pushVerifyOtp<T>({
    required String phoneNumber,
    String? fullName,
    required String type,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => VerifyOtpScreen(
          phoneNumber: phoneNumber,
          fullName: fullName,
          type: type,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Navigation vers les détails de commande
  static Future<T?> pushOrderDetails<T>(String orderId) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => OrderDetailsScreen(
          orderId: orderId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Navigation vers les détails d'un plat
  static Future<T?> pushFoodDetails<T>(String foodId) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.push<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FoodDetailsScreen(
          foodId: foodId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Remplacement avec animation
  static void navigateAndReplace(String routeName) {
    if (navigatorKey.currentState == null) return;

    navigatorKey.currentState!.pushReplacementNamed(routeName);
  }

  // Remplacement avec paramètres et animation
  static Future<T?> pushReplacement<T>(Widget page) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.pushReplacement<T, T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Navigation avec effacement de l'historique et animation
  static void navigateAndRemoveAll(String routeName) {
    if (navigatorKey.currentState == null) return;

    navigatorKey.currentState!.pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
  }

  // Effacer tout avec paramètres et animation
  static Future<T?> pushAndRemoveAll<T>(Widget page) {
    if (navigatorKey.currentState == null) return Future.value(null);

    return navigatorKey.currentState!.pushAndRemoveUntil<T>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
          (Route<dynamic> route) => false,
    );
  }

  // Retour avec animation
  static void goBack<T>([T? result]) {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop<T>(result);
    }
  }

  // Génération des routes
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Récupérer le builder pour la route demandée
    final routeBuilder = routes[settings.name];

    // Si la route n'existe pas, retourner à l'écran splash
    if (routeBuilder == null) {
      // Return a default route if the requested route is not found
      return MaterialPageRoute(
        builder: routes[splash] ?? ((context) => const Scaffold(body: Center(child: Text('Route non trouvée')))),
        settings: const RouteSettings(name: splash),
      );
    }

    // Création d'une route MaterialPageRoute standard
    return MaterialPageRoute(
      builder: routeBuilder,
      settings: settings,
    );
  }
}
