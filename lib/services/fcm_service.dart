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

import 'package:merchant/services/device_token_manager.dart';
import 'package:merchant/services/local_notification_service.dart';

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

    await LocalNotificationService.showIncomingOrder(
      title: title,
      body: body,
      payloadData: data,
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
  Future<void> init({required FcmDataHandler onDataMessage}) async {
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

    // 1. Permission FCM iOS (sur Android, c'est POST_NOTIFICATIONS qui compte,
    // deja demande par LocalNotificationService).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[FcmService] permission status: ${settings.authorizationStatus}',
    );

    // 2. Recupere le token courant.
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
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
        '[FcmService] cold-start FCM message: type=${initial.data['type']}',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        _dispatch(initial);
      });
    }

    // 6b. Cold-start depuis un tap LocalNotification (background FSI).
    final launchPayload = await LocalNotificationService.getLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      debugPrint(
        '[FcmService] cold-start local notif: type=${launchPayload['type']}',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        _onDataMessage?.call(launchPayload);
      });
    }
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
