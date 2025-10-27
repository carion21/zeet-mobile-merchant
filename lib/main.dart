// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:merchant/core/constants/themes.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/providers/theme_provider.dart';

void main() {
  // Assurer que l'initialisation des widgets est complète
  WidgetsFlutterBinding.ensureInitialized();

  // Définir l'orientation de l'application
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Lancer l'application avec ProviderScope pour Riverpod
  runApp(
    const ProviderScope(
      child: MyApp(initialRoute: Routes.home),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ToastificationWrapper(
      child: MaterialApp(
        // Utiliser la même clé de navigation globale pour toute l'application
        navigatorKey: Routes.navigatorKey,
        title: 'ZEET Merchant',
        // Configuration des thèmes
        theme: AppTheme.lightTheme(context),
        darkTheme: AppTheme.darkTheme(context),
        themeMode: themeMode,
        // Configuration des routes
        initialRoute: initialRoute,
        onGenerateRoute: Routes.onGenerateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
