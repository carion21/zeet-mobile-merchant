// DeepLinkHandler — Phase 4.2 skill zeet-notification-strategy §7.
//
// Role : router les deep-links issus d'une notification (cold-start, tap
// background, tap foreground) vers l'ecran cible avec contexte pre-rempli.
//
// Regle critique (skill §7) : si l'app est killed quand la notif arrive,
// un tap doit aller DIRECTEMENT sur l'ecran cible — JAMAIS par le home
// comme etape intermediaire.
//
// Mapping types → route (source : FCM_PARTNER_CONTRACT.md §4) :
//   - `order.created` / `new_order` → IncomingOrderScreen (via
//     IncomingOrderDispatcher.handleRaw — inchange, deja Phase 2).
//   - `order.updated` / `order.rider_assigned` / `order.cancelled`
//     / `order.delivered` / `order.otp.updated` → OrderDetailsScreen
//     avec `fromNotificationId` pour declencher l'ACK silent.
//   - `orders.group` (payload synthetique de la summary inbox) → liste
//     orders filtree sur `payment-accepted`.
//   - `support.message_received` / `support.mention`
//     / `support.status_changed` / `support.ticket_opened`
//     → TicketDetailScreen(ticketId) + ACK silent (stop cascade backend).
//   - autre → rien (log debug, pas de routage).
//
// Cle de routage : le backend envoie `type` ET `type_value` (alias canonique,
// cf. contract §2.1). On lit `type_value` en priorite pour rester aligne sur
// la cle canonique, `type` en fallback.
//
// Le handler utilise Routes.* (NavigatorState global) plutot qu'un
// `BuildContext` : il doit fonctionner avant le premier frame (cold-start)
// ou depuis un isolate sans widget tree.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/order_details/index.dart';
import 'package:merchant/screens/root/index.dart';
import 'package:merchant/screens/tickets/detail.dart';
import 'package:merchant/services/incoming_order_dispatcher.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/notification_service.dart';

/// Types de payload qui correspondent a une commande individuelle (detail).
const Set<String> _kOrderDetailTypes = <String>{
  'order.updated',
  'order.rider_assigned',
  'order.cancelled',
  'order.delivered',
  'order.otp.updated',
  'order.ready.reminded',
  'order.preparing.reminded',
};

/// Types qui ouvrent la vue groupe (liste filtree).
const String _kOrdersGroupType = 'orders.group';

/// Types de payload qui ouvrent un ticket support (TicketDetailScreen).
/// Source : FCM_PARTNER_CONTRACT.md §4.2-4.5.
const Set<String> _kSupportTicketTypes = <String>{
  'support.message_received',
  'support.mention',
  'support.status_changed',
  'support.ticket_opened',
};

abstract class DeepLinkHandler {
  /// Route un payload brut (issu de FCM.data, iOS category, LocalNotif
  /// launch, etc.). Retourne `true` si un routage a eu lieu.
  ///
  /// IMPORTANT : si le type est `order.created`, on delegue au
  /// [IncomingOrderDispatcher] existant (Phase 2) — il gere deja la
  /// navigation vers l'IncomingOrderScreen sans passer par home.
  static bool handle(WidgetRef ref, Map<String, dynamic> raw) {
    // Contract §2.1 : `type_value` est la cle canonique de routage. On lit
    // `type_value` en priorite et `type` en fallback (ils sont identiques
    // dans le payload actuel, mais le contrat prefere `type_value`).
    final String type = (raw['type_value']?.toString().isNotEmpty ?? false)
        ? raw['type_value'].toString()
        : raw['type']?.toString() ?? '';

    // 1. Incoming order — deleguer au dispatcher existant (inchange).
    if (type.startsWith('order.created') || type == 'new_order') {
      return IncomingOrderDispatcher.handleRaw(ref, raw);
    }

    // 2. Summary inbox groupee : ouvrir la liste orders sur
    //    "payment-accepted" directement (pas via home).
    if (type == _kOrdersGroupType) {
      _routeToOrdersGroup(ref, raw);
      return true;
    }

    // 3. Transition de commande → details directs avec ACK.
    if (_kOrderDetailTypes.contains(type)) {
      return _routeToOrderDetails(raw);
    }

    // 4. Support tickets → TicketDetailScreen + ACK silent.
    if (_kSupportTicketTypes.contains(type)) {
      return _routeToTicketDetail(raw);
    }

    if (kDebugMode) {
      debugPrint('[DeepLinkHandler] type non mappe: $type');
    }
    return false;
  }

