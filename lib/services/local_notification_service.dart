// LocalNotificationService — Phase 3 du flow "Incoming Order".
//
// Role :
//  - Creer un canal de notification HIGH importance avec son d'alarme et
//    bypass du mode silencieux (USAGE_ALARM). Ce canal sert aussi au
//    FCM natif Android pour les pushes avec `notification:{}` envoyes
//    pendant que l'app est en background.
//  - Afficher une notification FullScreenIntent quand un FCM arrive alors
//    que l'app est killed ou en background profond : Android reveille
//    l'ecran (comme un appel entrant), affiche le titre/body, et au tap
//    lance MainActivity qui routera sur IncomingOrderScreen.
//  - Router le tap utilisateur (foreground ou cold-start) vers un callback
//    fourni par l'appelant, qui dispatchera via IncomingOrderDispatcher.
//
// Ce service doit etre initialisable DEPUIS LES DEUX ISOLATES (main + FCM
// background handler). La methode init() est idempotente et stocke la
// configuration localement par isolate.

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Id unique de la notification "incoming order". Utiliser le meme id a
/// chaque show permet de remplacer la notification precedente (evite les
/// empilements si le backend renvoie plusieurs pushs pour la meme commande).
const int kIncomingOrderNotificationId = 1001;

/// Id du canal Android. DOIT correspondre a celui que le backend place
/// eventuellement dans `android.notification.channel_id` de ses pushes FCM
/// pour beneficier du meme son/priorite.
const String kIncomingOrderChannelId = 'zeet_partner_incoming_order';
const String kIncomingOrderChannelName = 'Nouvelles commandes';
const String kIncomingOrderChannelDesc =
    'Alertes prioritaires avec sonnerie forte pour les nouvelles commandes entrantes.';

/// Canal pour les mises à jour de statut (annulation client, OTP, livreur
/// assigné). Importance HIGH : son + vibration mais PAS d'alarme — le
/// partner peut vouloir rester concentré sur la cuisine.
const String kOrderUpdateChannelId = 'zeet_partner_order_update';
const String kOrderUpdateChannelName = 'Mises à jour commandes';
const String kOrderUpdateChannelDesc =
    'Notifications sur le cycle de vie d\'une commande (livreur assigné, annulation, OTP).';

/// Canal marketing : offres plateforme, promos, actualités. Importance
/// DEFAULT : pas de son, l'utilisateur peut couper entièrement le canal.
const String kMarketingChannelId = 'zeet_partner_marketing';
const String kMarketingChannelName = 'Actualités ZEET';
const String kMarketingChannelDesc =
    'Offres plateforme, nouveautés et communications non urgentes.';

/// Signature du callback appele quand l'utilisateur tape la notification.
typedef NotificationTapHandler = Future<void> Function(
  Map<String, dynamic> payload,
);

/// Callback global de tap — stocke au niveau du fichier pour que le handler
/// static (`_onNotificationResponse`) puisse le retrouver.
NotificationTapHandler? _onTap;

/// Handler de tap en foreground.
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  final payloadStr = response.payload;
  if (payloadStr == null || payloadStr.isEmpty) return;
  try {
    final decoded = jsonDecode(payloadStr);
    if (decoded is Map) {
      _onTap?.call(Map<String, dynamic>.from(decoded));
    }
  } catch (e) {
    debugPrint('[LocalNotifService] payload parse failed: $e');
  }
}

/// Handler de tap quand l'app est killed (nouvelle isolate).
/// Flutter le reveille automatiquement si on tape une notif FSI.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // Rien a faire ici : le launch details sera recupere a l'init du main
  // isolate et le tap sera route a ce moment.
  debugPrint(
    '[LocalNotifService.bg] notification tapped (payload=${response.payload})',
  );
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// A appeler au plus tot dans main() ET dans le FCM background handler.
  /// Idempotent.
  static Future<void> init({NotificationTapHandler? onTap}) async {
    if (onTap != null) _onTap = onTap;

    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Cree le canal HIGH importance si pas deja present (idempotent).
    await _createChannel();

    // Demande la permission POST_NOTIFICATIONS (Android 13+). Best-effort.
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      // Android 14+ : permission FullScreenIntent separee.
      await androidImpl?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('[LocalNotifService] permission request failed: $e');
    }
  }

  static Future<void> _createChannel() async {
    // Canal 1 — Nouvelles commandes (max, sonnerie, FullScreenIntent).
    const AndroidNotificationChannel incomingChannel =
        AndroidNotificationChannel(
      kIncomingOrderChannelId,
      kIncomingOrderChannelName,
      description: kIncomingOrderChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Canal 2 — Mises à jour commandes (high, son par défaut).
    // Couvre : annulation client, livreur assigné, OTP pickup changé.
    const AndroidNotificationChannel orderUpdateChannel =
        AndroidNotificationChannel(
      kOrderUpdateChannelId,
      kOrderUpdateChannelName,
      description: kOrderUpdateChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Canal 3 — Marketing (default, silencieux, coupable par l'user).
    const AndroidNotificationChannel marketingChannel =
        AndroidNotificationChannel(
      kMarketingChannelId,
      kMarketingChannelName,
      description: kMarketingChannelDesc,
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(incomingChannel);
    await androidImpl?.createNotificationChannel(orderUpdateChannel);
    await androidImpl?.createNotificationChannel(marketingChannel);
  }

  /// Affiche une notification FullScreenIntent pour une nouvelle commande.
  /// Le payload sera attache a la notification et rejoue au tap.
  static Future<void> showIncomingOrder({
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    // Sur-init par securite si le service est appele avant init() (p.ex.
    // depuis le FCM background handler).
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      kIncomingOrderChannelId,
      kIncomingOrderChannelName,
      channelDescription: kIncomingOrderChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      // Categorie "call" = traitement prioritaire, bypass DND possible.
      category: AndroidNotificationCategory.call,
      // FullScreenIntent : reveille l'ecran et affiche comme un appel.
      fullScreenIntent: true,
      // Ongoing : ne peut pas etre swipee par l'utilisateur.
      ongoing: true,
      autoCancel: false,
      // Visible sur lockscreen avec contenu complet.
      visibility: NotificationVisibility.public,
      // Son d'alarme fort (ressource systeme si pas de custom).
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const [0, 800, 400, 800, 400, 800, 400, 800],
      ),
      // Couleur d'accent ZEET (orange).
      color: const Color(0xFFFF5A1F),
      colorized: true,
      ticker: title,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      kIncomingOrderNotificationId,
      title,
      body,
      details,
      payload: jsonEncode(payloadData),
    );
  }

  /// Annule la notification en cours (a appeler apres accept/reject).
  static Future<void> cancelIncomingOrder() async {
    try {
      await _plugin.cancel(kIncomingOrderNotificationId);
    } catch (e) {
      debugPrint('[LocalNotifService] cancel failed: $e');
    }
  }

  /// Recupere le payload d'une notification qui a lance l'app (cold-start).
  /// A appeler une fois au demarrage, apres init().
  static Future<Map<String, dynamic>?> getLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      final payloadStr = details?.notificationResponse?.payload;
      if (payloadStr == null || payloadStr.isEmpty) return null;
      final decoded = jsonDecode(payloadStr);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[LocalNotifService] getLaunchPayload failed: $e');
    }
    return null;
  }
}
