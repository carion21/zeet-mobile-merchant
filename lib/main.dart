// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';
import 'package:merchant/core/constants/themes.dart';
import 'package:merchant/services/fcm_service.dart';
import 'package:merchant/services/incoming_order_dispatcher.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/providers/theme_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';

void main() async {
  // Assurer que l'initialisation des widgets est complète
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la locale française pour les dates
  await initializeDateFormatting('fr_FR', null);

  // Initialiser le service de tokens (SharedPreferences)
  await TokenService.instance.init();

  // Firebase — requis avant runApp pour que le handler background puisse
  // reinitialiser Firebase dans son propre isolate.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Non fatal en dev local si google-services.json est absent.
    debugPrint('[main] Firebase init failed: $e');
  }

  // Définir l'orientation de l'application
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Si un token existe deja, on saute le splash et on va direct au home.
  final hasTokens = await TokenService.instance.hasTokens();
  final initialRoute = hasTokens ? Routes.home : Routes.login;

  runApp(
    ProviderScope(
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Redirect global vers login si la session expire (refresh 401 echoue).
    ApiClient.onSessionExpired = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Routes.navigateAndRemoveAll(Routes.login);
      });
    };

    // Init FCM apres la premiere frame (le NavigatorState doit exister pour
    // pouvoir pusher l'IncomingOrderScreen depuis un cold-start notif tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.instance.init(
        onDataMessage: (data) async {
          // Routage unifie : foreground, tap-from-background, cold-start.
          IncomingOrderDispatcher.handleRaw(ref, data);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone 11 Pro
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
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
            initialRoute: widget.initialRoute,
            onGenerateRoute: Routes.onGenerateRoute,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}
