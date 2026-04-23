// LocalNotificationService — Phase 3+4 du flow "Incoming Order".
//
// Role :
//  - Creer les canaux de notification requis par le backend (5 channels
//    dont 3 critiques matches a l'ID pres sur `ORDERS_PARTNER_FLOW.md`).
//  - Afficher une notification FullScreenIntent quand un FCM arrive alors
//    que l'app est killed ou en background profond : Android reveille
//    l'ecran (comme un appel entrant), affiche le titre/body, et au tap
//    lance MainActivity qui routera sur IncomingOrderScreen.
//  - Grouper intelligemment les notifs rapides (>3 en <2 min) en 1 summary
//    Android inbox-style + `threadIdentifier` iOS — cf. Phase 4 skill
//    `zeet-notification-strategy` §4.
//  - Router le tap utilisateur (foreground ou cold-start) vers un callback
//    fourni par l'appelant, qui dispatchera via IncomingOrderDispatcher.
//
// Matrice des channels (backend → local) :
//   ┌────────────────────────────────────┬──────────────────────┬─────────────┐
//   │ Event type                         │ channel_id           │ Importance  │
//   ├────────────────────────────────────┼──────────────────────┼─────────────┤
//   │ order.created (critical, FSI)      │ zeet_partner_incoming_order*│ max  │
//   │ order.*  (updates transitions)     │ zeet_partner_orders  │ high        │
//   │ ticket.*  (support)                │ zeet_partner_support │ high        │
//   │ platform.promo / news              │ zeet_partner_marketing│ default    │
//   │ service.reminder / pending actions │ zeet_partner_reminders│ high       │
//   │ stats / daily recap                │ zeet_partner_stats   │ default     │
//   └────────────────────────────────────┴──────────────────────┴─────────────┘
//   * suffixe `_v2` : bump local car Android refuse de modifier le son d'un
//     channel apres creation (cf. kIncomingOrderChannelId plus bas).
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

/// Base id pour les notifs "action en echec de sync". Offset par l'orderId
/// pour ne pas ecraser plusieurs echecs simultanes. Plafonne a 65k commandes
/// en vol pour rester dans une plage int32 sure.
const int kSyncFailedNotificationIdBase = 3000;

/// Base id pour les notifs "mise a jour commande" (rider_assigned, cancelled,
/// delivered, otp.updated…). Offset par l'orderId pour que plusieurs updates
/// simultanees sur des commandes differentes s'empilent au lieu de s'ecraser.
/// Plafonne a 65k commandes en vol pour rester dans la plage int32.
const int kOrderUpdateNotificationIdBase = 2000;

/// Id du canal Android. DOIT correspondre a celui que le backend place
/// eventuellement dans `android.notification.channel_id` de ses pushes FCM
/// pour beneficier du meme son/priorite.
///
/// **Versionnage** : Android refuse de modifier le son d'un channel apres
/// sa creation (cf. NotificationChannel.setSound docs). Bumper le suffixe a
/// chaque changement de son / d'importance. `_v4` : retrait de la
/// `RawResourceAndroidNotificationSound('incoming_order')` tant que le MP3
/// n'est pas livre — certains OEMs (Samsung notamment) creaient un channel
/// silencieux ou droppaient la notif quand la raw resource etait
/// introuvable, au lieu de fallback sur le son systeme comme annonce. En
/// omettant le `sound:`, on laisse Android utiliser le son de notif
/// systeme par defaut, ce qui marche partout.
const String kIncomingOrderChannelId = 'zeet_partner_incoming_order_v4';
const String kIncomingOrderChannelName = 'Nouvelles commandes';
const String kIncomingOrderChannelDesc =
    'Alertes prioritaires avec sonnerie distincte pour les nouvelles commandes entrantes.';

