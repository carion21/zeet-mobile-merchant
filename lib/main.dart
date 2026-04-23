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
import 'package:merchant/services/overlay_service.dart';
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

          // Auto-refresh des vues quand une transition de commande arrive —
          // sans ca l'app restait avec des donnees stale tant que l'user ne
          // faisait pas un pull-to-refresh manuel. Cible tous les events
          // order.* (created/updated/cancelled/delivered/otp.updated/…)
          // et le group orders.group. On logue les erreurs au lieu de les
          // avaler : sans log on ne peut pas diagnostiquer un refresh qui
          // echoue (cold-start, session expiree, network flaky).
          if (type.startsWith('order.') || type == 'new_order' ||
              type == 'orders.group') {
            try {
              ref.read(ordersListProvider.notifier).refresh();
            } catch (e) {
              debugPrint('[FCM.refresh] ordersList failed: $e');
            }
            try {
              ref.read(dashboardProvider.notifier).refresh();
            } catch (e) {
              debugPrint('[FCM.refresh] dashboard failed: $e');
            }
            // Si l'ecran OrderDetailsScreen est ouvert sur la commande qui
            // vient de transitionner (rider picked_up / delivered / annulation
            // admin), on recharge le detail sans attendre un pull-to-refresh.
            // Sinon l'user voit un statut stale tant qu'il reste sur la vue.
            // Avec orderDetailProvider en .family, chaque commande a son
            // notifier dedie : pas de race entre deux FCM simultanes.
            try {
              final orderIdRaw =
                  data['order_id'] ?? data['entity_id'] ?? data['id'];
              final orderId = orderIdRaw is int
                  ? orderIdRaw
                  : int.tryParse(orderIdRaw?.toString() ?? '');
              if (orderId != null) {
                ref
                    .read(orderDetailProvider(orderId).notifier)
                    .load(orderId);
              } else {
                debugPrint(
                  '[FCM.refresh] orderDetail skipped: no order_id in '
                  'payload (type=$type, keys=${data.keys.toList()})',
                );
              }
            } catch (e) {
              debugPrint('[FCM.refresh] orderDetail failed: $e');
            }
            // Wallet : le solde est credite cote backend quand une commande
            // est livree. Recharger le balance evite d'afficher un montant
            // obsolete si l'user ouvre le wallet juste apres.
            try {
              ref.read(walletProvider.notifier).loadBalance();
            } catch (e) {
              debugPrint('[FCM.refresh] wallet failed: $e');
            }
          }

          // Auto-refresh liste tickets sur support.* (message/mention/status/
          // ticket_opened) : le badge "non-lu" et l'ordre de la liste changent
          // des que le backend pousse une nouvelle activite sur un ticket.
          // Contract §4.2-4.5.
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
