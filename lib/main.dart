// lib/main.dart
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:toastification/toastification.dart';
import 'package:merchant/core/constants/themes.dart';
import 'package:merchant/core/widgets/orders/active_orders_badge_overlay.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/ticket_provider.dart';
import 'package:merchant/providers/notifications_provider.dart';
import 'package:merchant/providers/wallet_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/services/deep_link_handler.dart';
import 'package:merchant/services/fcm_service.dart';
import 'package:merchant/services/incoming_order_grouper.dart';
import 'package:merchant/services/local_notification_service.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/order_status_dispatcher.dart';
import 'package:merchant/services/overlay_service.dart';
import 'package:merchant/services/partner_dispatcher.dart';
import 'package:merchant/services/payout_dispatcher.dart';
import 'package:merchant/services/rating_dispatcher.dart';
import 'package:merchant/services/wallet_dispatcher.dart';
import 'package:merchant/providers/theme_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';

void main() async {
  // Assurer que l'initialisation des widgets est complète
  WidgetsFlutterBinding.ensureInitialized();

  // Budget ImageCache adapte a la cible partner (tablette Android cheap,
  // ~2-4 Go RAM). Skill zeet-performance-budget §6.
  PaintingBinding.instance.imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 50 * 1024 * 1024; // 50 MB

  // Initialiser la locale française pour les dates
  await initializeDateFormatting('fr_FR', null);

  // Workaround sqlite3_flutter_libs : sur certains Android (Samsung
  // notamment), DynamicLibrary.open('libsqlite3.so') echoue et retombe sur
  // /data/data/<pkg>/lib/libsqlite3.so qui n'existe pas quand
  // extractNativeLibs=false. Precharger la lib cote JVM avant tout acces DB
  // (y compris depuis les background isolates utilises par
  // NativeDatabase.createInBackground).
  if (Platform.isAndroid) {
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    } catch (e) {
      debugPrint('[main] sqlite3 workaround failed: $e');
    }
  }

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

  // Route initiale : toujours Splash. La SplashScreen se charge :
  //   - de l'animation branding (1200ms minimum),
  //   - du `checkAuthStatus()` parallèle,
  //   - du routage vers login / permissions / root selon l'etat.
  // Voir `lib/screens/splash/index.dart`.
  runApp(
    const ProviderScope(
      child: MyApp(initialRoute: Routes.splash),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Redirect global vers login si la session expire (refresh 401 echoue).
    ApiClient.onSessionExpired = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Routes.navigateAndRemoveAll(Routes.login);
      });
    };

    // Observer cycle de vie pour : (1) fermer la bulle quand l'app revient
    // au foreground, (2) afficher la bulle quand l'app passe en background
    // si une nouvelle commande est en attente.
    WidgetsBinding.instance.addObserver(this);

    // Init overlay listener : tap sur la bulle ramene l'app au front.
    OverlayService.instance.initListener(
      onTap: () {
        debugPrint('[main] overlay tapped, app brought to front');
      },
    );

    // Init FCM apres la premiere frame (le NavigatorState doit exister pour
    // pouvoir pusher l'IncomingOrderScreen depuis un cold-start notif tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Boot le SyncManager (ecoute connectivite + replay queue).
      ref.read(syncManagerProvider);

      // Phase 4.2 — Cold-start deep-link pour les types non-critical :
      // si l'app a ete lancee depuis un tap sur une notif locale (FSI ou
      // summary inbox) AVANT que FCM n'ait fini son init, on parse le
      // launch payload et on route immediatement. JAMAIS via home (skill §7).
      // Note : pour `order.created` le routage passe par le dispatcher
      // existant via DeepLinkHandler.handle → IncomingOrderDispatcher.
      _handleColdStartDeepLink();

      FcmService.instance.init(
        onDataMessage: (data) async {
          // Si l'app est en background quand la commande arrive, afficher la
          // bulle flottante (en plus de la FullScreenIntent). La bulle sera
          // masquee quand l'app reviendra au foreground.
          final lifecycle =
              WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
          // Contract §2.1 : `type_value` est la cle canonique de routage
          // (alias de `type`). On lit type_value en priorite, type en fallback.
          final String type = (data['type_value']?.toString().isNotEmpty ?? false)
              ? data['type_value'].toString()
              : data['type']?.toString() ?? '';
          if (lifecycle != AppLifecycleState.resumed) {
            if (type == 'order.created' || type == 'new_order') {
              await OverlayService.instance.incrementBubble(
                title: data['title']?.toString() ?? 'Nouvelle commande',
              );
            }
          }
          // Routage unifie : foreground, tap-from-background, cold-start.
          // Delegue au DeepLinkHandler qui map `order.created` vers
          // IncomingOrderDispatcher, `order.*` vers OrderDetailsScreen,
          // `orders.group` vers la liste filtree (Phase 4), et `support.*`
          // vers TicketDetailScreen (contract §4.2-4.5).
          DeepLinkHandler.handle(ref, data);

          // Auto-refresh des vues — chaque dispatcher est responsable d'un
          // domaine, retourne true s'il a consomme le payload. Cascade
          // d'essais : on s'arrete au premier match (les types backend
          // sont disjoints). Resout le bug "l'UI ne se rafraichit pas
          // automatiquement quand le core envoie une transition de statut".
          // Cf. BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4 et
          // AUDITS/partner-audit-complet-2026-05-07.md section C.
          if (OrderStatusDispatcher.handleRaw(ref, data)) {
            // ok : order.*
          } else if (WalletDispatcher.handleRaw(ref, data)) {
            // ok : wallet.credited
          } else if (PayoutDispatcher.handleRaw(ref, data)) {
            // ok : payout.*
          } else if (PartnerDispatcher.handleRaw(ref, data)) {
            // ok : partner.* / menu_item.*
          } else if (RatingDispatcher.handleRaw(ref, data)) {
            // ok : rating.received
          }

          // Auto-refresh liste tickets sur support.* (message/mention/status/
          // ticket_opened) : le badge "non-lu" et l'ordre de la liste changent
          // des que le backend pousse une nouvelle activite sur un ticket.
          // Contract §4.2-4.5. (Pas de SupportDispatcher dedie pour l'instant
          // car la logique reste simple : liste + detail si ouvert.)
          if (type.startsWith('support.')) {
            try {
              ref.read(ticketsListProvider.notifier).refresh();
            } catch (e) {
              debugPrint('[FCM.refresh] ticketsList failed: $e');
            }
            // Si TicketDetailScreen est deja ouvert sur l'id concerne, son
            // provider family doit etre invalide : sans ca, un nouveau message
            // agent arrive en FCM mais la timeline reste stale.
            try {
              final ticketId = (data['entity_id'] ??
                      data['ticket_id'] ??
                      data['id'])
                  ?.toString();
              if (ticketId != null && ticketId.isNotEmpty) {
                ref.read(ticketDetailProvider(ticketId).notifier).refresh();
              }
            } catch (e) {
              debugPrint('[FCM.refresh] ticketDetail failed: $e');
            }
          }

          // Badge cloche : tout FCM entrant represente potentiellement une
          // nouvelle entree dans l'inbox notifications (backend cree une row
          // notifications en parallele du push). Invalider le compteur pour
          // que le badge header se mette a jour sans attendre une navigation.
          try {
            ref.read(unreadCountProvider.notifier).refresh();
          } catch (e) {
            debugPrint('[FCM.refresh] unreadCount failed: $e');
          }
        },
      );
    });
  }

  /// Cold-start : si l'app a ete lancee en tapant une notification locale
  /// (LocalNotifService FSI ou summary), on recupere le payload stocke
  /// et on route. FcmService.getInitialMessage gere deja le cas FCM pur,
  /// mais pas les notifs locales qu'on a generees soi-meme.
  Future<void> _handleColdStartDeepLink() async {
    try {
      final Map<String, dynamic>? launchPayload =
          await LocalNotificationService.getLaunchPayload();
      if (launchPayload == null || launchPayload.isEmpty) return;

      final String type = launchPayload['type']?.toString() ?? '';
      debugPrint('[main] cold-start deep-link: type=$type');

      // Reset du grouper : l'utilisateur a consulte la notification, la
      // window est consommee.
      if (type == 'orders.group' || type.startsWith('order.')) {
        await IncomingOrderGrouper.instance.reset();
      }

      // Delai de 800ms pour laisser le RootScaffold se mount (sinon le
      // rootTabProvider n'est pas encore dans le widget tree et les
      // navigations vers "/root" retombent sur splash qui re-route).
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      DeepLinkHandler.handle(ref, launchPayload);
    } catch (e) {
      debugPrint('[main] cold-start deep-link failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Hygiene : libere les 3 StreamSubscriptions FCM
    // (onMessage / onMessageOpenedApp / onTokenRefresh) a la fermeture
    // de l'app. Sans pratique l'OS detruit l'isolate de toute facon, mais
    // ca permet une recuperation propre si un test/test integration
    // recree l'arbre de widgets.
    // ignore: unawaited_futures
    FcmService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Des que l'app revient au premier plan, masquer la bulle flottante :
    // le partner a les commandes a l'ecran, la bulle perd son sens.
    if (state == AppLifecycleState.resumed) {
      OverlayService.instance.hideBubble();
      // Phase 4.3 : l'utilisateur consulte l'app, on considere la window
      // grouping comme consommee — la summary inbox disparait + reset.
      IncomingOrderGrouper.instance.reset();

      // Refresh automatique a la reprise : apres un fond prolonge,
      // les listes et compteurs sont stales (statut transitionne cote
      // backend pendant que l'app etait endormie, nouveaux ordres rates
      // par Doze, silent push perdus). Non-bloquant, swallow les erreurs.
      try {
        ref.read(ordersListProvider.notifier).refresh();
      } catch (_) {}
      try {
        ref.read(dashboardProvider.notifier).refresh();
      } catch (_) {}
      try {
        ref.read(profileProvider.notifier).loadProfile();
      } catch (_) {}
      try {
        ref.read(walletProvider.notifier).loadBalance();
      } catch (_) {}
      try {
        ref.read(ticketsListProvider.notifier).refresh();
      } catch (_) {}
      try {
        ref.read(unreadCountProvider.notifier).refresh();
      } catch (_) {}
    }
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
            // Overlay global : badge "commandes en cours" visible partout
            // hors Accueil / Commandes (anti-perte POS, Zeigarnik).
            builder: (BuildContext context, Widget? child) {
              if (child == null) return const SizedBox.shrink();
              return Stack(
                children: <Widget>[
                  child,
                  const ActiveOrdersBadgeOverlay(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
