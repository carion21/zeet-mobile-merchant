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
import 'dart:convert';

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

  // Contract §2.1 — `type_value` est la cle canonique, `type` en fallback.
  // Aligne sur le dispatcher foreground (main.dart) pour un parsing coherent.
  final String type =
      (message.data['type_value']?.toString().isNotEmpty ?? false)
          ? message.data['type_value'].toString()
          : message.data['type']?.toString() ?? '';
  debugPrint(
    '[FcmService.bg] received: type=$type entity=${message.data['entity_id']}',
  );

  final data = Map<String, dynamic>.from(message.data);
  // Merge title/body depuis notification:{} si fourni (iOS collapse ces
  // champs dans message.notification plutot que dans data).
  final notif = message.notification;
  if (notif != null) {
    data['title'] ??= notif.title;
    data['body'] ??= notif.body;
  }

  // Seuls les events "new order" meritent un full-screen intent avec
  // sonnerie alarme — ils requierent une decision immediate.
  if (type == 'order.created' || type == 'new_order') {
    // Grouping Phase 4 : si > 3 notifs en < 2 min, le grouper active la
    // summary. Quel que soit le retour, on pousse la notif individuelle
    // avec groupKey/threadIdentifier (cf. LocalNotifService) pour que
    // le systeme les stacke visuellement. Parse defensif : si le payload
    // est minimaliste, le grouper compte quand meme la nouvelle entree.
    bool grouped = false;
    IncomingOrderPayload? parsed;
    try {
      parsed = IncomingOrderPayload.tryParse(data);
      if (parsed != null) {
        grouped = await IncomingOrderGrouper.instance.onIncomingOrder(parsed);
      }
    } catch (e) {
      debugPrint('[FcmService.bg] grouper failed: $e');
    }

    // Format dense lock-screen (Skill `zeet-notification-strategy` §3) :
    // `Cmde · 12 500 FCFA · 3 articles · ZT-...`. Permet au partner de
    // decider en 1 glance. Backend fournit `title`/`body` mais le parser
    // local enrichit avec total/items quand dispo.
    final title = _buildIncomingOrderTitle(data, parsed);
    final body = _buildIncomingOrderBody(data, parsed);

    await LocalNotificationService.showIncomingOrder(
      title: title,
      body: body,
      payloadData: data,
      groupKey: grouped ? kIncomingOrderGroupKey : null,
    );
    return;
  }

  // Transitions de commande en background — sans ce relais, aucune notif
  // n'apparait quand l'app est killed (data-only) et l'user voit l'etat
  // stale au retour foreground. Canal `zeet_partner_orders` HIGH
  // (son + vibration, pas FSI).
  //
  // Liste alignee sur FCM_PARTNER_CONTRACT.md §4 + WORK_ORDER §4 :
  // SEULS les events "visible HIGH/normal" generent une notif locale ici.
  // Les events "silent" (order.status_changed, order.delivered,
  // wallet.credited, rating.received) ne doivent JAMAIS reveiller l'user
  // en background — l'UI se mettra a jour via les dispatchers au prochain
  // foreground.
  //
  // Les alias historiques (`order.cancelled`, `order.updated`) sont gardes
  // pour absorber d'eventuels vieux backends ou messages en transit. A
  // retirer une fois la migration 4.x backend confirmee en prod.
  const Set<String> transitionTypes = <String>{
    'order.cancelled_by_customer',
    'order.cancelled_by_admin',
    'order.cancelled', // alias retrocompat
  };
  if (transitionTypes.contains(type)) {
    // Format dense : `Annulee client · ZT-... · 12 500 FCFA` quand le payload
    // permet d'enrichir. Fallback sur le title backend ou un libelle generique.
    final String title = _buildCancelTransitionTitle(data, type);
    final String body = (data['body']?.toString().isNotEmpty ?? false)
        ? data['body'].toString()
        : 'Appuyez pour voir la commande';
    await LocalNotificationService.showOrderUpdate(
      title: title,
      body: body,
      payloadData: data,
    );
  }
}