/// Nom de la raw resource Android pour la sonnerie incoming order. Doit
/// correspondre exactement au nom du fichier dans
/// `android/app/src/main/res/raw/<name>.mp3` (lowercase, pas d'espaces).
///
/// Tant que [kHasCustomIncomingSound] est `false`, cette constante n'est
/// pas utilisee — on laisse Android / iOS jouer leur son systeme par defaut.
const String kIncomingOrderSoundResource = 'incoming_order';

/// Nom du fichier de sonnerie iOS — bundle dans ios/Runner/. Format `.caf`
/// recommande (Core Audio Format), voir `assets/sounds/README.md`.
const String kIncomingOrderSoundIos = 'incoming_order.caf';

/// Flipper : `true` quand le MP3 / CAF custom est bien commit dans
/// `android/app/src/main/res/raw/` et `ios/Runner/`. Tant qu'il est `false`,
/// on omet le parametre `sound` des notifs/channels → fallback propre sur
/// le son systeme par defaut. Quand le sound design livre les assets :
///   1. Copier `incoming_order.mp3` dans `android/app/src/main/res/raw/`.
///   2. Copier `incoming_order.caf` dans `ios/Runner/` + ajouter au
///      bundle Xcode (Build Phases → Copy Bundle Resources).
///   3. Basculer ce flag a `true` ET bumper [kIncomingOrderChannelId]
///      (`_v4` → `_v5`) pour forcer Android a recreer le channel avec
///      le nouveau son — Android refuse de modifier le son d'un channel
///      existant.
const bool kHasCustomIncomingSound = false;

/// Canal pour les mises à jour de statut (annulation client, OTP, livreur
/// assigné). Importance HIGH : son + vibration mais PAS d'alarme — le
/// partner peut vouloir rester concentré sur la cuisine.
///
/// **ID backend-attendu** : `zeet_partner_orders` (cf. ORDERS_PARTNER_FLOW.md
/// §6.3 — Channels matrix). Le backend pousse les notifications de
/// transition de commande (rider_assigned, cancelled, delivered…) sur
/// exactement ce `channel_id` Android, donc on doit matcher à la lettre.
const String kOrderUpdateChannelId = 'zeet_partner_orders';
const String kOrderUpdateChannelName = 'Mises à jour commandes';
const String kOrderUpdateChannelDesc =
    'Notifications sur le cycle de vie d\'une commande (livreur assigné, annulation, OTP).';

/// Canal pour les tickets support (reponses agent, escalades, cloture).
/// Importance HIGH : le partner doit voir la reponse support rapidement
/// pour debloquer une operation (rupture, incident livraison, paiement).
///
/// **ID backend-attendu** : `zeet_partner_support` (cf. ORDERS_PARTNER_FLOW.md
/// §6.3 — Channels matrix).
const String kSupportChannelId = 'zeet_partner_support';
const String kSupportChannelName = 'Support';
const String kSupportChannelDesc =
    'Reponses aux tickets support et communications de l\'equipe ZEET.';

/// Canal marketing : offres plateforme, promos, actualités. Importance
/// DEFAULT : pas de son, l'utilisateur peut couper entièrement le canal.
const String kMarketingChannelId = 'zeet_partner_marketing';
const String kMarketingChannelName = 'Actualités ZEET';
const String kMarketingChannelDesc =
    'Offres plateforme, nouveautés et communications non urgentes.';

/// Canal rappels : "N'oubliez pas de clôturer le service", "Mettez à jour
/// vos horaires d'été", etc. Importance HIGH mais son par défaut pour ne
/// pas stresser pendant le coup de feu.
const String kReminderChannelId = 'zeet_partner_reminders';
const String kReminderChannelName = 'Rappels service';
const String kReminderChannelDesc =
    'Rappels operationnels : cloture de service, horaires, actions en attente.';

/// Canal stats : récapitulatifs quotidiens / hebdomadaires. Importance
/// DEFAULT, silencieux — le partner consulte quand il est dispo.
const String kStatsChannelId = 'zeet_partner_stats';
const String kStatsChannelName = 'Recaps & stats';
const String kStatsChannelDesc =
    'Recaps quotidiens, chiffre d\'affaires, statistiques hebdomadaires.';

