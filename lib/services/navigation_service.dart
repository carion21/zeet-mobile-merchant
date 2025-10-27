// lib/services/navigation_service.dart
import 'package:flutter/material.dart';

class Routes {
  // GlobalKey unique pour le Navigator
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Définition des routes statiques
  static const String home = '/';

  // Définition des constructeurs de widgets pour chaque route
  static final Map<String, WidgetBuilder> routes = {
    home: (context) => const Scaffold(
      body: Center(
        child: Text('Merchant App - Home'),
      ),
    ),
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

    // Si la route n'existe pas, retourner à l'écran d'accueil
    if (routeBuilder == null) {
      // Return a default route if the requested route is not found
      return MaterialPageRoute(
        builder: routes[home] ?? ((context) => const Scaffold(body: Center(child: Text('Route non trouvée')))),
        settings: const RouteSettings(name: home),
      );
    }

    // Création d'une route MaterialPageRoute standard
    return MaterialPageRoute(
      builder: routeBuilder,
      settings: settings,
    );
  }
}
