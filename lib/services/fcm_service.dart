// FcmService — branche Firebase Cloud Messaging sur l'app partner.
//
// Responsabilites :
//  - Demander la permission notifications (Android 13+)
//  - Recuperer le token FCM et l'injecter dans DeviceTokenManager
//  - Ecouter onTokenRefresh (rotation de token)
//  - Router les messages recus (foreground, tap-from-background, cold-start)
//    vers un callback fourni par l'appelant
//  - En Phase 3 : quand un message arrive alors que l'app est killed ou
//    en background profond, afficher une notification FullScreenIntent
//    via LocalNotificationService (reveille l'ecran + sonne fort).
//
// Background isolate :
//  - Le handler background tourne dans un isolate separe — il ne peut PAS
//    acceder aux providers Riverpod du main isolate, mais il PEUT appeler
//    LocalNotificationService (qui reinit le plugin dans le nouvel isolate).

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/services/device_token_manager.dart';
import 'package:merchant/services/incoming_order_grouper.dart';
import 'package:merchant/services/incoming_ring_bridge.dart';
import 'package:merchant/services/local_notification_service.dart';
import 'package:merchant/services/navigation_service.dart';

/// Signature du callback appele pour dispatcher un payload recu.
typedef FcmDataHandler = Future<void> Function(Map<String, dynamic> data);

/// Handler background top-level obligatoire pour FirebaseMessaging.
/// Affiche une notification FullScreenIntent pour reveiller l'ecran sur
/// les events critiques ("order.created").
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.init();

  final type = message.data['type']?.toString() ?? '';
  debugPrint(
    '[FcmService.bg] received: type=$type entity=${message.data['entity_id']}',
  );

  // Seuls les events critiques meritent un full-screen intent.
  if (type == 'order.created' || type == 'new_order') {
    final data = Map<String, dynamic>.from(message.data);
    // Merge title/body depuis notification:{} si fourni.
    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    final title = (data['title']?.toString().isNotEmpty ?? false)
        ? data['title'].toString()
        : 'Nouvelle commande';
    final body = (data['body']?.toString().isNotEmpty ?? false)
        ? data['body'].toString()
        : 'Appuyez pour voir les details';

    // Grouping Phase 4 : si > 3 notifs en < 2 min, le grouper active la
    // summary. Quel que soit le retour, on pousse la notif individuelle
    // avec groupKey/threadIdentifier (cf. LocalNotifService) pour que
    // le systeme les stacke visuellement. Parse defensif : si le payload
    // est minimaliste, le grouper compte quand meme la nouvelle entree.
    bool grouped = false;
    try {
      final IncomingOrderPayload? parsed =
          IncomingOrderPayload.tryParse(data);
      if (parsed != null) {
        grouped = await IncomingOrderGrouper.instance.onIncomingOrder(parsed);
      }
    } catch (e) {
      debugPrint('[FcmService.bg] grouper failed: $e');
    }

    await LocalNotificationService.showIncomingOrder(
      title: title,
      body: body,
      payloadData: data,
      groupKey: grouped ? kIncomingOrderGroupKey : null,
    );
  }
}

class FcmService {
  static FcmService? _instance;

  FcmDataHandler? _onDataMessage;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;

  FcmService._();

  static FcmService get instance {
    _instance ??= FcmService._();
    return _instance!;
  }

