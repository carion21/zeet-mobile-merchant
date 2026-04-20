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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/providers/incoming_order_provider.dart';
import 'package:merchant/screens/incoming_order/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Lock gestuel partage : empeche l'`IncomingOrderScreen` de s'ouvrir par
/// dessus un swipe-to-confirm en cours (`ZeetSwipeToConfirm` sur une card
/// du home ou du detail). Sans ce lock, une FCM `order.created` qui arrive
/// pendant que le partner glisse sur une card `preparing` pour passer en
/// `ready` provoque un push `IncomingOrderScreen` instantane, ce qui donne
/// l'impression que le swipe a "ouvert l'ecran qui sonne".
///
/// L'UI appelle [markInteraction] juste avant d'executer son action
/// (accept/preparing/ready/cancel) — le dispatcher differera alors tout
/// push incoming de [_gestureLockWindow].
abstract class IncomingOrderGestureLock {
  static DateTime? _lastInteractionAt;
  static const Duration _gestureLockWindow = Duration(milliseconds: 1200);

  /// A appeler depuis l'UI au declenchement d'une action critique sur une
  /// card (swipe-to-confirm, cancel, tap sur action bar).
  static void markInteraction() {
    _lastInteractionAt = DateTime.now();
  }

  /// Duree restante du lock (0 si expire).
  static Duration get remaining {
    final last = _lastInteractionAt;
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    final diff = _gestureLockWindow - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }

  static bool get isLocked => remaining > Duration.zero;
}

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

    // Mets a jour le payload du provider immediatement (le state porte
    // la payload meme si la navigation est differee — permet de sonner
    // des que la window de lock expire).
    ref.read(incomingOrderProvider.notifier).show(payload);

    if (alreadyShowing) return true;

    // Guard race : si le partner est en train de swiper sur une card
    // existante (preparing → ready, confirmed → preparing, etc.), on
    // differe le push de l'IncomingOrderScreen le temps que le lock
    // expire. Sinon l'ouverture instantanee de l'ecran en plein milieu
    // du swipe donne l'impression que le swipe "a appele l'interface
    // qui sonne".
    final Duration lockRemaining = IncomingOrderGestureLock.remaining;
    if (lockRemaining > Duration.zero) {
      debugPrint(
        '[IncomingOrderDispatcher] gesture lock active, deferring '
        '${lockRemaining.inMilliseconds}ms',
      );
      Timer(lockRemaining + const Duration(milliseconds: 50), () {
        // Re-check : si entre-temps l'utilisateur a deja accepte/refuse
        // depuis une autre source, on skip le push pour ne pas ouvrir
        // un screen obsolete.
        final latest = ref.read(incomingOrderProvider);
        if (!latest.isActive) return;
        if (latest.payload?.orderId != payload.orderId) return;
        Routes.push(
          const IncomingOrderScreen(),
          style: ZeetTransitionStyle.scaled,
        );
      });
      return true;
    }

    Routes.push(const IncomingOrderScreen(), style: ZeetTransitionStyle.scaled);
    return true;
  }

  /// Trigger dev : declenche l'ecran avec un payload bidon (utile pour tester
  /// le flow sans attendre FCM + backend). Ne fait rien en release.
  static void triggerDev(WidgetRef ref, {int orderId = 421}) {
    if (!kDebugMode) return;
    handle(ref, IncomingOrderPayload.fake(orderId: orderId));
  }
}