/// Construit un titre dense pour les transitions `order.cancelled_*`.
/// Format prefere : `Annulee client · ZT-... · 12 500 FCFA`.
/// Skill `zeet-notification-strategy` §3.
String _buildCancelTransitionTitle(Map<String, dynamic> data, String type) {
  // Parse defensif metadata pour total + code, comme _buildIncomingOrderTitle.
  int? totalFcfa;
  String? orderCode;
  final dynamic meta = data['metadata'];
  Map<String, dynamic>? metaMap;
  if (meta is Map) {
    metaMap = Map<String, dynamic>.from(meta);
  } else if (meta is String && meta.isNotEmpty) {
    try {
      final decoded = jsonDecode(meta);
      if (decoded is Map) metaMap = Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  totalFcfa = (metaMap?['total_fcfa'] ?? metaMap?['total']) as int? ??
      (data['total_fcfa'] ?? data['total']) as int?;
  orderCode = (metaMap?['order_code'] ?? data['order_code']) as String?;

  final String prefix = type == 'order.cancelled_by_customer'
      ? 'Annulee client'
      : type == 'order.cancelled_by_admin'
          ? 'Annulee ZEET'
          : 'Annulee';
  final List<String> parts = <String>[prefix];
  if (orderCode != null && orderCode.isNotEmpty) parts.add(orderCode);
  if ((totalFcfa ?? 0) > 0) {
    final s = totalFcfa.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    parts.add('${buf.toString()} FCFA');
  }
  if (parts.length == 1) {
    final raw = data['title']?.toString();
    if (raw != null && raw.isNotEmpty) return raw;
    return _defaultTransitionTitle(type);
  }
  return parts.join(' · ');
}

/// Construit un titre de notif "nouvelle commande" dense et glanceable.
///
/// Format prefere : `Cmde · 12 500 FCFA · 3 articles`. Si le payload n'a
/// pas le total ou le nombre d'items, on retombe sur le titre backend, puis
/// sur le libelle generique "Nouvelle commande".
///
/// Skill `zeet-notification-strategy` §3 (info dense lock-screen) +
/// `zeet-tone-of-voice-fr` (vouvoiement, abreviations sobres).
String _buildIncomingOrderTitle(
  Map<String, dynamic> data,
  IncomingOrderPayload? parsed,
) {
  final int total = parsed?.totalFcfa ?? 0;
  final int items = parsed?.itemsCount ?? 0;

  if (total > 0 && items > 0) {
    return 'Cmde · ${_formatFcfa(total)} · ${_pluralizeItems(items)}';
  }
  if (total > 0) {
    return 'Cmde · ${_formatFcfa(total)}';
  }
  if (items > 0) {
    return 'Cmde · ${_pluralizeItems(items)}';
  }
  final raw = data['title']?.toString();
  if (raw != null && raw.isNotEmpty) return raw;
  return 'Nouvelle commande';
}

/// Construit le body de la notif. Affiche le code de commande si dispo,
/// sinon retombe sur le body backend ou un libelle generique.
String _buildIncomingOrderBody(
  Map<String, dynamic> data,
  IncomingOrderPayload? parsed,
) {
  final code = parsed?.orderCode;
  if (code != null && code.isNotEmpty) {
    return 'Code : $code · Appuyez pour decider.';
  }
  final raw = data['body']?.toString();
  if (raw != null && raw.isNotEmpty) return raw;
  return 'Appuyez pour voir les details.';
}

/// Format FCFA avec espaces tous les 3 chiffres (convention BCEAO/Zeet).
/// Ex: 12500 → "12 500 FCFA".
String _formatFcfa(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${buf.toString()} FCFA';
}

String _pluralizeItems(int n) => n <= 1 ? '$n article' : '$n articles';

/// Libelle par defaut quand le backend n'envoie pas de `title` dans le
/// payload data (fallback rare — en prod le backend pose toujours ce champ).
String _defaultTransitionTitle(String type) {
  switch (type) {
    case 'order.cancelled_by_customer':
      return 'Commande annulée par le client';
    case 'order.cancelled_by_admin':
      return 'Commande annulée par ZEET';
    case 'order.cancelled':
    default:
      return 'Commande annulée';
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
    } else {
      // Bug historique : sans ce fallback, le token FCM n'etait jamais refetch
      // au cold-start. Si l'utilisateur avait accepte la permission lors d'une
      // session precedente mais que le token FCM a ete invalide (rotation
      // silencieuse, reinstall Google Play Services, backend qui a supprime
      // l'entree), le backend n'avait plus aucun moyen de joindre l'app et
      // les nouvelles commandes tombaient dans le vide.
      //
      // ensureTokenRegistered verifie le statut de permission SANS declencher
      // le prompt iOS (getNotificationSettings, pas requestPermission) et
      // re-enregistre le token courant aupres du backend si tout est ok.
      unawaited(ensureTokenRegistered());
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

  /// Re-fetch silencieux du token FCM + re-register cote backend, **sans**
  /// declencher le prompt de permission systeme.
  ///
  /// A appeler :
  ///  - Au cold-start (depuis [init], pour couvrir le cas "l'utilisateur a
  ///    accepte la permission lors d'une precedente session").
  ///  - Apres un login (pour garantir que le backend recoit le token a jour
  ///    meme si la session prec. a ete perdue / le token a rotate).
  ///
  /// Skip silencieusement si la permission n'est pas accordee, ou si
  /// `getToken()` echoue (reseau / Google Play Services absent).
  Future<bool> ensureTokenRegistered() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // getNotificationSettings NE DECLENCHE PAS le prompt iOS — c'est une
      // simple lecture du statut courant.
      final settings = await messaging.getNotificationSettings();
      final status = settings.authorizationStatus;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        debugPrint(
          '[FcmService.ensure] permission not granted yet (status=$status) — skip',
        );
        return false;
      }

      final String? token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FcmService.ensure] getToken returned null/empty');
        return false;
      }

      DeviceTokenManager.instance.setPushToken(token);
      debugPrint(
        '[FcmService.ensure] FCM token refreshed: ${token.substring(0, 16)}...',
      );
      return await DeviceTokenManager.instance.registerCurrentDevice();
    } catch (e) {
      debugPrint('[FcmService.ensure] failed: $e');
      return false;
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