  /// Initialise FCM une seule fois.
  ///
  /// [onDataMessage] est appele a chaque message recu (foreground, tap de
  /// notif, cold-start). L'appelant est responsable de dispatcher vers l'UI.
  /// Initialise les listeners FCM + local notifications + channels.
  ///
  /// Par défaut **ne demande PAS** la permission système (`promptPermission:
  /// false`) — le pre-prompt custom `NotifRationaleSheet` doit être affiché
  /// avant, côté écran d'accueil post-auth. Évite de brûler la chance
  /// iOS (one-shot) au cold-start pré-login.
  ///
  /// Cf. zeet-notification-strategy §8 — "ask in context".
  Future<void> init({
    required FcmDataHandler onDataMessage,
    bool promptPermission = false,
  }) async {
    if (_initialized) {
      _onDataMessage = onDataMessage;
      return;
    }
    _initialized = true;
    _onDataMessage = onDataMessage;

    final messaging = FirebaseMessaging.instance;

    // Declare le handler background (obligatoire AVANT tout autre listener).
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Init LocalNotificationService du main isolate — branche le tap sur
    // notre dispatcher Flutter via le callback onTap.
    await LocalNotificationService.init(
      onTap: (payload) async {
        debugPrint(
          '[FcmService] local notif tapped: type=${payload['type']}',
        );
        await _onDataMessage?.call(payload);
      },
    );

    if (promptPermission) {
      await requestPushPermission();
    }

    // 3. Rotation de token.
    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) async {
      debugPrint(
        '[FcmService] token refreshed: ${token.substring(0, 16)}...',
      );
      DeviceTokenManager.instance.setPushToken(token);
      await DeviceTokenManager.instance.registerCurrentDevice();
    });

    // 4. Messages recus en foreground : dispatch direct (l'ecran Incoming
    // s'affiche sans passer par une notif).
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FcmService] foreground message: type=${message.data['type']}',
      );
      // Cote natif, ZeetFirebaseMessagingService skip le ring quand l'app
      // est deja en foreground pour eviter un double son. Cote Flutter, il
      // faut donc declencher la sonnerie/vibration ici — sinon une nouvelle
      // commande recue app ouverte arrivait en silence jusqu'a ce que
      // IncomingOrderScreen mount son propre player, trop tard pour une
      // cuisine bruyante.
      final String type = message.data['type']?.toString() ?? '';
      if (type == 'order.created' || type == 'new_order') {
        final String title = message.data['title']?.toString()
            ?? message.notification?.title
            ?? 'Nouvelle commande';
        final String body = message.data['body']?.toString()
            ?? message.notification?.body
            ?? 'Appuyez pour voir les details';
        // ignore: unawaited_futures
        IncomingRingBridge.startFake(title: title, body: body);
      }
      _dispatch(message);
    });

    // 5. Tap sur une notif systeme (FCM ou locale) quand l'app etait en
    // background.
    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FcmService] opened from background: type=${message.data['type']}',
      );
      _dispatch(message);
    });

    // 6a. Cold-start depuis un tap FCM (Android system notif).
    //
    // On attend que le Navigator soit pret (poll 50ms, timeout 1200ms)
    // au lieu d'un delay fixe 800ms. Resultat : dispatch des que possible
    // (typiquement < 200ms en warm boot), plutot qu'apres ~1s d'attente
    // qui faisait manquer les premieres secondes de l'alerte POS.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
        '[FcmService] cold-start FCM message: type=${initial.data['type']}',
      );
      unawaited(_dispatchWhenReady(() => _dispatch(initial)));
    }

    // 6b. Cold-start depuis un tap LocalNotification (background FSI).
    final launchPayload = await LocalNotificationService.getLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      debugPrint(
        '[FcmService] cold-start local notif: type=${launchPayload['type']}',
      );
      unawaited(_dispatchWhenReady(() => _onDataMessage?.call(launchPayload)));
    }
  }

  /// Attend que le [Routes.navigatorKey] ait un `currentState` avant
  /// d'executer [action]. Poll toutes les 50ms, cap a 1500ms (safety net).
  ///
  /// Sans cette helper, un dispatch au cold-start peut no-op silencieusement
  /// parce que le Navigator n'est pas encore monte. L'ancien code utilisait
  /// un `Future.delayed(800ms)` fixe — trop long en warm boot (~200ms suffisent),
  /// trop court en cold boot lent (tablette cheap qui peut prendre 1s+).
  Future<void> _dispatchWhenReady(FutureOr<void> Function() action) async {
    const Duration pollInterval = Duration(milliseconds: 50);
    const Duration maxWait = Duration(milliseconds: 1500);
    final Stopwatch sw = Stopwatch()..start();
    while (Routes.navigatorKey.currentState == null &&
        sw.elapsed < maxWait) {
      await Future<void>.delayed(pollInterval);
    }
    try {
      await action();
    } catch (e) {
      debugPrint('[FcmService] _dispatchWhenReady action failed: $e');
    }
  }

  /// Déclenche la demande de permission notification système + enregistrement
  /// du token FCM. À appeler **après** le pre-prompt `NotifRationaleSheet`
  /// depuis l'écran d'accueil post-auth.
  ///
  /// Idempotent : si la permission est déjà accordée, récupère juste le
  /// token et le synchronise côté serveur.
  Future<AuthorizationStatus> requestPushPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[FcmService] permission status: ${settings.authorizationStatus}',
    );

    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        DeviceTokenManager.instance.setPushToken(token);
        debugPrint('[FcmService] FCM token: ${token.substring(0, 16)}...');
        await DeviceTokenManager.instance.registerCurrentDevice();
      }
    } catch (e) {
      debugPrint('[FcmService] getToken failed: $e');
    }

    return settings.authorizationStatus;
  }

  void _dispatch(RemoteMessage message) {
    final handler = _onDataMessage;
    if (handler == null) return;
    final data = Map<String, dynamic>.from(message.data);

    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    // Une fois dispatche, on annule toute notif FSI en cours : l'ecran
    // Incoming prend le relais avec son propre ring.
    LocalNotificationService.cancelIncomingOrder();

    handler(data);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onOpenedAppSub = null;
    _onTokenRefreshSub = null;
    _initialized = false;
  }
}