  /// Route directement vers OrderDetailsScreen (jamais via home).
  /// Reference : skill §7 "Si l'app est killed... pas de passage par le
  /// home — passage direct."
  static bool _routeToOrderDetails(Map<String, dynamic> raw) {
    // On reutilise IncomingOrderPayload.tryParse : meme logique defensive
    // de parsing (entity_id, metadata JSON string, notification_id…).
    final IncomingOrderPayload? parsed =
        IncomingOrderPayload.tryParse(raw);
    if (parsed == null) {
      debugPrint('[DeepLinkHandler] order detail: parsing echoue: $raw');
      return false;
    }

    // Navigator peut ne pas etre pret au tout premier frame du cold-start.
    // Le guard `currentState == null` de Routes.push swallow proprement.
    Routes.push(
      OrderDetailsScreen(
        orderId: parsed.orderId,
        fromNotificationId:
            parsed.notificationId > 0 ? parsed.notificationId : null,
      ),
    );
    return true;
  }

  /// Route directement vers TicketDetailScreen et declenche un ACK silent
  /// pour stopper la cascade backend (WS → FCM retry → SMS → Telegram).
  /// Contract §6.2 : parser `deep_link` en priorite, `entity_id` en fallback.
  static bool _routeToTicketDetail(Map<String, dynamic> raw) {
    final String? ticketId = _extractTicketId(raw);
    if (ticketId == null || ticketId.isEmpty) {
      debugPrint('[DeepLinkHandler] support: ticketId introuvable dans $raw');
      return false;
    }

    // ACK silent fire-and-forget (stop cascade backend). Idempotent.
    final int notifId = _asInt(raw['notification_id']) ?? 0;
    if (notifId > 0) {
      NotificationService().acknowledgeSilent(notifId);
    }

    Routes.push(TicketDetailScreen(ticketId: ticketId));
    return true;
  }

  /// Extrait le ticketId depuis un payload support.*.
  /// Priorite : (1) `data.entity_id` top-level, (2) `deep_link` zeet://ticket/:id,
  /// (3) `metadata.ticket_id` (JSON string fallback).
  static String? _extractTicketId(Map<String, dynamic> raw) {
    // 1. Top-level entity_id (contract §2.1).
    final String? entityId = raw['entity_id']?.toString();
    if (entityId != null && entityId.isNotEmpty) return entityId;

    // 2. deep_link zeet://ticket/:id (contract §5).
    final String deepLink = raw['deep_link']?.toString() ?? '';
    final RegExpMatch? match =
        RegExp(r'zeet://ticket/(\d+)').firstMatch(deepLink);
    if (match != null) return match.group(1);

    // 3. metadata JSON string fallback.
    final dynamic metaRaw = raw['metadata'];
    if (metaRaw is String && metaRaw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(metaRaw);
        if (decoded is Map && decoded['ticket_id'] != null) {
          return decoded['ticket_id'].toString();
        }
      } catch (_) {
        // metadata malforme — on retombe sur null
      }
    }
    if (metaRaw is Map && metaRaw['ticket_id'] != null) {
      return metaRaw['ticket_id'].toString();
    }
    return null;
  }

  static int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Ouvre la liste orders filtree sur `payment-accepted` (coup de feu) +
  /// switch le tab root sur `orders`. Le grouper est reset : l'utilisateur
  /// a vu la summary, on peut oublier la window.
  static void _routeToOrdersGroup(WidgetRef ref, Map<String, dynamic> raw) {
    debugPrint('[DeepLinkHandler] orders.group tap → filtre payment-accepted');

    // 1. Switch root tab → orders (si le RootScaffold est dans la stack).
    try {
      ref.read(rootTabProvider.notifier).state = RootTab.orders;
    } catch (_) {
      // Si rootTabProvider n'est pas encore construit (cold-start avant
      // mount du RootScaffold), tomber sur une navigation directe.
    }

    // 2. Applique le filtre + refresh la liste.
    try {
      ref
          .read(ordersListProvider.notifier)
          .filterByStatus('payment-accepted');
    } catch (_) {
      // ignore — le provider sera charge au mount du RootScaffold.
    }

    // 3. Assure qu'on est bien sur le root (pas dans un sous-ecran).
    Routes.navigateAndRemoveAll(Routes.root);
  }
}
