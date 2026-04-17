// IncomingOrderDispatcher — point d'entree unique pour declencher l'ecran
// "nouvelle commande".
//
// Appele par :
//  - Le handler FCM (Phase 1 — a venir quand google-services.json sera fourni)
//  - Le bouton dev en mode debug (Phase 2)
//  - Tout autre listener d'evenements push (WS, etc.) le cas echeant
//
// Role :
//  1. Parse le payload brut en [IncomingOrderPayload] (defensif)
//  2. Pousse le payload dans [incomingOrderProvider]
//  3. Navigue vers [IncomingOrderScreen] si pas deja affiche
//
// Evite les doubles navigations : si l'ecran est deja affiche pour la meme
// commande, seul le state est mis a jour (idempotent cote notifier).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/providers/incoming_order_provider.dart';
import 'package:merchant/screens/incoming_order/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

abstract class IncomingOrderDispatcher {
  /// Traite un payload brut (map type FCM RemoteMessage.data ou JSON decode).
  /// Retourne `false` si le payload n'est pas un ordre "nouvelle commande"
  /// exploitable.
  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    // Filtre : on ne traite que les events de type order.created (ou equivalents).
    final type = raw['type']?.toString() ?? '';
    if (!type.startsWith('order.created') && type != 'new_order') {
      debugPrint('[IncomingOrderDispatcher] skipped: type=$type');
      return false;
    }

    final payload = IncomingOrderPayload.tryParse(raw);
    if (payload == null) {
      debugPrint(
        '[IncomingOrderDispatcher] failed to parse payload: $raw',
      );
      return false;
    }

    return handle(ref, payload);
  }

  /// Traite un payload deja parse.
  static bool handle(WidgetRef ref, IncomingOrderPayload payload) {
    debugPrint('[IncomingOrderDispatcher] show $payload');

    final state = ref.read(incomingOrderProvider);
    final alreadyShowing = state.isActive &&
        state.payload?.orderId == payload.orderId;

    ref.read(incomingOrderProvider.notifier).show(payload);

    if (!alreadyShowing) {
      Routes.push(const IncomingOrderScreen(), style: ZeetTransitionStyle.scaled);
    }
    return true;
  }

  /// Trigger dev : declenche l'ecran avec un payload bidon (utile pour tester
  /// le flow sans attendre FCM + backend). Ne fait rien en release.
  static void triggerDev(WidgetRef ref, {int orderId = 421}) {
    if (!kDebugMode) return;
    handle(ref, IncomingOrderPayload.fake(orderId: orderId));
  }
}