/// Group key Android + threadIdentifier iOS pour le grouping intelligent
/// des notifs de commandes entrantes rapides (>3 en <2min). Toutes les
/// notifs incoming partagent cette clé : Android les empile visuellement
/// sous une summary notification (inbox style), iOS les regroupe dans le
/// meme fil de discussion. Cf. Phase 4 — skill zeet-notification-strategy §4.
const String kIncomingOrderGroupKey = 'zeet.partner.orders';

/// Identifiants de categories APNS iOS — DOIVENT matcher exactement ceux
/// que le backend place dans `apns.payload.aps.category`.
/// Source : FCM_PARTNER_CONTRACT.md §3 (tableau "Category APNS").
const String kIosOrderCategoryId = 'ZEET_PARTNER_ORDER';
const String kIosSupportCategoryId = 'ZEET_PARTNER_SUPPORT';

/// Id de la notification "summary" (inbox style) qui chapeaute le groupe
/// Android. Doit être distinct de [kIncomingOrderNotificationId] pour que
/// les deux coexistent.
const int kIncomingOrderSummaryId = 1002;

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
    // iOS Darwin init : permissions gérées en amont par FcmService pour
    // respecter le pre-prompt (zeet-notification-strategy §8).
    // Categories APNS alignees sur FCM_PARTNER_CONTRACT.md §3 :
    //  - `ZEET_PARTNER_ORDER`   : nouvelle commande / transitions
    //  - `ZEET_PARTNER_SUPPORT` : tickets support / mentions
    // IMPORTANT : les IDs doivent MATCHER EXACTEMENT ceux que le backend
    // envoie dans `apns.payload.aps.category`, sinon iOS ignore les inline
    // actions. Le backend envoie en uppercase snake_case.
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          kIosOrderCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'accept',
              'Accepter',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'refuse',
              'Refuser',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
        DarwinNotificationCategory(
          kIosSupportCategoryId,
          actions: <DarwinNotificationAction>[
            // "Repondre" : input text inline (iOS affiche un champ sans
            // ouvrir l'app). Le texte saisi est transmis via response.input.
            DarwinNotificationAction.text(
              'reply',
              'Repondre',
              buttonTitle: 'Envoyer',
              placeholder: 'Tapez votre reponse…',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

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
    // Canal 1 — Nouvelles commandes (max, FullScreenIntent). Tant que
    // [kHasCustomIncomingSound] est `false` (MP3 pas encore livre), on
    // n'attache PAS de `RawResourceAndroidNotificationSound` — certains
    // OEMs creaient un channel silencieux ou droppaient la notif quand la
    // raw resource n'existait pas, au lieu du fallback systeme annonce.
    // Sans `sound:`, Android joue le son de notif par defaut, qui marche
    // partout. Quand le MP3 sera livre : flipper [kHasCustomIncomingSound]
    // a `true` + bumper [kIncomingOrderChannelId] (`_v4` -> `_v5`).
    final AndroidNotificationChannel incomingChannel =
        AndroidNotificationChannel(
      kIncomingOrderChannelId,
      kIncomingOrderChannelName,
      description: kIncomingOrderChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: kHasCustomIncomingSound
          ? const RawResourceAndroidNotificationSound(
              kIncomingOrderSoundResource,
            )
          : null,
      enableVibration: true,
      // Pattern long et marque (cuisine bruyante).
      vibrationPattern: Int64List.fromList(
        const <int>[0, 800, 400, 800, 400, 800, 400, 800],
      ),
      showBadge: true,
      // Audio en mode alarm pour bypass Do Not Disturb (l'OS demande
      // l'autorisation explicite a l'utilisateur via les settings systeme —
      // sans accord, ce flag est ignore). Cf. zeet-notification-strategy §4.
      audioAttributesUsage: AudioAttributesUsage.alarm,
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

    // Canal 4 — Rappels operationnels (high, son par defaut).
    const AndroidNotificationChannel reminderChannel =
        AndroidNotificationChannel(
      kReminderChannelId,
      kReminderChannelName,
      description: kReminderChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Canal 5 — Stats / recaps (default, silencieux).
    const AndroidNotificationChannel statsChannel = AndroidNotificationChannel(
      kStatsChannelId,
      kStatsChannelName,
      description: kStatsChannelDesc,
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    // Canal 6 — Support (high, son par defaut). Critique pour ne pas
    // rater une reponse agent pendant une operation bloquante.
    const AndroidNotificationChannel supportChannel = AndroidNotificationChannel(
      kSupportChannelId,
      kSupportChannelName,
      description: kSupportChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(incomingChannel);
    await androidImpl?.createNotificationChannel(orderUpdateChannel);
    await androidImpl?.createNotificationChannel(marketingChannel);
    await androidImpl?.createNotificationChannel(reminderChannel);
    await androidImpl?.createNotificationChannel(statsChannel);
    await androidImpl?.createNotificationChannel(supportChannel);

    // Validation dev-only : les 3 channels **critiques** attendus par le
    // backend (ORDERS_PARTNER_FLOW.md §6.3) doivent etre effectivement
    // crees. On log un avertissement en debug si l'un manque.
    if (kDebugMode) {
      try {
        final created = await androidImpl?.getNotificationChannels() ?? [];
        final ids = created.map((c) => c.id).toSet();
        final required = <String>{
          kIncomingOrderChannelId,
          kOrderUpdateChannelId,
          kSupportChannelId,
        };
        final missing = required.difference(ids);
        if (missing.isNotEmpty) {
          debugPrint(
            '[LocalNotifService] WARN channels backend manquants: $missing',
          );
        } else {
          debugPrint(
            '[LocalNotifService] OK 3 channels backend critiques declares '
            '(incoming=$kIncomingOrderChannelId, updates=$kOrderUpdateChannelId, '
            'support=$kSupportChannelId)',
          );
        }
      } catch (e) {
        debugPrint('[LocalNotifService] channel validation skipped: $e');
      }
    }
  }

  /// Affiche une notification FullScreenIntent pour une nouvelle commande.
  /// Le payload sera attache a la notification et rejoue au tap.
  ///
  /// [groupKey] (optionnel) : lorsque le grouping intelligent est actif
  /// (cf. [showIncomingOrderSummary]), chaque notif individuelle partage
  /// la meme clé pour etre empilee sous la summary Android / dans le meme
  /// thread iOS.
  static Future<void> showIncomingOrder({
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
    String? groupKey,
    int? notificationId,
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
      // Son : raw resource custom si livree ([kHasCustomIncomingSound]),
      // sinon on omet le parametre pour laisser Android jouer le son de
      // notif par defaut. Attacher une raw resource invalide faisait
      // dropper la notif sur certains OEMs au lieu du fallback annonce.
      playSound: true,
      sound: kHasCustomIncomingSound
          ? const RawResourceAndroidNotificationSound(
              kIncomingOrderSoundResource,
            )
          : null,
      // Audio en mode alarm pour bypass DND (avec permission utilisateur).
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const [0, 800, 400, 800, 400, 800, 400, 800],
      ),
      // Couleur d'accent ZEET (orange).
      color: const Color(0xFFFF5A1F),
      colorized: true,
      ticker: title,
      // Grouping : toutes les notifs "nouvelle commande" partagent le meme
      // groupKey → Android les empile sous la summary. Individual expand
      // style par defaut (BigText/Inbox cote summary).
      groupKey: groupKey,
      // Actions inline : Accepter / Refuser depuis la notification (sans
      // ouvrir l'app). Skill zeet-notification-strategy §6.
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept',
          'Accepter',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'refuse',
          'Refuser',
          showsUserInterface: true,
        ),
      ],
    );
    // iOS : `timeSensitive` permet de percer le Focus Mode si l'utilisateur
    // l'autorise. Critical alerts nécessitent l'entitlement Apple (rare).
    // Cf. zeet-notification-strategy §4 (bypass DND et focus).
    //
    // Son : fichier custom si livre ([kHasCustomIncomingSound]) et present
    // dans le bundle iOS, sinon on omet le parametre pour laisser iOS jouer
    // le son par defaut. Une reference a un fichier absent pouvait suffire
    // a faire echouer la notif sur certains devices.
    //
    // `threadIdentifier` : lorsque groupKey != null, iOS regroupe les notifs
    // du meme thread dans la notification-center stack. Cf. Phase 4.
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: kHasCustomIncomingSound ? kIncomingOrderSoundIos : null,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: kIosOrderCategoryId,
      threadIdentifier: groupKey,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      notificationId ?? kIncomingOrderNotificationId,
      title,
      body,
      details,
      payload: jsonEncode(payloadData),
    );
  }

  /// Affiche une notification "summary" inbox-style Android qui chapeaute
  /// un groupe de notifs "nouvelle commande" (Phase 4 grouping intelligent).
  ///
  /// Utilisee par [IncomingOrderGrouper] lorsqu'un seuil est depasse
  /// (>3 notifs en <2 min). Un tap sur la summary ouvre l'app sur la liste
  /// `payment-accepted` via le payload `{type: 'orders.group'}`.
  ///
  /// iOS n'a pas de concept de "summary" : chaque notif est deja dans le
  /// meme `threadIdentifier`, iOS decide du regroupement visuel seul.
  static Future<void> showIncomingOrderSummary({
    required int count,
    required int totalFcfa,
    required List<String> lines,
  }) async {
    if (!_initialized) await init();

    // Inbox style : liste chaque commande ("ZT-... - 12 500 FCFA") sous
    // la ligne de resume ("X nouvelles commandes · Y FCFA"). Lisible en un
    // coup d'oeil meme en cuisine (skill zeet-pos-ergonomics §2.6).
    final InboxStyleInformation inboxStyle = InboxStyleInformation(
      lines,
      contentTitle: '$count nouvelles commandes',
      summaryText: '${_formatFcfa(totalFcfa)} au total',
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kIncomingOrderChannelId,
      kIncomingOrderChannelName,
      channelDescription: kIncomingOrderChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      styleInformation: inboxStyle,
      // Pas de FSI sur la summary (sinon double reveil de l'ecran).
      fullScreenIntent: false,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      // Pas de son : les notifs individuelles ont deja sonne. La summary est
      // silencieuse pour eviter la saturation auditive (skill notif §4).
      playSound: false,
      enableVibration: false,
      color: const Color(0xFFFF5A1F),
      colorized: true,
      groupKey: kIncomingOrderGroupKey,
      setAsGroupSummary: true,
      ticker: '$count nouvelles commandes en attente',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: kIncomingOrderGroupKey,
    );
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Payload special : tap sur la summary ouvre la liste orders filtree
    // sur `payment-accepted` plutot qu'une commande particuliere.
    final Map<String, dynamic> payload = <String, dynamic>{
      'type': 'orders.group',
      'filter': 'payment-accepted',
      'group_count': count,
      'group_total_fcfa': totalFcfa,
    };

    await _plugin.show(
      kIncomingOrderSummaryId,
      '$count nouvelles commandes',
      '${_formatFcfa(totalFcfa)} au total · tapez pour voir',
      details,
      payload: jsonEncode(payload),
    );
  }

  /// Annule la summary notification du groupe (a appeler quand le groupe est
  /// vide, ou apres que l'utilisateur a consulte la liste).
  static Future<void> cancelIncomingOrderSummary() async {
    try {
      await _plugin.cancel(kIncomingOrderSummaryId);
    } catch (e) {
      debugPrint('[LocalNotifService] cancel summary failed: $e');
    }
  }

  /// Formate un montant FCFA avec espace insecable (1 234 FCFA).
  /// Helper local pour eviter d'importer intl depuis le background isolate.
  static String _formatFcfa(int total) {
    final String str = total.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        out.write('\u00A0');
      }
      out.write(str[i]);
    }
    out.write('\u00A0FCFA');
    return out.toString();
  }

  /// Annule la notification en cours (a appeler apres accept/reject).
  static Future<void> cancelIncomingOrder() async {
    try {
      await _plugin.cancel(kIncomingOrderNotificationId);
    } catch (e) {
      debugPrint('[LocalNotifService] cancel failed: $e');
    }
  }

  /// Affiche une notification locale pour une **transition de commande**
  /// (rider_assigned, cancelled, delivered, otp.updated…) recue en background.
  ///
  /// Sans ce relais local, quand l'app est killed, le FCM background handler
  /// tournait mais ne montrait AUCUNE notif pour les transitions critiques
  /// (seul `order.created` avait un FSI). Resultat : au retour foreground,
  /// l'utilisateur voit l'etat stale jusqu'au prochain refresh manuel — le
  /// bug "le refresh partner n'est pas toujours effectif".
  ///
  /// Canal `zeet_partner_orders` (importance HIGH, pas de FSI) : son discret,
  /// vibration courte, tap-to-open sur OrderDetailsScreen via le payload.
  /// N'affiche PAS une alerte comme une nouvelle commande — c'est une
  /// information de suivi, pas une interruption d'action.
  static Future<void> showOrderUpdate({
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    if (!_initialized) await init();

    // Offset par orderId pour que les updates de commandes differentes
    // coexistent (pas d'ecrasement). Fallback sur le base id si pas d'id
    // dans le payload (improbable mais on reste defensif).
    final orderIdRaw =
        payloadData['order_id'] ?? payloadData['entity_id'] ?? payloadData['id'];
    final int? orderId = orderIdRaw is int
        ? orderIdRaw
        : int.tryParse(orderIdRaw?.toString() ?? '');
    final int notificationId = orderId != null
        ? kOrderUpdateNotificationIdBase + (orderId % 60000)
        : kOrderUpdateNotificationIdBase;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kOrderUpdateChannelId,
      kOrderUpdateChannelName,
      channelDescription: kOrderUpdateChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      color: Color(0xFFFF5A1F),
      colorized: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      categoryIdentifier: kIosOrderCategoryId,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode(payloadData),
    );
  }

  /// Affiche une notification quand une action queued (sync offline) echoue
  /// definitivement. Sans ce signal, le partner ne voit l'echec qu'en
  /// ouvrant manuellement SyncPendingScreen (cf. zeet-offline-first §7).
  ///
  /// Canal : reminder (high importance, son par defaut). Deep-link payload
  /// `{type: 'sync.failed'}` route sur l'ecran des actions en attente.
  static Future<void> showSyncActionFailed({
    required int orderId,
    required String actionLabel,
    String? reason,
  }) async {
    if (!_initialized) await init();
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kReminderChannelId,
      kReminderChannelName,
      channelDescription: kReminderChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      color: const Color(0xFFFF5A1F),
      ticker: 'Action non appliquee',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final String body = reason == null || reason.isEmpty
        ? 'Commande #$orderId · "$actionLabel" n\'a pas pu etre enregistree.'
        : 'Commande #$orderId · "$actionLabel" · $reason';
    final int notifId =
        kSyncFailedNotificationIdBase + (orderId & 0x0000FFFF);
    try {
      await _plugin.show(
        notifId,
        'Action non appliquee',
        body,
        details,
        payload: jsonEncode(<String, dynamic>{
          'type': 'sync.failed',
          'orderId': orderId,
        }),
      );
    } catch (e) {
      debugPrint('[LocalNotifService] showSyncActionFailed failed: $e');
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
